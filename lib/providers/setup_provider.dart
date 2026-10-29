import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/focus_mode_service.dart';
import '../services/usage_service.dart';
import '../utils/permission_helper.dart';
import '../utils/platform_capability.dart';

/// Từng bước quyền trong First-Time Setup Wizard, theo đúng thứ tự hiện ra.
/// Thứ tự có chủ đích: quyền THÔNG BÁO đến trước, vì nhắc nghỉ mắt 20-20-20
/// chỉ cần quyền này và đó là giá trị cốt lõi của app. Usage Access để CUỐI
/// vì nó là chuyển hướng sang Cài đặt hệ thống (không có popup, người dùng
/// phải tự bật tay) — hỏi nó sớm làm nhiều người dùng bỏ luôn cả wizard và
/// mất luôn quyền thông báo. Các quyền còn lại bổ trợ cho từng thói quen/tính
/// năng riêng lẻ. Thứ tự cụ thể: `kSetupWizardStepOrder` bên dưới — xem
/// docs/growth/retention-plan.md (Move 3).
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

/// Thứ tự các bước trong Setup Wizard — nguồn DUY NHẤT (xem
/// setup_wizard_screen.dart, dựng các trang theo danh sách này).
///
/// VALUE FIRST: thông báo (runtime popup, một chạm) → các quyền phụ trợ →
/// Usage Access (chuyển hướng Cài đặt hệ thống) CUỐI CÙNG. Người dùng bỏ
/// qua ở bước cuối vẫn đã có quyền thông báo để nhận nhắc 20-20-20.
const List<SetupStepId> kSetupWizardStepOrder = [
  SetupStepId.notifications,
  SetupStepId.location,
  SetupStepId.activityRecognition,
  SetupStepId.fullScreenIntent,
  SetupStepId.batteryOptimization,
  SetupStepId.focusMode,
  SetupStepId.overlay,
  SetupStepId.usageAccess,
];

/// Các bước CHỈ tồn tại trên Android — iOS không có API tương đương, nên trên
/// iOS lời gọi xuống native ném lỗi và bước đó không bao giờ "được cấp"
/// (kể cả hai bước Android cho phép, vì chúng chẳng có màn hình cài đặt nào
/// để mở). Hỏi chúng trên iOS là hỏi quyền ma.
const Set<SetupStepId> kAndroidOnlySetupSteps = {
  SetupStepId.usageAccess,
  SetupStepId.activityRecognition,
  SetupStepId.fullScreenIntent,
  SetupStepId.batteryOptimization,
  SetupStepId.focusMode,
  SetupStepId.overlay,
};

/// Các bước wizard QUAN TRỌNG ở nền tảng này, đúng thứ tự hiển thị.
///
/// Android: cả 8 bước. iOS: chỉ còn thông báo + vị trí — hai quyền có popup
/// hệ thống thật. Tham số [platform] chỉ để test ép nền tảng; khi chạy thật
/// lấy `defaultTargetPlatform`.
List<SetupStepId> applicableSetupSteps([TargetPlatform? platform]) {
  if (hasAndroidNativeFeatures(platform)) return kSetupWizardStepOrder;
  return kSetupWizardStepOrder
      .where((id) => !kAndroidOnlySetupSteps.contains(id))
      .toList();
}

/// Điều kiện để banner "hoàn tất thiết lập" ở Home biến mất: MỌI bước áp dụng
/// cho nền tảng này đã được cấp — không đếm các bước iOS không có.
bool allApplicableGranted(
  Set<SetupStepId> grantedIds, [
  TargetPlatform? platform,
]) =>
    applicableSetupSteps(platform).every(grantedIds.contains);

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

  /// Số bước đã cấp / tổng số bước — chỉ tính các bước ÁP DỤNG cho nền tảng
  /// hiện tại. Trên iOS còn 2 bước, nên banner Home về lý thuyết có thể tắt
  /// được; nếu đếm cả 8 bước thì 6 bước iOS không có sẽ chặn banner mãi mãi.
  int get grantedCount => applicableSetupSteps()
      .where((id) => isGranted(id))
      .length;
  int get totalCount => applicableSetupSteps().length;

  Set<SetupStepId> get _grantedIds =>
      {for (final id in SetupStepId.values) if (isGranted(id)) id};

  bool get allGranted => allApplicableGranted(_grantedIds);

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
  /// Chỉ hỏi các bước áp dụng cho nền tảng này (`applicableSetupSteps`) — trên
  /// iOS không hỏi Usage Access / DND / overlay vì các kênh native đó không
  /// tồn tại, lời gọi sẽ ném lỗi và kết quả luôn là false.
  ///
  /// fullScreenIntent & batteryOptimization: Android KHÔNG có API công khai
  /// đọc được trạng thái 2 công tắc này (giống các tile tương ứng ở màn
  /// Cài đặt) — luôn coi là "đã cấp" (true), tile chỉ mang tính "Quản lý"
  /// để mở đúng màn cài đặt cho người dùng tự kiểm tra/bật tay.
  Future<void> refreshStatus() async {
    try {
      final applicable = applicableSetupSteps();
      final results = await Future.wait<bool>([
        for (final id in applicable) _queryStep(id),
      ]).timeout(const Duration(seconds: 6));

      for (var i = 0; i < applicable.length; i++) {
        _status[applicable[i]] = results[i];
      }
      // Bước không áp dụng: không hỏi, không đếm — để "true" để mọi nơi đọc
      // `isGranted` thấy nhất quán (chúng không xuất hiện trong wizard).
      for (final id in SetupStepId.values) {
        if (!applicable.contains(id)) _status[id] = true;
      }
      notifyListeners();
    } catch (e) {
      notifyListeners();
    }
  }

  /// Trạng thái của MỘT bước — giữ nguyên cách hỏi từng quyền như trước, chỉ
  /// gom về một chỗ để refreshStatus lọc được theo nền tảng.
  Future<bool> _queryStep(SetupStepId id) async {
    switch (id) {
      case SetupStepId.usageAccess:
        return UsageService.hasPermission();
      case SetupStepId.notifications:
        if (Platform.isAndroid) {
          final status = await Permission.notification.status;
          return status.isGranted;
        }
        // iOS: quyền thông báo hỏi được bằng popup hệ thống, coi là xong ở
        // bước hiển thị (provider chỉ bám trạng thái thật của Android).
        return true;
      case SetupStepId.location:
        return PermissionHelper.checkLocationPermission();
      case SetupStepId.activityRecognition:
        return PermissionHelper.checkActivityPermission();
      case SetupStepId.fullScreenIntent:
      case SetupStepId.batteryOptimization:
        return true;
      case SetupStepId.focusMode:
        return FocusModeService.instance.hasAccess();
      case SetupStepId.overlay:
        return PermissionHelper.checkOverlayPermission();
    }
  }

  Future<void> markWizardCompleted() async {
    _wizardCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWizardCompletedKey, true);
    notifyListeners();
  }
}
