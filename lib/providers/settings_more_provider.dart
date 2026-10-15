import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/cloud_backup_service.dart';
import '../services/device_data_service.dart';

/// State cho màn hình "Cài đặt thêm" (Settings > More): quyền riêng tư,
/// bảo mật, quản lý dữ liệu, đăng xuất, xóa tài khoản.
///
/// LƯU Ý: file này KHÔNG trùng với `settings_provider.dart` (đơn vị đo,
/// định dạng giờ, thông báo) — được đặt tên riêng `SettingsMoreProvider`
/// để tránh xung đột, và được đăng ký thêm trong main.dart.
class SettingsMoreProvider extends ChangeNotifier {
  // ---- Privacy toggles ----
  static const _kDataCollectionKey = 'data_collection_enabled';
  // "pref_" để CloudBackupService tự cuốn theo khi sao lưu (xem whitelist
  // tiền tố trong cloud_backup_service.dart).
  static const _kCloudBackupKey = 'pref_cloud_backup_enabled';
  // Cài đặt "Hỏi trước khi AI tự thao tác" — mặc định BẬT (an toàn hơn):
  // trước khi AI thật sự đổi mục tiêu/cài đặt thay người dùng (qua
  // AiActionHandler), luôn hỏi xác nhận trước. Người dùng có thể tắt để AI
  // tự áp dụng ngay không cần hỏi.
  static const _kAiConfirmBeforeActingKey = 'pref_ai_confirm_before_acting';
  bool _dataCollection = true;
  bool _cloudBackup = true;
  bool _personalizedAI = false;
  bool _aiConfirmBeforeActing = true;

  bool get dataCollection => _dataCollection;
  bool get cloudBackup => _cloudBackup;
  bool get personalizedAI => _personalizedAI;
  bool get aiConfirmBeforeActing => _aiConfirmBeforeActing;

