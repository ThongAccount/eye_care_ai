import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'brightness_service.dart';
import 'notification_service.dart';

/// "AI Night Mode Advisor" — không cần cài đặt/xin quyền gì thêm (tái dùng
/// đúng cảm biến ánh sáng + quyền đổi độ sáng hệ thống đã xin ở tính năng
/// "Gợi ý độ sáng"/Setup Wizard). Mỗi 15 phút trong khung giờ tối kiểm tra 1
/// lần: nếu (1) đang là giờ tối, (2) phòng đang tối (lux thấp), VÀ (3) màn
/// hình lại đang để khá sáng — coi là bất hợp lý, gửi 1 thông báo gợi ý giảm
/// độ sáng, kèm nút "Giảm ngay" để áp dụng ngay trên thông báo, không cần mở
/// app. Chỉ gợi ý TỐI ĐA 1 LẦN/NGÀY để không làm phiền.
class NightModeAdvisorService {
  NightModeAdvisorService._();
  static final NightModeAdvisorService instance = NightModeAdvisorService._();

  static const _kLastShownDateKey = 'pref_night_advisor_last_shown_date';
  static const _kPendingBrightnessKey = 'pref_night_advisor_pending_brightness';

  // Khung giờ "ban đêm": từ 21:00 tới 5:00 sáng hôm sau (qua nửa đêm).
  static const _kNightStartHour = 21;
  static const _kNightEndHour = 5;

  // Dùng CHUNG mốc "tối" 10 lux với tính năng cảnh báo dùng điện thoại trong
  // bóng tối (device_data_service.dart) để nhất quán định nghĩa "phòng tối"
  // trong toàn app, tránh 2 tính năng dùng 2 ngưỡng khác nhau gây khó hiểu.
  static const _kDarkLuxThreshold = 10;

  // Màn hình >= 60% giữa đêm trong phòng tối coi là "sáng bất hợp lý".
  static const _kHighBrightnessThreshold = 0.6;
  // Mức giảm đề xuất mỗi lần — khớp yêu cầu "giảm sáng 20%".
  static const _kReductionAmount = 0.20;
  static const _kMinBrightnessFloor = 0.05;

  Timer? _checkTimer;

  void start() {
    if (!Platform.isAndroid) return; // cảm biến ánh sáng + đổi độ sáng hệ thống: chỉ hỗ trợ Android.
    stop();
    _checkOnce(); // kiểm tra ngay (vd người dùng mở app lúc 22h30 luôn).
    _checkTimer = Timer.periodic(const Duration(minutes: 15), (_) => _checkOnce());
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  bool _isNightTime(DateTime now) {
    final hour = now.hour;
    if (_kNightStartHour <= _kNightEndHour) {
      return hour >= _kNightStartHour && hour < _kNightEndHour;
    }
    // Khung giờ vắt qua nửa đêm (vd 21h -> 5h): đúng khi >= giờ bắt đầu
    // HOẶC < giờ kết thúc (không phải AND, vì 2 mốc nằm ở 2 phía nửa đêm).
    return hour >= _kNightStartHour || hour < _kNightEndHour;
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  Future<bool> _alreadyShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastShownDateKey) == _dateKey(DateTime.now());
  }

  Future<void> _checkOnce() async {
    final now = DateTime.now();
    if (!_isNightTime(now)) return;
    if (await _alreadyShownToday()) return;

    final brightness = await BrightnessService.instance.getCurrentSystemBrightness();
    if (brightness == null || brightness < _kHighBrightnessThreshold) return;

    // Đọc lux SAU CÙNG (không phải đầu tiên) vì đây là bước tốn thời gian
    // nhất (chờ cảm biến trả mẫu, timeout riêng) — chỉ đọc khi giờ giấc +
    // độ sáng đã hợp lệ, đỡ đánh thức cảm biến vô ích mỗi 15 phút cả ngày.
    final lux = await BrightnessService.instance.readAmbientLux();
    if (lux == null || lux >= _kDarkLuxThreshold) return;

    final suggested = (brightness - _kReductionAmount).clamp(_kMinBrightnessFloor, 1.0);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastShownDateKey, _dateKey(now));
    // Lưu lại mức đề xuất để nút "Giảm ngay" trên thông báo áp dụng ĐÚNG con
    // số đã tính lúc gửi thông báo (người dùng có thể bấm nút này rất lâu
    // sau đó, không thể tính lại real-time từ trong notification action).
    await prefs.setDouble(_kPendingBrightnessKey, suggested);

    await NotificationService.instance.showNightModeSuggestion(
      currentPercent: (brightness * 100).round(),
      suggestedPercent: (suggested * 100).round(),
    );
  }

  /// Gọi khi người dùng bấm nút "Giảm ngay" trên thông báo (xem main.dart:
  /// NotificationService.instance.onApplyNightBrightness). Áp dụng đúng mức
  /// độ sáng đã tính và LƯU LẠI lúc gửi thông báo, không tính lại từ đầu.
  Future<bool> applyPendingSuggestion() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(_kPendingBrightnessKey);
    if (value == null) return false;
    final canChange = await BrightnessService.instance.canChangeSystemBrightness();
    if (!canChange) return false;
    return BrightnessService.instance.applySystemBrightness(value);
  }
}
