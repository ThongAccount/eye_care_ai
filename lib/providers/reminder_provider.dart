import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderProvider extends ChangeNotifier {
  static const _kReminderMinutesKey = 'pref_reminder_minutes';
  // Chế độ THỤ ĐỘNG (Cách 1 trong tài liệu tham khảo): khi người dùng khoá
  // màn hình / rời app từ 20 giây trở lên, tự động tính là 1 lần nghỉ mắt —
  // phù hợp với thói quen của thanh thiếu niên (hay tự nhiên úp điện thoại
  // xuống / khoá màn hình hơn là bấm nút "Xong" thủ công). Không tốn thêm
  // pin/quyền vì chỉ dùng WidgetsBindingObserver có sẵn của Flutter.
  static const _kAutoDetectKey = 'pref_auto_detect_eye_breaks';
  // Chế độ Focus: chặn thông báo app khác (Do Not Disturb) trong lúc đang
  // đếm ngược giữa 2 lần nghỉ mắt, giảm giật mình/mất tập trung.
  static const _kFocusModeKey = 'pref_focus_mode_enabled';
  // Ngày + cờ "chạy không giới hạn" — khi đã đạt đủ số lần nghỉ mắt mục
  // tiêu trong ngày (lấy từ target habit 'breaks'), nhắc nghỉ mắt TỰ DỪNG
  // (xem eye_break_screen.dart _confirmBreakTaken). Nếu người dùng vẫn chủ
  // động bấm "Bắt đầu" lại sau đó, cờ này được bật để KHÔNG tự dừng thêm
  // lần nào nữa trong CÙNG NGÀY đó — tự reset lại (coi như tắt) khi sang
  // ngày mới, không lưu vĩnh viễn.
  static const _kUnlimitedOverrideDateKey = 'pref_unlimited_override_date';

  ReminderProvider() {
    _loadSavedPreferences();
  }

  bool _isEyeBreakReminderActive = false;
  int _reminderMinutes = 20;
  bool _autoDetectEyeBreaks = true;
  bool _focusModeEnabled = false;
  bool _unlimitedOverrideToday = false;

  bool get isEyeBreakReminderActive => _isEyeBreakReminderActive;
  int get reminderMinutes => _reminderMinutes;
  bool get autoDetectEyeBreaks => _autoDetectEyeBreaks;
  bool get focusModeEnabled => _focusModeEnabled;
  bool get unlimitedOverrideToday => _unlimitedOverrideToday;

  Future<void> reload() => _loadSavedPreferences();

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _reminderMinutes = prefs.getInt(_kReminderMinutesKey) ?? _reminderMinutes;
    _autoDetectEyeBreaks = prefs.getBool(_kAutoDetectKey) ?? _autoDetectEyeBreaks;
    _focusModeEnabled = prefs.getBool(_kFocusModeKey) ?? _focusModeEnabled;
    _unlimitedOverrideToday = prefs.getString(_kUnlimitedOverrideDateKey) == _todayKey();
    notifyListeners();
  }

  // Gọi khi người dùng CHỦ ĐỘNG bấm "Bắt đầu" trong lúc đã đạt/vượt mục
  // tiêu số lần nghỉ mắt hôm nay — từ giờ tới hết ngày, không tự dừng nữa.
  Future<void> activateUnlimitedForToday() async {
    _unlimitedOverrideToday = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnlimitedOverrideDateKey, _todayKey());
    notifyListeners();
  }

  Future<void> setFocusModeEnabled(bool value) async {
    _focusModeEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFocusModeKey, value);
    notifyListeners();
  }

  Future<void> setAutoDetectEyeBreaks(bool value) async {
    _autoDetectEyeBreaks = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoDetectKey, value);
    notifyListeners();
  }

  Future<void> setReminderMinutes(int minutes) async {
    _reminderMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReminderMinutesKey, minutes);
    notifyListeners();
  }

  void toggleEyeBreakReminder(bool active) {
    _isEyeBreakReminderActive = active;
    notifyListeners();
  }
}