  /// Load persisted toggle values from SharedPreferences. Call once at app start.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _dataCollection = prefs.getBool(_kDataCollectionKey) ?? true;
    _cloudBackup = prefs.getBool(_kCloudBackupKey) ?? true;
    _aiConfirmBeforeActing = prefs.getBool(_kAiConfirmBeforeActingKey) ?? true;
    notifyListeners();
  }

  void setDataCollection(bool v) {
    _dataCollection = v;
    // Persist and sync with AnalyticsService
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_kDataCollectionKey, v);
    });
    notifyListeners();
  }

  void setCloudBackup(bool v) {
    _cloudBackup = v;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_kCloudBackupKey, v);
    });
    notifyListeners();
    // Bật lên -> đẩy 1 bản sao lưu ngay (không chờ tới lần đồng bộ định kỳ
    // tiếp theo), để người dùng bật xong là biết ngay dữ liệu đã lên mây.
    if (v) {
      unawaited(CloudBackupService.instance.pushBackup());
    }
  }

  void setPersonalizedAI(bool v) {
    _personalizedAI = v;
    notifyListeners();
  }

  void setAiConfirmBeforeActing(bool v) {
    _aiConfirmBeforeActing = v;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_kAiConfirmBeforeActingKey, v);
    });
    notifyListeners();
  }

  // ---- Security toggles ----
  bool _biometricLogin = false;
  bool _twoFactorAuth = false;
  final bool _biometricSupported = true;

  bool get biometricLogin => _biometricLogin;
  bool get twoFactorAuth => _twoFactorAuth;
  bool get biometricSupported => _biometricSupported;

  void setBiometricLogin(bool v) {
    _biometricLogin = v;
    notifyListeners();
  }

  void setTwoFactorAuth(bool v) {
    _twoFactorAuth = v;
    notifyListeners();
  }

  /// Đổi mật khẩu thật qua Firebase (AuthService.changePassword).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return AuthService.instance.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  // ---- Data management ----
  bool _isExporting = false;
  bool _isDeletingLocal = false;
  bool _isDeletingAccount = false;

  bool get isExporting => _isExporting;
  bool get isDeletingLocal => _isDeletingLocal;
  bool get isDeletingAccount => _isDeletingAccount;

  /// Xuất toàn bộ cài đặt + snapshot 7 ngày gần nhất dạng JSON, rồi mở hộp
  /// thoại chia sẻ của hệ điều hành (lưu vào Drive/Files, gửi qua email...).
  /// Không dùng backend vì app hiện chưa có server lưu dữ liệu người dùng —
  /// đây là "export" trung thực nhất có thể: xuất đúng dữ liệu ĐANG có
  /// trên máy, không bịa số.
  Future<void> exportMyData() async {
    _isExporting = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final allPrefs = <String, Object?>{
        for (final key in prefs.getKeys()) key: prefs.get(key),
      };
      final snapshots = await DeviceDataService.instance.loadCurrentWeekSnapshots();
      final data = {
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': allPrefs,
        'last7DaysSnapshots': snapshots
            .map((s) => s == null
                ? null
                : {'score': s.score, 'screenHours': s.screenHours, 'sleepHours': s.sleepHours})
            .toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/eyecare_ai_export.json');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'EyeCare AI — Data Export',
      );
    } catch (_) {
      // Nếu chia sẻ thất bại (bị người dùng huỷ, không có app nhận...),
      // im lặng bỏ qua — UI vẫn tự tắt loading, không cần báo lỗi ồn ào.
    }
    _isExporting = false;
    notifyListeners();
  }

  /// Tạo báo cáo tóm tắt sức khoẻ mắt 7 ngày gần nhất dạng văn bản thuần rồi
  /// chia sẻ — CỐ Ý không dùng thư viện tạo PDF (rất nặng, làm tăng đáng kể
  /// dung lượng APK) để giữ app nhẹ theo đúng yêu cầu tối ưu hiệu năng.
  Future<void> downloadEyeHealthReport() async {
    final snapshots = await DeviceDataService.instance.loadCurrentWeekSnapshots();
    final buffer = StringBuffer()
      ..writeln('EYECARE AI — BÁO CÁO SỨC KHOẺ MẮT')
      ..writeln('Xuất lúc: ${DateTime.now()}')
      ..writeln('=' * 40);
    const days = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    for (var i = 0; i < snapshots.length; i++) {
      final s = snapshots[i];
      buffer.writeln();
      buffer.writeln(days[i]);
      if (s == null) {
        buffer.writeln('  Chưa có dữ liệu');
      } else {
        buffer.writeln('  Điểm sức khoẻ mắt: ${s.score}%');
        buffer.writeln('  Thời gian màn hình: ${s.screenHours.toStringAsFixed(1)}h');
        buffer.writeln('  Giờ ngủ: ${s.sleepHours.toStringAsFixed(1)}h');
      }
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/eyecare_ai_report.txt');
    await file.writeAsString(buffer.toString());

    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'EyeCare AI — Eye Health Report',
      );
    } catch (_) {
      // Người dùng huỷ chia sẻ hoặc không có app nhận — bỏ qua im lặng.
    }
  }

  /// Xóa dữ liệu local (SharedPreferences/cache) — không đụng tới tài khoản.
  Future<void> deleteAllLocalData() async {
    _isDeletingLocal = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isDeletingLocal = false;
    notifyListeners();
  }

  /// Xóa tài khoản thật qua Firebase (AuthService.deleteAccount) + dọn luôn
  /// bản sao lưu trên Firestore (nếu không xoá, dữ liệu cũ sẽ mồ côi mãi vì
  /// UID sau khi xoá tài khoản không bao giờ dùng lại được nữa).
  Future<void> deleteAccount() async {
    _isDeletingAccount = true;
    notifyListeners();
    try {
      await CloudBackupService.instance.deleteBackup();
      await AuthService.instance.deleteAccount();
    } finally {
      _isDeletingAccount = false;
      notifyListeners();
    }
  }

  // ---- Sign out ----
  bool _isSigningOut = false;
  bool get isSigningOut => _isSigningOut;

  /// Đăng xuất thật qua Firebase (AuthService.signOut).
  Future<void> signOut() async {
    _isSigningOut = true;
    notifyListeners();
    try {
      await AuthService.instance.signOut();
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }
}