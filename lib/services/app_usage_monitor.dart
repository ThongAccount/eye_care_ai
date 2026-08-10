import 'package:flutter/material.dart';

import '../navigation/root_navigator.dart';
import '../providers/usage_limit_provider.dart';
import '../screens/app_lock_overlay.dart';
import '../services/device_data_service.dart';

/// Màn hình khoá khi hết giờ (Phase 1) — đẩy overlay toàn màn hình lên
/// navigator GỐC (_rootNavigatorKey/lúc trước), KHÔNG thay widget từng màn.
/// Data nguồn gióng hệt số Home/Statistics hiển thị (getAppUsageBreakdownToday),
/// nên “đã dùng 60 phút” ở khóa và “3 giờ” ở Home là cùng một con số.
class AppUsageMonitor {
  AppUsageMonitor._();

  static final AppUsageMonitor instance = AppUsageMonitor._();

  bool _overlayOpen = false;
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

    if (!provider.limit.enabled || _overlayOpen) return;

    try {
      final breakdown = await DeviceDataService.instance
          .getAppUsageBreakdownToday()
          .timeout(const Duration(seconds: 6));
      final consumedSeconds =
          breakdown.fold<int>(0, (sum, e) => sum + e.usage.inSeconds);
      provider.updateConsumedMinutes(consumedSeconds ~/ 60);

      if (provider.isLocked) {
        _showLockOverlay();
      }
    } catch (_) {
      // Không có quyền usage / lỗi native → không khóa bậy.
    }
  }

  void _showLockOverlay() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null || _overlayOpen) return;
    _overlayOpen = true;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AppLockOverlay(
          onDismissed: () => _overlayOpen = false,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Overlay tự đóng (bấm +5) — reset cờ để lần check sau có thể mở lại.
  void notifyOverlayClosed() {
    _overlayOpen = false;
  }
}