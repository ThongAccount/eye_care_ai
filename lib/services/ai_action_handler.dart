import 'dart:convert';

import '../providers/auto_break_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/settings_provider.dart';
import 'focus_mode_service.dart';

/// Cho phép AI không chỉ TRẢ LỜI mà còn THAO TÁC được với app.
///
/// Cách hoạt động: system prompt (xem eye_chat_service.dart) dạy cho model
/// một "giao thức" đơn giản — khi muốn thực hiện hành động trong app, model
/// chèn 1 khối JSON được bọc trong %%ACTION%% ... %%END%% ở cuối câu trả
/// lời. Vì đây là model dạng text-completion thuần (không chắc NIM endpoint
/// hỗ trợ "function calling" chuẩn OpenAI khi streaming), dùng 1 giao thức
/// tự định nghĩa bằng text sẽ chắc chắn hoạt động với MỌI model, không phụ
/// thuộc API có hỗ trợ tools hay không.
///
/// Sau khi nhận đủ phản hồi (stream xong), `AiActionHandler.extract()` tách
/// khối JSON đó ra khỏi văn bản hiển thị.
///
/// TỪ ĐÂY VỀ SAU app có 2 chế độ áp dụng action (tuỳ cài đặt "Hỏi trước khi
/// AI tự thao tác" trong Settings > Quyền riêng tư & Bảo mật):
/// - Nếu BẬT (mặc định): `describeActions()` sinh ra bản xem trước bằng
///   ngôn ngữ tự nhiên (KHÔNG áp dụng gì cả), hiện kèm 2 nút Đồng ý/Từ chối
///   trong khung chat — chỉ khi người dùng bấm "Đồng ý" thì `execute()` mới
///   thực sự chạy.
/// - Nếu TẮT: `execute()` được gọi ngay sau khi model trả lời xong, không
///   cần hỏi.
class AiAction {
  AiAction({required this.type, required this.params});

  final String type;
  final Map<String, dynamic> params;

  factory AiAction.fromJson(Map<String, dynamic> json) {
    return AiAction(
      type: (json['action'] ?? '').toString(),
      params: json,
    );
  }
}

class AiActionResult {
  AiActionResult({required this.cleanedText, required this.actions});

  final String cleanedText;
  final List<AiAction> actions;
}

class AiActionHandler {
  AiActionHandler._();

  static final RegExp _tagPattern = RegExp(
    r'%%ACTION%%\s*(.*?)\s*%%END%%',
    dotAll: true,
  );

  // Giới hạn giá trị hợp lý cho từng loại mục tiêu, để dù model có "sáng
  // tạo" đề xuất số điên rồ (ví dụ 0 giờ ngủ, hoặc 999 giờ dùng điện thoại)
  // thì app cũng không áp dụng bừa — luôn kẹp về khoảng an toàn/thực tế.
  static const Map<String, _Range> _targetRanges = {
    'phone': _Range(min: 1, max: 12), // giờ/ngày
    'sleep': _Range(min: 4, max: 12), // giờ/đêm
    'outdoor': _Range(min: 15, max: 240), // phút/ngày
    'breaks': _Range(min: 1, max: 30), // số lần nghỉ mắt/ngày
  };

  static const List<String> _visionProfileIds = ['glasses', 'contact_lens', 'no_correction'];
  static const List<String> _reminderStyleIds = ['gentle', 'normal', 'strict'];

