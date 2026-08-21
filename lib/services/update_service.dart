import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
///
/// LƯU Ý QUAN TRỌNG nếu "kiểm tra cập nhật" báo "đang dùng bản mới nhất" một
/// cách SAI (đã có release mới thật trên GitHub): cơ chế này CHỈ nhận diện
/// được release có tag đúng định dạng `build-<số>` — tự tạo release thủ công
/// trên GitHub UI với tag khác (vd "v1.3.0") sẽ KHÔNG được nhận diện, phải
/// tạo release bằng cách chạy đúng workflow `build-apk.yml`. Ngoài ra nếu
/// repo đang ở chế độ PRIVATE, các request KHÔNG XÁC THỰC (app không mang
/// theo token GitHub) sẽ luôn nhận lỗi 404 — repo phải PUBLIC thì tính năng
/// này mới hoạt động được cho người dùng cuối.
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

/// Dùng cho nút "Kiểm tra cập nhật" thủ công (Settings) — khác với
/// [UpdateService.checkForUpdate] (dùng cho lần tự động kiểm tra lúc mở app,
/// vốn cố tình im lặng khi lỗi), ở đây CẦN phân biệt rõ 3 trường hợp để
/// người dùng/người debug biết chính xác vì sao không thấy bản cập nhật —
/// "đang dùng bản mới nhất" và "kiểm tra thất bại" là 2 tình huống khác hẳn
/// nhau nhưng trước đây gộp chung làm một (đều trả về null), khiến không
/// thể phân biệt được.
enum UpdateCheckStatus { upToDate, updateAvailable, failed }

class UpdateCheckResult {
  UpdateCheckResult(this.status, this.info, {this.errorDetail});
  final UpdateCheckStatus status;
  final UpdateInfo? info;
  // Chi tiết kỹ thuật (mã lỗi HTTP, thông báo exception...) — CHỈ để debug,
  // không hiển thị thẳng cho người dùng thường (khó hiểu/không cần biết).
  final String? errorDetail;
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

// Chủ repo GitHub đang publish APK qua workflow build-apk.yml. Nếu nút
// "Kiểm tra cập nhật" LUÔN báo lỗi/luôn "đang dùng bản mới nhất" dù rõ
// ràng đã có bản mới, việc ĐẦU TIÊN cần xác minh là 2 hằng số này khớp
// ĐÚNG với repo thật (https://github.com/<owner>/<repo>) — sai 1 trong 2
// sẽ khiến GitHub trả về 404 cho MỌI request, bị nuốt thành "checkForUpdate
// trả về null" ở bản tự động, và hiện lỗi rõ ràng hơn ở nút kiểm tra thủ
// công (xem checkForUpdateVerbose).
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
  /// như "chưa chắc có cập nhật" và im lặng bỏ qua. Dùng cho lần tự động
  /// kiểm tra lúc mở app — muốn biết rõ lý do thất bại, dùng
  /// [checkForUpdateVerbose] thay thế (nút kiểm tra thủ công).
  Future<UpdateInfo?> checkForUpdate() async {
    final result = await checkForUpdateVerbose();
    return result.info;
  }

  /// Bản "nói rõ lý do" — dùng cho nút kiểm tra thủ công trong Settings.
  Future<UpdateCheckResult> checkForUpdateVerbose() async {
    if (!Platform.isAndroid) {
      return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'not_android');
    }

    try {
      final response = await _dio.get(
        _latestReleaseUrl,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final raw = response.data;
      if (raw == null) {
        return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'empty_response');
      }

      final data = raw is List ? (raw.firstOrNull as Map<String, dynamic>?) : raw as Map<String, dynamic>?;
      if (data == null) {
        // raw is List rỗng -> repo CHƯA CÓ release nào (khác với lỗi mạng).
        return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'no_releases_found');
      }

      final tag = (data['tag_name'] ?? '').toString(); // "build-42"
      final match = RegExp(r'build-(\d+)').firstMatch(tag);
      if (match == null) {
        debugPrint('[UpdateService] Release mới nhất có tag "$tag" không khớp định dạng "build-<số>" '
            '— có thể release này được tạo thủ công thay vì qua workflow build-apk.yml.');
        return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'tag_format_mismatch:$tag');
      }
      final latestBuildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
      if (latestBuildNumber <= 0) {
        return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'invalid_build_number');
      }

      final assets = (data['assets'] as List?) ?? [];
      final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] ?? '').toString().toLowerCase().endsWith('.apk'),
            orElse: () => {},
          );
      final downloadUrl = (apkAsset['browser_download_url'] ?? '').toString();
      if (downloadUrl.isEmpty) {
        return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'no_apk_asset');
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (latestBuildNumber <= currentBuildNumber) {
        return UpdateCheckResult(UpdateCheckStatus.upToDate, null);
      }

      return UpdateCheckResult(
        UpdateCheckStatus.updateAvailable,
        UpdateInfo(
          buildNumber: latestBuildNumber,
          versionName: (data['name'] ?? tag).toString(),
          downloadUrl: downloadUrl,
          releaseNotes: (data['body'] ?? '').toString(),
        ),
      );
    } on DioException catch (e) {
      // Lỗi hay gặp nhất trong nhóm này: 404 (sai githubOwner/githubRepo,
      // hoặc repo đang PRIVATE nên request không xác thực bị từ chối) và 403
      // (vượt giới hạn 60 request/giờ không xác thực của GitHub API — dễ xảy
      // ra khi nhiều người dùng app cùng lúc gọi từ chung 1 địa chỉ IP/NAT).
      final status = e.response?.statusCode;
      debugPrint('[UpdateService] Gọi GitHub API thất bại (HTTP $status): ${e.message}');
      return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'http_$status');
    } catch (e) {
      debugPrint('[UpdateService] Lỗi không xác định khi kiểm tra cập nhật: $e');
      return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'unknown:$e');
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