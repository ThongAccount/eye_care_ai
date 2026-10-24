import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kMetricKey = 'pref_use_metric';
  static const _k24HourKey = 'pref_24_hour';
  static const _kNotifyBreaksKey = 'pref_notify_breaks';
  static const _kNotifyTestsKey = 'pref_notify_tests';
  static const _kNotifyHabitsKey = 'pref_notify_habits';
  static const _kNotifyTipsKey = 'pref_notify_tips';
  static const _kVisionProfileKey = 'pref_vision_profile';
  static const _kReminderStyleKey = 'pref_reminder_style';
  static const _kViewingDistanceModeKey = 'pref_viewing_distance_mode';
  static const _kGuardianEmailKey = 'pref_guardian_email';

  SettingsProvider() {
    _loadSavedPreferences();
  }

  bool _useMetric = true;
  bool _is24Hour = false;
  bool _notifyBreaks = true;
  bool _notifyTests = true;
  bool _notifyHabits = true;
  bool _notifyTips = true;
  String _visionProfile = 'glasses';
  String _reminderStyle = 'gentle';
  String _viewingDistanceMode = 'auto';
  String _guardianEmail = '';
  bool _customNotificationSound = true;

  bool get useMetric => _useMetric;
  bool get is24Hour => _is24Hour;
  bool get notifyBreaks => _notifyBreaks;
  bool get notifyTests => _notifyTests;
  bool get notifyHabits => _notifyHabits;
  bool get notifyTips => _notifyTips;
  String get visionProfile => _visionProfile;
  String get reminderStyle => _reminderStyle;
  String get viewingDistanceMode => _viewingDistanceMode;
  String get guardianEmail => _guardianEmail;

  /// Dùng âm thanh báo nghỉ mắt riêng của EyeCare AI thay cho âm thanh mặc
  /// định của hệ thống. Khoá lưu trữ do [NotificationService] sở hữu.
  bool get customNotificationSound => _customNotificationSound;

  Future<void> reload() => _loadSavedPreferences();

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _useMetric = prefs.getBool(_kMetricKey) ?? _useMetric;
    _is24Hour = prefs.getBool(_k24HourKey) ?? _is24Hour;
    _notifyBreaks = prefs.getBool(_kNotifyBreaksKey) ?? _notifyBreaks;
    _notifyTests = prefs.getBool(_kNotifyTestsKey) ?? _notifyTests;
    _notifyHabits = prefs.getBool(_kNotifyHabitsKey) ?? _notifyHabits;
    _notifyTips = prefs.getBool(_kNotifyTipsKey) ?? _notifyTips;
    _visionProfile = prefs.getString(_kVisionProfileKey) ?? _visionProfile;
    _reminderStyle = prefs.getString(_kReminderStyleKey) ?? _reminderStyle;
    _viewingDistanceMode = prefs.getString(_kViewingDistanceModeKey) ?? _viewingDistanceMode;
    _guardianEmail = prefs.getString(_kGuardianEmailKey) ?? _guardianEmail;
    _customNotificationSound =
        prefs.getBool(NotificationService.customSoundPrefKey) ??
            _customNotificationSound;
    notifyListeners();
  }

  Future<void> toggleMetric(bool value) async {
    _useMetric = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMetricKey, value);
    notifyListeners();
  }

  Future<void> toggleTimeFormat(bool value) async {
    _is24Hour = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_k24HourKey, value);
    notifyListeners();
  }

  Future<void> setNotification(String key, bool value) async {
    switch (key) {
      case 'breaks':
        _notifyBreaks = value;
        break;
      case 'tests':
        _notifyTests = value;
        break;
      case 'habits':
        _notifyHabits = value;
        break;
      case 'tips':
        _notifyTips = value;
        break;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationKey(key), value);
    notifyListeners();
  }

  Future<void> setVisionProfile(String value) async {
    _visionProfile = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVisionProfileKey, value);
    notifyListeners();
  }

  Future<void> setReminderStyle(String value) async {
    _reminderStyle = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReminderStyleKey, value);
    notifyListeners();
  }

  Future<void> setViewingDistanceMode(String value) async {
    _viewingDistanceMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kViewingDistanceModeKey, value);
    notifyListeners();
  }

  Future<void> setGuardianEmail(String value) async {
    _guardianEmail = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGuardianEmailKey, _guardianEmail);
    notifyListeners();
  }

  /// Bật/tắt âm thanh báo nghỉ mắt riêng. Việc lưu trữ (và việc đặt lại
  /// báo thức lặp đang chạy) do [NotificationService] đảm nhiệm — provider
  /// chỉ cập nhật trạng thái để UI vẽ lại.
  Future<void> setCustomNotificationSound(bool value) async {
    _customNotificationSound = value;
    await NotificationService.instance.setCustomSoundEnabled(value);
    notifyListeners();
  }

  String _notificationKey(String key) {
    switch (key) {
      case 'breaks':
        return _kNotifyBreaksKey;
      case 'tests':
        return _kNotifyTestsKey;
      case 'habits':
        return _kNotifyHabitsKey;
      case 'tips':
        return _kNotifyTipsKey;
      default:
        return key;
    }
  }
}
