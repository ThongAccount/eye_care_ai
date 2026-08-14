import 'package:flutter/material.dart';
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

    if (!provider.limit.enabled || _gateRequested) return;

    try {
      final breakdown = await DeviceDataService.instance
          .getAppUsageBreakdownToday()
          .timeout(const Duration(seconds: 6));
      final consumedSeconds =
          breakdown.fold<int>(0, (sum, e) => sum + e.usage.inSeconds);
      provider.updateConsumedMinutes(consumedSeconds ~/ 60);

      if (provider.isLocked) {
        _requestNativeGate();
      }
    } catch (_) {
      // Không có quyền usage / lỗi native → không khóa bậy.
    }
  }

  Future<void> _requestNativeGate() async {
    if (_gateRequested) return;
    _gateRequested = true;
    try {
      await _appLockChannel.invokeMethod<void>('armGate', {
        'blockedPackages': [], // chưa có blocked-app picker — Phase 1 mở rộng
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