import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

/// "Tự động nhắc nghỉ mắt": đếm ngược theo ĐỒNG HỒ THẬT, không cần người dùng
/// tự đặt hẹn giờ. Countdown được chia từ mục tiêu "Nghỉ mắt/ngày" (habit
/// 'breaks') trên số giờ thức giả định.
///
/// THIẾT KẾ MỚI (theo yêu cầu: "khi đếm ngược hết thời gian thì mới gửi thông
/// báo nhắc nhở và tính đó là 1 lần nghỉ mắt"):
///  - Thông báo CHỈ do báo thức NATIVE (AlarmManager qua
///    flutter_local_notifications) bắn đúng lúc đếm ngược về 0 — đáng tin cậy
///    kể cả khi app ở nền/đã đóng. Dart KHÔNG tự bắn thêm thông báo nào nữa,
///    nên không còn chuyện 2 thông báo/2 đồng hồ lệch nhau.
///  - Mỗi chu kỳ đếm ngược trôi hết = ĐÚNG 1 lần nghỉ mắt được ghi nhận
///    (onAutoConfirmed), không cần bấm xác nhận, không cần kiểm tra usage.
///  - Thanh/số đếm ngược trên UI tính từ cùng 1 mốc `_cycleStart` với báo
///    thức native (cùng khoảng làm tròn theo phút) nên luôn khớp thông báo.
///  - App mở lại sau khi ở nền: bù các chu kỳ đã trôi qua trong lúc đó (tối
///    đa [_kMaxCatchUpCycles]). Nếu vắng mặt quá lâu (máy tắt, ban đêm...)
///    thì chỉ dời mốc, KHÔNG cộng bừa các lần nghỉ.
class AutoBreakProvider extends ChangeNotifier {
  static const _kEnabledKey = 'pref_auto_break_enabled';
  static const _kCycleStartKey = 'pref_auto_break_cycle_start_millis';
  // Giả định số giờ thức trung bình/ngày để chia countdown từ mục tiêu.
  static const double _kAssumedWakingHours = 16.0;
  static const int _kMinIntervalSec = 5 * 60;
  static const int _kMaxIntervalSec = 90 * 60;
  static const int _kMaxCatchUpCycles = 3;

  bool _enabled = false;
  int _intervalSeconds = 20 * 60;
  DateTime? _cycleStart;
  Timer? _tickTimer;

  /// Gọi mỗi khi 1 chu kỳ đếm ngược trôi hết — nơi gọi (main_shell.dart) gán
  /// hàm này để ghi 1 lần nghỉ mắt vào HabitProvider.
  Future<void> Function()? onAutoConfirmed;

  bool get enabled => _enabled;

  // Khoảng thực tế, làm tròn theo PHÚT để khớp tuyệt đối với báo thức native
  // (periodicallyShowWithDuration nhận số phút nguyên).
  int get intervalSeconds => ((_intervalSeconds / 60).round().clamp(1, 1000000)) * 60;

  int get secondsRemaining {
    final start = _cycleStart;
    if (!_enabled || start == null) return intervalSeconds;
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (intervalSeconds - elapsed).clamp(0, intervalSeconds);
  }

  double get progress {
    if (intervalSeconds == 0) return 0;
    return ((intervalSeconds - secondsRemaining) / intervalSeconds).clamp(0.0, 1.0);
  }

  AutoBreakProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? false;
    final startMillis = prefs.getInt(_kCycleStartKey);
    _cycleStart = startMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(startMillis);
    if (_enabled) {
      if (_cycleStart == null) {
        await _restartCycle(); // lần đầu: đặt mốc + báo thức native.
      } else {
        await _catchUp(); // bù chu kỳ đã trôi trong lúc app không chạy.
        // Đăng ký lại báo thức native mỗi lần app khởi động (idempotent).
        unawaited(_scheduleNativeAlarm());
      }
      _startTicking();
    }
    notifyListeners();
  }

  /// Gọi mỗi khi mục tiêu 'breaks' thay đổi hoặc lúc khởi động — chia đều giờ
  /// thức giả định cho số lần nghỉ mục tiêu.
  void recomputeInterval(double dailyTargetBreaks) {
    if (dailyTargetBreaks <= 0) return;
    final seconds = (_kAssumedWakingHours * 3600 / dailyTargetBreaks).round();
    final clamped = seconds.clamp(_kMinIntervalSec, _kMaxIntervalSec);
    if (clamped != _intervalSeconds) {
      final oldEffective = intervalSeconds;
      _intervalSeconds = clamped;
      // Khoảng hiệu dụng (làm tròn phút) đổi -> bắt đầu chu kỳ mới để UI và
      // báo thức native không lệch pha.
      if (_enabled && intervalSeconds != oldEffective) {
        unawaited(_restartCycle());
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
    if (value) {
      await _restartCycle();
      _startTicking();
    } else {
      _tickTimer?.cancel();
      _tickTimer = null;
      _cycleStart = null;
      await prefs.remove(_kCycleStartKey);
      await NotificationService.instance.cancelRepeatingBreakAlarm();
    }
    notifyListeners();
  }

  Future<void> _restartCycle() async {
    _cycleStart = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCycleStartKey, _cycleStart!.millisecondsSinceEpoch);
    await _scheduleNativeAlarm();
    notifyListeners();
  }

  // Báo thức native lặp lại mỗi `intervalSeconds` — lần bắn đầu tiên cách thời
  // điểm đặt lịch đúng 1 khoảng, trùng với `_cycleStart + interval`.
  Future<void> _scheduleNativeAlarm() async {
    await NotificationService.instance.scheduleRepeatingBreakAlarm(
      intervalMinutes: intervalSeconds ~/ 60,
      title: 'Đến giờ nghỉ mắt',
      body: 'Nhìn xa 6 mét trong 20 giây nhé.',
      ongoingTitle: 'Tự động nhắc nghỉ mắt',
      ongoingRemainingSuffix: 'Sẽ nhắc lúc',
    );
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_enabled) return;
      await _catchUp();
      notifyListeners();
    });
  }

  // Ghi nhận các chu kỳ đã trôi hết kể từ `_cycleStart`. Mốc được dời lên
  // đúng bội số của chu kỳ để giữ cùng pha với báo thức native.
  Future<void> _catchUp() async {
    final start = _cycleStart;
    if (start == null) return;
    final intervalMs = intervalSeconds * 1000;
    final cycles = DateTime.now().difference(start).inMilliseconds ~/ intervalMs;
    if (cycles <= 0) return;

    _cycleStart = start.add(Duration(milliseconds: cycles * intervalMs));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCycleStartKey, _cycleStart!.millisecondsSinceEpoch);

    // Vắng mặt quá lâu (> _kMaxCatchUpCycles chu kỳ) = nhiều khả năng máy
    // tắt/ngủ qua đêm -> chỉ dời mốc, không cộng các lần nghỉ.
    if (cycles > _kMaxCatchUpCycles) return;
    for (var i = 0; i < cycles; i++) {
      await onAutoConfirmed?.call();
    }
  }

  /// Người dùng tự bấm "Đã nghỉ" thủ công (nếu muốn) — bắt đầu chu kỳ mới.
  Future<void> confirmBreakManually() async {
    await _restartCycle();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}