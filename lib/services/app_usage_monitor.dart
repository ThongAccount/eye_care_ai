import 'package:flutter/services.dart';

import '../providers/usage_limit_provider.dart';
import '../services/device_data_service.dart';

/// Kênh native app-lock (MainActivity / AppLockOverlayManager).
const MethodChannel _appLockChannel = MethodChannel('eye_care_ai/app_lock');

/// Khi hết thời gian dùng (budget), yêu cầu NATIVE hiện màn hình chặn PHỦ
/// TRÊN app khác (SYSTEM_ALERT_WINDOW). Không push route Flutter — route
/// chỉ phủ trong app EyeCare AI, không chặn được app ngoài.
/// Data nguồn gióng hệt số Home/Statistics (getAppUsageBreakdownToday),
/// nên "đã dùng 60 phút" ở gate và "3 giờ" ở Home là cùng một con số.
class AppUsageMonitor {
  AppUsageMonitor._();

  static final AppUsageMonitor instance = AppUsageMonitor._();

  bool _gateRequested = false;
  DateTime? _lastChecked;

  // Ngôn ngữ hiện tại của app — native overlay dùng để chọn chuỗi hiển thị.
  bool _isVietnamese = true;

  /// Gọi từ LanguageProvider khi đổi ngôn ngữ — đồng bộ xuống native.
  Future<void> setLanguage(bool vi) async {
    _isVietnamese = vi;
    try {
      await _appLockChannel.invokeMethod<void>('setLanguage', {
        'vi': vi,
      });
    } catch (_) {}
  }

  /// Gọi từ MainShell sau mỗi lần refresh habit (init, poll 60s, resume).
  /// Bounded timeout 6s giống mọi nguồn khác — lỗi → bỏ qua, KHÔNG bao giờ
  /// treo boot (xem quy tắc từ 749f37a).
  Future<void> check(UsageLimitProvider provider) async {
    // Tránh spam native query khi đã kiểm tra < 15s trước.
    final now = DateTime.now();
    if (_lastChecked != null && now.difference(_lastChecked!) < const Duration(seconds: 15)) {
      return;
    }
    _lastChecked = now;

    if (!provider.limit.enabled) {
      // Tắt giới hạn → tháo gate native (nếu đang bật).
      if (_gateRequested) await disarm();
      return;
    }

    try {
      final breakdown = await DeviceDataService.instance
          .getAppUsageBreakdownToday()
          .timeout(const Duration(seconds: 6));
      final consumedSeconds =
          breakdown.fold<int>(0, (sum, e) => sum + e.usage.inSeconds);
      // Cập nhật bộ đếm TRƯỚC khi xét trạng thái khoá — nhờ vậy provider tính
      // lại isLocked (và báo cho AppLockGate vẽ/gỡ màn hình khoá) ngay khi
      // chạm hạn mức.
      //
      // QUAN TRỌNG: bước này KHÔNG được bỏ qua khi gate native đang bật.
      // Trước đây hàm return sớm khi `_gateRequested == true`, nên bộ đếm bị
      // đóng băng đúng lúc user vượt hạn mức → sau khi bấm "+5 phút" app không
      // biết user đã dùng bao nhiêu nữa, và khoá không tự bật lại được khi
      // hết 5 phút.
      provider.updateConsumedMinutes(consumedSeconds ~/ 60);

      if (provider.isLocked) {
        _requestNativeGate();
      } else if (_gateRequested) {
        // Hết hạn mức (đã cấp thêm giờ, sang ngày mới, hoặc tắt giới hạn)
        // → tháo gate native.
        await disarm();
      }
    } catch (_) {
      // Không có quyền usage / lỗi native → không khóa bậy.
    }
  }

  /// Dart yêu cầu NATIVE bật gate (phủ màn hình lên app khác).
  ///
  /// GIỚI HẠN ĐÃ BIẾT: native chỉ hiện overlay khi app đang foreground nằm
  /// trong `blockedPackages` — mà danh sách này rỗng vì chưa có màn hình chọn
  /// app bị chặn (blocked-app picker, ngoài phạm vi fix này). Vì vậy gate
  /// NATIVE hiện chưa chặn được app nào; enforcement thật của app-lock Phase 1
  /// là màn hình khoá TRONG app (AppLockGate, xem
  /// lib/screens/app_lock_overlay.dart) vẽ đè lên toàn bộ app.
  ///
  /// Gate native vẫn được "armed" ở đây để sẵn sàng cho blocked-app picker:
  /// khi có danh sách app bị chặn, chỉ cần truyền danh sách đó xuống là gate
  /// hoạt động, không phải viết lại phần native.
  Future<void> _requestNativeGate() async {
    if (_gateRequested) return;
    _gateRequested = true;
    try {
      await _appLockChannel.invokeMethod<void>('armGate', {
        'blockedPackages': [], // chưa có blocked-app picker — Phase 1 mở rộng
        'vi': _isVietnamese,
      });
    } catch (_) {
      _gateRequested = false;
    }
  }

  /// Gọi khi người dùng tắt limit / bấm +5 phút — tháo gate.
  Future<void> disarm() async {
    _gateRequested = false;
    try {
      await _appLockChannel.invokeMethod<void>('disarmGate');
    } catch (_) {}
  }

  /// Overlay tự đóng (bấm nút trong native / rời app bị chặn) — reset cờ.
  void notifyOverlayClosed() {
    _gateRequested = false;
  }
}