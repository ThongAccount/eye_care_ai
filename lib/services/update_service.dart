import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'release_asset_picker.dart';

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

// 1 mục nhật ký cập nhật — ứng với 1 GitHub Release. Dùng cho màn hình
// "Nhật ký cập nhật" (ChangelogScreen) trong Cài đặt, liệt kê TẤT CẢ các bản
// đã phát hành (khác với UpdateInfo chỉ giữ bản MỚI NHẤT hiện chưa cài).
class ChangelogEntry {
  ChangelogEntry({
    required this.buildNumber,
    required this.versionName,
    required this.notes,
    required this.publishedAt,
  });

  final int buildNumber;
  final String versionName;
  final String notes;
  final DateTime? publishedAt;
}

class UpdateCheckResult {
  UpdateCheckResult(this.status, this.info, {this.errorDetail});
  final UpdateCheckStatus status;
  final UpdateInfo? info;
  // Chi tiết kỹ thuật (mã lỗi HTTP, thông báo exception...) — CHỈ để debug,
  // không hiển thị thẳng cho người dùng thường (khó hiểu/không cần biết).
  final String? errorDetail;
}

/// Một bản phát hành đã được chuẩn hoá từ JSON của GitHub Releases API.
@immutable
class ReleaseRef {
  const ReleaseRef({
    required this.buildNumber,
    required this.versionName,
    required this.notes,
    required this.downloadUrl,
  });