  /// Tách các khối %%ACTION%%{...}%%END%% ra khỏi [rawText], trả về text đã
  /// làm sạch (để hiển thị cho người dùng) và danh sách action hợp lệ.
  static AiActionResult extract(String rawText) {
    final actions = <AiAction>[];
    final cleaned = rawText.replaceAllMapped(_tagPattern, (match) {
      final jsonPart = match.group(1) ?? '';
      try {
        final decoded = jsonDecode(jsonPart);
        if (decoded is Map<String, dynamic>) {
          actions.add(AiAction.fromJson(decoded));
        } else if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              actions.add(AiAction.fromJson(item));
            }
          }
        }
      } catch (_) {
        // Model lỡ trả JSON sai định dạng -> bỏ qua action, vẫn giữ phần
        // text còn lại hiển thị bình thường, không làm crash/kẹt chat.
      }
      return '';
    });
    return AiActionResult(cleanedText: cleaned.trim(), actions: actions);
  }

  /// Sinh mô tả preview cho từng action bằng ngôn ngữ tự nhiên, KHÔNG áp
  /// dụng bất kỳ thay đổi thật nào — dùng khi cần HỎI XÁC NHẬN trước (xem
  /// cài đặt "Hỏi trước khi AI tự thao tác"). Action lạ/tham số không hợp lệ
  /// sẽ bị bỏ qua (không thêm dòng preview) — execute() sau đó cũng tự bỏ
  /// qua action đó, nên hành vi luôn đồng bộ giữa preview và lúc áp dụng
  /// thật.
  static List<String> describeActions(
    List<AiAction> actions, {
    required HabitProvider habits,
    required bool isVietnamese,
  }) {
    final lines = <String>[];
    for (final action in actions) {
      switch (action.type) {
        case 'set_habit_target':
          final line = _describeSetHabitTarget(action, habits, isVietnamese);
          if (line != null) lines.add(line);
          break;
        case 'record_eye_break':
          lines.add(isVietnamese
              ? 'Ghi nhận 1 lần nghỉ mắt cho hôm nay'
              : 'Log one eye break for today');
          break;
        case 'enable_focus_mode':
          lines.add(isVietnamese ? 'Bật Chế độ Tập trung' : 'Turn on Focus Mode');
          break;
        case 'disable_focus_mode':
          lines.add(isVietnamese ? 'Tắt Chế độ Tập trung' : 'Turn off Focus Mode');
          break;
        case 'set_vision_profile':
          final profile = (action.params['profile'] ?? '').toString();
          if (_visionProfileIds.contains(profile)) {
            lines.add(isVietnamese
                ? 'Đổi Hồ sơ thị lực sang "${_visionProfileLabel(profile, true)}"'
                : 'Set Vision Profile to "${_visionProfileLabel(profile, false)}"');
          }
          break;
        case 'set_reminder_style':
          final style = (action.params['style'] ?? '').toString();
          if (_reminderStyleIds.contains(style)) {
            lines.add(isVietnamese
                ? 'Đổi Kiểu nhắc nhở sang "${_reminderStyleLabel(style, true)}"'
                : 'Set Reminder Style to "${_reminderStyleLabel(style, false)}"');
          }
          break;
        case 'set_auto_break_enabled':
          final enabled = action.params['enabled'] == true;
          lines.add(isVietnamese
              ? (enabled ? 'Bật Tự động nhắc nghỉ mắt' : 'Tắt Tự động nhắc nghỉ mắt')
              : (enabled ? 'Turn on Auto eye-break reminders' : 'Turn off Auto eye-break reminders'));
          break;
        default:
          // Action lạ (model bịa ra loại không có thật) -> bỏ qua, không
          // thêm dòng preview cho nó.
          break;
      }
    }
    return lines;
  }

  static String? _describeSetHabitTarget(
    AiAction action,
    HabitProvider habits,
    bool isVietnamese,
  ) {
    final habitId = (action.params['habit'] ?? '').toString();
    final rawValue = action.params['value'];
    final value = rawValue is num ? rawValue.toDouble() : double.tryParse('$rawValue');
    final range = _targetRanges[habitId];
    if (value == null || range == null) return null;
    final index = habits.habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return null;
    final habit = habits.habits[index];
    if (habit.isComingSoon) return null;
    final newTarget = value.clamp(range.min, range.max).toDouble();
    final title = _habitLabel(habitId, isVietnamese);
    final unit = _habitUnit(habitId, isVietnamese);
    return isVietnamese
        ? 'Đổi mục tiêu "$title" thành ${_formatNumber(newTarget)} $unit/ngày'
        : 'Set "$title" target to ${_formatNumber(newTarget)} $unit/day';
  }

  /// Áp dụng danh sách action vào app thật, trả về các dòng xác nhận
  /// (tiếng Việt hoặc Anh tuỳ [isVietnamese]) để hiện cho người dùng thấy.
  /// [settings]/[autoBreak] là optional vì không phải mọi nơi gọi hàm này
  /// đều cần tới 2 action mới (đổi hồ sơ thị lực/kiểu nhắc nhở/auto-break) —
  /// nếu thiếu, các action đó bị bỏ qua an toàn (không crash).
  static Future<List<String>> execute(
    List<AiAction> actions, {
    required HabitProvider habits,
    required bool isVietnamese,
    SettingsProvider? settings,
    AutoBreakProvider? autoBreak,
  }) async {
    final confirmations = <String>[];
    for (final action in actions) {
      switch (action.type) {
        case 'set_habit_target':
          final confirmation = await _setHabitTarget(action, habits, isVietnamese);
          if (confirmation != null) confirmations.add(confirmation);
          break;
        case 'record_eye_break':
          await habits.recordEyeBreak();
          confirmations.add(isVietnamese
              ? '✅ Đã ghi nhận 1 lần nghỉ mắt cho hôm nay.'
              : '✅ Logged one eye break for today.');
          break;
        case 'enable_focus_mode':
          confirmations.add(await _toggleFocusMode(true, isVietnamese));
          break;
        case 'disable_focus_mode':
          confirmations.add(await _toggleFocusMode(false, isVietnamese));
          break;
        case 'set_vision_profile':
          if (settings == null) break;
          final profile = (action.params['profile'] ?? '').toString();
          if (!_visionProfileIds.contains(profile)) break;
          await settings.setVisionProfile(profile);
          confirmations.add(isVietnamese
              ? '👓 Đã đổi Hồ sơ thị lực sang "${_visionProfileLabel(profile, true)}".'
              : '👓 Vision Profile set to "${_visionProfileLabel(profile, false)}".');
          break;
        case 'set_reminder_style':
          if (settings == null) break;
          final style = (action.params['style'] ?? '').toString();
          if (!_reminderStyleIds.contains(style)) break;
          await settings.setReminderStyle(style);
          confirmations.add(isVietnamese
              ? '🎯 Đã đổi Kiểu nhắc nhở sang "${_reminderStyleLabel(style, true)}".'
              : '🎯 Reminder Style set to "${_reminderStyleLabel(style, false)}".');
          break;
        case 'set_auto_break_enabled':
          if (autoBreak == null) break;
          final enabled = action.params['enabled'] == true;
          await autoBreak.setEnabled(enabled);
          confirmations.add(isVietnamese
              ? (enabled ? '🔁 Đã bật Tự động nhắc nghỉ mắt.' : '🔁 Đã tắt Tự động nhắc nghỉ mắt.')
              : (enabled ? '🔁 Auto eye-break reminders turned on.' : '🔁 Auto eye-break reminders turned off.'));
          break;
        default:
          // Action lạ (model bịa ra loại không có thật) -> lờ đi, không báo lỗi
          // cho người dùng vì đây là lỗi của model, không phải của họ.
          break;
      }
    }
    return confirmations;
  }

  static Future<String?> _setHabitTarget(
    AiAction action,
    HabitProvider habits,
    bool isVietnamese,
  ) async {
    final habitId = (action.params['habit'] ?? '').toString();
    final rawValue = action.params['value'];
    final value = rawValue is num ? rawValue.toDouble() : double.tryParse('$rawValue');
    final range = _targetRanges[habitId];
    if (value == null || range == null) return null;

    final index = habits.habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return null;
    final habit = habits.habits[index];
    if (habit.isComingSoon) return null;

    final oldTarget = habit.target;
    final newTarget = value.clamp(range.min, range.max).toDouble();
    await habits.setHabitTarget(habitId, newTarget);

    final title = _habitLabel(habitId, isVietnamese);
    final unit = _habitUnit(habitId, isVietnamese);
    final oldStr = _formatNumber(oldTarget);
    final newStr = _formatNumber(newTarget);
    final direction = newTarget < oldTarget
        ? (isVietnamese ? 'giảm' : 'lowered')
        : (isVietnamese ? 'tăng' : 'raised');

    return isVietnamese
        ? '🎯 Đã $direction mục tiêu "$title": $oldStr → $newStr $unit/ngày.'
        : '🎯 ${direction[0].toUpperCase()}${direction.substring(1)} "$title" target: $oldStr → $newStr $unit/day.';
  }

  static Future<String> _toggleFocusMode(bool enable, bool isVietnamese) async {
    final service = FocusModeService.instance;
    final hasAccess = await service.hasAccess();
    if (!hasAccess) {
      return isVietnamese
          ? '⚠️ Mình chưa được cấp quyền để bật Chế độ Tập trung. Vào Cài đặt > Chế độ Tập trung để cấp quyền nhé.'
          : '⚠️ I don\'t have permission to toggle Focus Mode yet. Please enable it under Settings > Focus Mode.';
    }
    final success = enable ? await service.enable() : await service.disable();
    if (!success) {
      return isVietnamese ? '⚠️ Không bật/tắt được Chế độ Tập trung.' : '⚠️ Couldn\'t toggle Focus Mode.';
    }
    if (enable) {
      return isVietnamese
          ? '🔕 Đã bật Chế độ Tập trung — thông báo sẽ được chặn để mắt bạn nghỉ ngơi.'
          : '🔕 Focus Mode is on — notifications will be blocked so your eyes can rest.';
    }
    return isVietnamese ? '🔔 Đã tắt Chế độ Tập trung.' : '🔔 Focus Mode is off.';
  }

  static String _habitLabel(String id, bool vi) {
    switch (id) {
      case 'phone':
        return vi ? 'Thời gian dùng điện thoại' : 'Phone Usage';
      case 'sleep':
        return vi ? 'Giấc ngủ' : 'Sleep';
      case 'outdoor':
        return vi ? 'Thời gian ngoài trời' : 'Outdoor Time';
      case 'breaks':
        return vi ? 'Nghỉ mắt' : 'Eye Breaks';
      default:
        return id;
    }
  }

  static String _habitUnit(String id, bool vi) {
    switch (id) {
      case 'phone':
      case 'sleep':
        return vi ? 'giờ' : 'hrs';
      case 'outdoor':
        return vi ? 'phút' : 'min';
      case 'breaks':
        return vi ? 'lần' : 'times';
      default:
        return '';
    }
  }

  static String _visionProfileLabel(String id, bool vi) {
    switch (id) {
      case 'glasses':
        return vi ? 'Đeo kính' : 'Glasses';
      case 'contact_lens':
        return vi ? 'Kính áp tròng' : 'Contact Lens';
      case 'no_correction':
        return vi ? 'Không sử dụng kính' : 'No Vision Correction';
      default:
        return id;
    }
  }

  static String _reminderStyleLabel(String id, bool vi) {
    switch (id) {
      case 'gentle':
        return vi ? 'Nhẹ nhàng' : 'Gentle';
      case 'normal':
        return vi ? 'Thông thường' : 'Normal';
      case 'strict':
        return vi ? 'Nghiêm ngặt' : 'Strict';
      default:
        return id;
    }
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}

class _Range {
  const _Range({required this.min, required this.max});
  final double min;
  final double max;
}