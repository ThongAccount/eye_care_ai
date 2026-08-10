import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Kiểm tra bản cập nhật mới bằng cách hỏi thẳng GitHub Releases của repo
/// (KHÔNG qua Google Play — vì app không lên Play Store, chỉ phát hành APK
/// trực tiếp qua GitHub Actions, xem .github/workflows/build-apk.yml).
///
/// Cách so sánh phiên bản: workflow build APK luôn gắn thẻ release dạng
/// `build-<run_number>` (ví dụ "build-42") VÀ build APK với đúng
/// `--build-number=<run_number>` (xem ghi chú ở cuối build-apk.yml) — nghĩa là
/// run_number CHÍNH LÀ versionCode thật của APK đó. Nhờ vậy so sánh được
/// "trên GitHub có bản mới hơn máy đang chạy không" chỉ bằng cách so sánh 2
/// số nguyên, không cần app tự theo dõi lịch sử bản đã cài.
class UpdateInfo {
  UpdateInfo({
    required this.buildNumber,
    required this.versionName,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final int buildNumber;
  final String versionName;
  final String downloadUrl;
  final String releaseNotes;
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // TODO: điền đúng chủ repo GitHub đang publish APK (xem link repo trên
  // GitHub của bạn, dạng https://github.com/<owner>/<repo>).
  static const String githubOwner = 'Supertime1236';
  static const String githubRepo = 'eye_care_ai';

  static const String _latestReleaseUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases?per_page=1';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Trả về null nếu không có bản mới hơn (hoặc không kiểm tra được, ví dụ
  /// mất mạng) — gọi nơi dùng không cần phân biệt 2 trường hợp này, đều coi
  /// như "chưa chắc có cập nhật" và im lặng bỏ qua.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null; // sideload APK chỉ áp dụng cho Android

    try {
      final response = await _dio.get(
        _latestReleaseUrl,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final raw = response.data;
      if (raw == null) return null;

      final data = raw is List ? (raw.firstOrNull as Map<String, dynamic>?) : raw as Map<String, dynamic>?;
      if (data == null) return null;

      final tag = (data['tag_name'] ?? '').toString(); // "build-42"
      final match = RegExp(r'build-(\d+)').firstMatch(tag);
      if (match == null) return null;
      final latestBuildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
      if (latestBuildNumber <= 0) return null;

      final assets = (data['assets'] as List?) ?? [];
      final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] ?? '').toString().toLowerCase().endsWith('.apk'),
            orElse: () => {},
          );
      final downloadUrl = (apkAsset['browser_download_url'] ?? '').toString();
      if (downloadUrl.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (latestBuildNumber <= currentBuildNumber) return null;

      return UpdateInfo(
        buildNumber: latestBuildNumber,
        versionName: (data['name'] ?? tag).toString(),
        downloadUrl: downloadUrl,
        releaseNotes: (data['body'] ?? '').toString(),
      );
    } catch (_) {
      // Mất mạng / GitHub rate-limit / repo chưa có release nào -> im lặng bỏ
      // qua, không làm phiền người dùng bằng lỗi kỹ thuật họ không cần biết.
      return null;
    }
  }

  /// Tải file APK về thư mục cache RIÊNG của app (KHÔNG phải thư mục Download
  /// công khai) — bắt buộc phải vậy để FileProvider (xem AndroidManifest.xml +
  /// res/xml/file_paths.xml) có quyền cấp lại quyền đọc file này cho trình
  /// cài đặt gói của hệ thống qua content:// URI.
  Future<File> downloadApk(
    UpdateInfo update, {
    void Function(int received, int total)? onProgress,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final updatesDir = Directory('${cacheDir.path}/updates');
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }
    final file = File('${updatesDir.path}/eye_care_ai-${update.buildNumber}.apk');

    await _dio.download(
      update.downloadUrl,
      file.path,
      onReceiveProgress: onProgress,
    );
    return file;
  }
}
