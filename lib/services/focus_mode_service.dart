import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Chế độ Focus: chặn thông báo app khác trong lúc đang đếm ngược giữa 2 lần
// nghỉ mắt, giảm giật mình/mất tập trung do bị làm phiền liên tục — dùng
// Do Not Disturb của hệ thống (xem FocusModeHandler.kt phía native).
class FocusModeService {
  FocusModeService._();
  static final instance = FocusModeService._();

  static const _channel = MethodChannel('eye_care_ai/focus_mode');

  /// Key lưu trạng thái "người dùng đã cấp quyền bật/tắt DND" (xem PLAN.md § D).
  ///
  /// Quyền này là quyền ĐẶC BIỆT của Android: người dùng bật tay ở Cài đặt
  /// hệ thống, không có hộp thoại xin quyền. Trước đây `hasAccess()` hỏi lại
  /// `isNotificationPolicyAccessGranted` mỗi lần được gọi — nên MỘT lần hỏi
  /// hỏng (native lỗi, hoặc batch refreshStatus của SetupProvider timeout) là
  /// app quên mất trạng thái đã cấp, và banner "cấp quyền DND" lại hiện lên
  /// dù người dùng đã cấp rồi. Cache lại ở SharedPreferences để trạng thái đã
  /// cấp sống sót qua app restart và qua các lần hỏi hỏng.
  static const dndGrantedPrefKey = 'pref_focus_mode_dnd_granted';

  Future<bool> hasAccess() async {
    // Đã cấp rồi (theo lần hỏi trước) -> khỏi hỏi lại native.
    if (await _readGranted()) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('hasAccess') ?? false;
      if (granted) await _writeGranted(true);
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    try {
      await _channel.invokeMethod('openAccessSettings');
    } catch (_) {}
  }

  // Trả về false nếu chưa được cấp quyền "Notification policy access" —
  // gọi hasAccess() trước để hiện đúng lời nhắc thay vì âm thầm không làm gì.
  Future<bool> enable() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('enable') ?? false;
      // Native trả false nghĩa là quyền ĐÃ BỊ THU HỒI (người dùng tự tắt ở
      // Cài đặt hệ thống) -> xoá cache, để lần hỏi sau báo đúng và banner
      // "cấp quyền DND" hiện lại đúng lúc người dùng cần.
      if (!enabled) await _writeGranted(false);
      return enabled;
    } catch (_) {
      return false;
    }
  }

  Future<bool> disable() async {
    try {
      return await _channel.invokeMethod<bool>('disable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isCurrentlyEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _readGranted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(dndGrantedPrefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeGranted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(dndGrantedPrefKey, value);
    } catch (_) {}
  }
}