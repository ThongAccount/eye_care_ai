// Chọn đúng file APK thuộc về một release trên GitHub Releases.
//
// VÌ SAO CẦN FILE NÀY (lỗi thật đã xảy ra trong production):
// Thư mục `release/` từng được commit vào git (2 APK build 57 và build 58,
// thêm bằng commit 6592129) dù `.gitignore` đã có `/release/`. Workflow
// build-apk.yml copy APK mới vào `release/` rồi đính kèm bằng glob
// `release/*.apk` — nên MỌI release mới đều bị kèm thêm 2 APK cũ đó.
// GitHub trả assets theo thứ tự tải lên, APK cũ đứng trước, còn logic
// cũ của app lấy asset `.apk` ĐẦU TIÊN -> app tải nhầm APK build 57/58
// (versionCode 58) thay vì bản mới (versionCode 92). Android từ chối cài
// vì đây là hạ cấp phiên bản, người dùng bị kẹt ở bản cũ.
//
// CÁCH SỬA: không đoán theo thứ tự, mà chọn theo SỐ BUILD của chính release.
// Ưu tiên asset có tên khớp đúng số build (ví dụ `...-build92.apk`), nếu
// không có thì lấy APK có số build CAO NHẤT tìm được trong tên, và chỉ
// fallback về APK đầu tiên khi không đọc được số build nào.

/// Trả về URL tải APK đúng cho release có [buildNumber].
///
/// Trả về chuỗi rỗng nếu release không đính kèm file APK nào.
String pickReleaseApkUrl(List<dynamic>? assets, int buildNumber) {
  if (assets == null || assets.isEmpty) return '';

  final apks = <Map<dynamic, dynamic>>[];
  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = (asset['name'] ?? '').toString().toLowerCase();
    if (name.endsWith('.apk')) apks.add(asset);
  }
  if (apks.isEmpty) return '';

  // 1) Asset khớp CHÍNH XÁC số build của release — trường hợp bình thường.
  final exact = RegExp(
    'build[-_]?$buildNumber\\.apk\$',
    caseSensitive: false,
  );
  for (final asset in apks) {
    final name = (asset['name'] ?? '').toString();
    if (exact.hasMatch(name)) {
      return (asset['browser_download_url'] ?? '').toString();
    }
  }

  // 2) Không có asset khớp chính xác -> lấy APK có số build CAO NHẤT tìm
  // được trong tên, thay vì mù theo thứ tự GitHub trả về.
  Map<dynamic, dynamic>? best;
  var bestBuild = -1;
  for (final asset in apks) {
    final name = (asset['name'] ?? '').toString();
    final match = RegExp('build[-_]?(\\d+)\\.apk\$', caseSensitive: false)
        .firstMatch(name);
    if (match == null) continue;
    final parsed = int.tryParse(match.group(1) ?? '') ?? -1;
    if (parsed > bestBuild) {
      bestBuild = parsed;
      best = asset;
    }
  }
  final chosen = best ?? apks.first;
  return (chosen['browser_download_url'] ?? '').toString();
}