  final int buildNumber;
  final String versionName;
  final String notes;
  final String downloadUrl;
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Chuẩn hoá ghi chú release trước khi hiển thị.
  ///
  /// Ghi chú release được render bằng widget Text thuần (không phải
  /// markdown) trong modal "Có bản cập nhật" và màn "Nhật ký cập nhật", nên
  /// các body cũ viết theo kiểu markdown ("**Commit:** ...") sẽ hiện ra với
  /// dấu * nguyên văn cho người dùng. Bỏ header legacy và dấu ** để phần
  /// ghi chú luôn hiển thị gọn gàng, đồng thời giữ nguyên các dòng bullet.
  static String sanitizeNotes(String body) {
    final lines = body
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('**Commit:**'))
        .map((l) => l.replaceAll('**', '').trimRight())
        .toList();
    return lines.join('\n').trim();
  }

  // Chủ repo GitHub đang publish APK qua workflow build-apk.yml. Nếu nút
  // "Kiểm tra cập nhật" LUÔN báo lỗi/luôn "đang dùng bản mới nhất" dù rõ
  // ràng đã có bản mới, viêc ĐẦU TIÊN cần xác minh là 2 hằng số này khớp
  // ĐÚNG với repo thật (https://github.com/<owner>/<repo>) — sai 1 trong 2
  // sẽ khiến GitHub trả về 404 cho MỌI request, bị nuốt thành "checkForUpdate
  // trả về null" ở bản tự động, và hiện lỗi rõ ràng hơn ở nút kiểm tra thủ
  // công (xem checkForUpdateVerbose).
  static const String githubOwner = 'ThongAccount';
  static const String githubRepo = 'eye_care_ai';

  static const String _latestReleaseUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases?per_page=20';

  static String _releasesUrl(int limit) =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases?per_page=$limit';

  /// Chuyển JSON của GitHub Releases API thành danh sách [ReleaseRef].
  ///
  /// - Bỏ qua release có tag không đúng định dạng `build-<số>` (release tạo
  ///   thủ công) — cùng quy tắc với logic so sánh trước đây.
  /// - Sắp theo build mới nhất trước.
  /// - Ghi chú đã qua [sanitizeNotes].
  /// - File APK được chọn theo SỐ BUILD của release (xem
  ///   [pickReleaseApkUrl]) — không lấy asset `.apk` đầu tiên, vì thứ tự
  ///   assets của GitHub có thể đưa APK cũ lên trước.
  ///
  /// Tách thành hàm thuần (không gọi mạng) để unit test được.
  static List<ReleaseRef> parseReleases(dynamic raw) {
    final items = raw is List
        ? raw
        : (raw == null ? const <dynamic>[] : <dynamic>[raw]);
    final parsed = <ReleaseRef>[];
    for (final item in items) {
      if (item is! Map) continue;
      final tag = (item['tag_name'] ?? '').toString();
      final match = RegExp(r'build-(\d+)').firstMatch(tag);
      if (match == null) continue;
      final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
      if (buildNumber <= 0) continue;

      // Chọn APK THEO SỐ BUILD của release, không lấy asset .apk đầu tiên —
      // lý do và lịch sử lỗi xem release_asset_picker.dart.
      final downloadUrl = pickReleaseApkUrl(
        (item['assets'] as List?) ?? const [],
        buildNumber,
      );

      parsed.add(ReleaseRef(
        buildNumber: buildNumber,
        versionName: (item['name'] ?? tag).toString(),
        notes: sanitizeNotes((item['body'] ?? '').toString()),
        downloadUrl: downloadUrl,
      ));
    }
    parsed.sort((a, b) => b.buildNumber.compareTo(a.buildNumber));
    return parsed;
  }

  /// Gộp ghi chú của MỌI bản phát hành mới hơn bản đang chạy.
  ///
  /// Người dùng thường bỏ qua nhiều bản (build 84 -> build 90), nên chỉ hiện
  /// ghi chú của bản mới nhất sẽ giấu mọi thay đổi ở giữa. Gom lại theo thứ tự
  /// mới -> cũ, mỗi bản một tiêu đề, để modal "Có bản cập nhật" cho người dùng
  /// biết đã có gì mới kể từ bản họ đang dùng.
  static String aggregateNotes(List<ReleaseRef> newerReleases) {
    return newerReleases
        .where((r) => r.notes.trim().isNotEmpty)
        .map((r) => '${r.versionName}\n${r.notes.trim()}')
        .join('\n\n');
  }

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

      final releases = UpdateService.parseReleases(raw);
      if (releases.isEmpty) {
        debugPrint('[UpdateService] Không có release nào khớp định dạng "build-<số>" '
            '(repo có thể chưa có release, hoặc release được tạo thủ công ngoài workflow).');
        return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'no_releases_found');
      }

      final latest = releases.first;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // Mọi bản phát hành mới hơn bản đang chạy — người dùng có thể bỏ qua
      // nhiều bản, và họ nên thấy đủ mọi thay đổi kể từ bản của họ.
      final newer =
          releases.where((r) => r.buildNumber > currentBuildNumber).toList();

      if (newer.isEmpty) {
        return UpdateCheckResult(UpdateCheckStatus.upToDate, null);
      }

      if (latest.downloadUrl.isEmpty) {
        return UpdateCheckResult(UpdateCheckStatus.failed, null, errorDetail: 'no_apk_asset');
      }

      return UpdateCheckResult(
        UpdateCheckStatus.updateAvailable,
        UpdateInfo(
          buildNumber: latest.buildNumber,
          versionName: latest.versionName,
          downloadUrl: latest.downloadUrl,
          releaseNotes: UpdateService.aggregateNotes(newer),
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

  /// Lấy danh sách bản phát hành gần đây để hiện màn hình "Nhật ký cập
  /// nhật" trong Cài đặt — khác [checkForUpdateVerbose] chỉ lấy đúng 1 bản
  /// MỚI NHẤT để so sánh với máy đang chạy. Trả về null nếu gọi API thất
  /// bại (mất mạng, repo private, hết quota...); trả về danh sách rỗng nếu
  /// repo chưa có release nào — 2 trường hợp này khác nhau nên UI cần phân
  /// biệt (lỗi -> cho bấm thử lại, rỗng -> hiện thông báo "chưa có gì").
  Future<List<ChangelogEntry>?> fetchChangelog({int limit = 20}) async {
    if (!Platform.isAndroid) return null;
    try {
      final response = await _dio.get(
        _releasesUrl(limit),
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final raw = response.data;
      if (raw is! List) return null;

      final entries = <ChangelogEntry>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final tag = (item['tag_name'] ?? '').toString();
        final match = RegExp(r'build-(\d+)').firstMatch(tag);
        // Bỏ qua release không đúng định dạng `build-<số>` (release tạo thủ
        // công) — chỉ liệt kê những bản thật sự do workflow build-apk.yml
        // phát hành, khớp với logic ở checkForUpdateVerbose.
        if (match == null) continue;
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        if (buildNumber <= 0) continue;

        entries.add(ChangelogEntry(
          buildNumber: buildNumber,
          versionName: (item['name'] ?? tag).toString(),
          notes: UpdateService.sanitizeNotes(
            (item['body'] ?? '').toString(),
          ),
          publishedAt: DateTime.tryParse((item['published_at'] ?? '').toString()),
        ));
      }
      // Sắp theo build mới nhất trước — GitHub API thường đã trả đúng thứ
      // tự này, nhưng sắp lại tường minh để không phụ thuộc vào giả định đó.
      entries.sort((a, b) => b.buildNumber.compareTo(a.buildNumber));
      return entries;
    } on DioException catch (e) {
      debugPrint('[UpdateService] Gọi GitHub API (changelog) thất bại: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[UpdateService] Lỗi không xác định khi tải nhật ký cập nhật: $e');
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