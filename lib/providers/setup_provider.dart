import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/focus_mode_service.dart';
import '../services/usage_service.dart';
import '../utils/permission_helper.dart';

/// Từng bước quyền trong First-Time Setup Wizard, theo đúng thứ tự hiện ra.
/// Thứ tự có chủ đích: Usage Access trước tiên vì gần như MỌI tính năng cốt
/// lõi (thói quen Phone Usage, điểm sức khỏe mắt, thống kê, VÀ CẢ ước lượng
/// giấc ngủ — xem UsageStatsHandler.getSleepEstimate()) đều phụ thuộc vào
/// nó; các quyền còn lại bổ trợ cho từng thói quen/tính năng riêng lẻ.
///
/// BỎ bước `sleep` riêng (trước đây xin quyền Health Connect) — Sleep giờ
/// suy ra từ chính Usage Access ở trên, không cần quyền riêng nữa. THÊM 4
/// bước còn thiếu so với danh sách quyền thật ở màn Cài đặt (Settings ->
/// Quyền & dữ liệu): vị trí (outdoor time), nhận diện hoạt động (bước
/// chân/vận động), popup toàn màn hình lúc hết giờ nghỉ mắt, và chạy nền
/// không giới hạn (báo thức không bị trễ/im lặng do OEM diệt tiến trình).
enum SetupStepId {
  usageAccess,
  notifications,
  location,
  activityRecognition,
  fullScreenIntent,
  batteryOptimization,
  focusMode,
  overlay,
}

class SetupProvider extends ChangeNotifier {
  static const _kWizardCompletedKey = 'pref_setup_wizard_completed';

  bool _wizardCompleted = false;
  bool get wizardCompleted => _wizardCompleted;

  bool _loading = true;
  bool get loading => _loading;

  final Map<SetupStepId, bool> _status = {
    for (final id in SetupStepId.values) id: false,
  };
  Map<SetupStepId, bool> get status => Map.unmodifiable(_status);

  int get grantedCount => _status.values.where((v) => v).length;
  int get totalCount => SetupStepId.values.length;
  bool get allGranted => grantedCount == totalCount;

  SetupProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('SharedPreferences timeout'),
      );
      _wizardCompleted = prefs.getBool(_kWizardCompletedKey) ?? false;
    } catch (e) {
      // I/O khởi động lạnh có thể stall → rơi về mặc định an toàn, không treo splash.
      _wizardCompleted = false;
    }

    try {
      await refreshStatus().timeout(const Duration(seconds: 6));
    } catch (_) {
      _status[SetupStepId.usageAccess] = false;
      _status[SetupStepId.notifications] = false;
      _status[SetupStepId.location] = false;
      _status[SetupStepId.activityRecognition] = false;
      _status[SetupStepId.fullScreenIntent] = true;
      _status[SetupStepId.batteryOptimization] = true;
      _status[SetupStepId.focusMode] = false;
      _status[SetupStepId.overlay] = false;
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> reload() => _init();

  bool isGranted(SetupStepId id) => _status[id] ?? false;

  /// Hỏi lại HỆ THỐNG trạng thái từng quyền — gọi khi mở Wizard, khi quay lại
  /// app sau khi rời sang màn Cài đặt hệ thống, và định kỳ (MainShell) để
  /// banner ở Home luôn đúng thực tế.
  ///
  /// fullScreenIntent & batteryOptimization: Android KHÔNG có API công khai
  /// đọc được trạng thái 2 công tắc này (giống các tile tương ứng ở màn
  /// Cài đặt) — luôn coi là "đã cấp" (true), tile chỉ mang tính "Quản lý"
  /// để mở đúng màn cài đặt cho người dùng tự kiểm tra/bật tay.
  Future<void> refreshStatus() async {
    try {
      late final Future<bool> notificationFuture;
      if (Platform.isAndroid) {
        notificationFuture = Permission.notification.status.then((s) => s.isGranted);
      } else {
        notificationFuture = Future.value(true);
      }

      final results = await Future.wait<bool>([
        UsageService.hasPermission(),
        notificationFuture,
        PermissionHelper.checkLocationPermission(),
        PermissionHelper.checkActivityPermission(),
        FocusModeService.instance.hasAccess(),
        PermissionHelper.checkOverlayPermission(),
      ]).timeout(const Duration(seconds: 6));

      _status[SetupStepId.usageAccess] = results[0];
      _status[SetupStepId.notifications] = results[1];
      _status[SetupStepId.location] = results[2];
      _status[SetupStepId.activityRecognition] = results[3];
      _status[SetupStepId.fullScreenIntent] = true;
      _status[SetupStepId.batteryOptimization] = true;
      _status[SetupStepId.focusMode] = results[4];
      _status[SetupStepId.overlay] = results[5];
      notifyListeners();
    } catch (e) {
      notifyListeners();
    }
  }

  Future<void> markWizardCompleted() async {
    _wizardCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWizardCompletedKey, true);
    notifyListeners();
  }
}
