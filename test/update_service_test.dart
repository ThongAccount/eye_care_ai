import 'package:eye_care_ai/services/release_asset_picker.dart';
import 'package:eye_care_ai/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test dùng ĐÚNG code production (trước đây test tự viết lại logic lấy APK
/// trong file test, nên không bắt được lỗi thật: app lấy asset `.apk` đầu
/// tiên trong khi GitHub trả asset APK cũ lên trước -> tải nhầm bản cũ).
void main() {
  group('UpdateService.parseReleases', () {
    test('extracts build number from standard prerelease tag', () {
      final releases = UpdateService.parseReleases([
        {'tag_name': 'build-42', 'name': 'v1.2.0 (build 42)', 'assets': []},
      ]);
      expect(releases.length, 1);
      expect(releases.first.buildNumber, 42);
    });

    test('skips releases whose tag is not build-<n>', () {
      final releases = UpdateService.parseReleases([
        {'tag_name': 'v1.2.0', 'assets': []},
        {'tag_name': '', 'assets': []},
        {'tag_name': 'build-', 'assets': []},
        {'tag_name': 'build-abc', 'assets': []},
      ]);
      expect(releases, isEmpty);
    });

    test('sorts releases by build number, newest first', () {
      final releases = UpdateService.parseReleases([
        {'tag_name': 'build-57', 'assets': []},
        {'tag_name': 'build-92', 'assets': []},
        {'tag_name': 'build-66', 'assets': []},
      ]);
      expect(
        releases.map((r) => r.buildNumber).toList(),
        [92, 66, 57],
      );
    });

    test('picks the APK matching the release build even when stale APKs '
        'are attached first', () {
      // Đúng dữ liệu thật của release build-92 trên GitHub: 2 APK cũ
      // (build 57/58, từ thư mục release/ bị commit nhầm vào git) đứng
      // TRƯỚC APK đúng trong danh sách assets.
      final releases = UpdateService.parseReleases([
        {
          'tag_name': 'build-92',
          'name': 'v1.4.0+alpha (build 92)',
          'assets': [
            {
              'name': 'eye_care_ai-1.2.1+alpha-76243979-build58.apk',
              'browser_download_url':
                  'https://example.com/eye_care_ai-1.2.1+alpha-76243979-build58.apk',
            },
            {
              'name': 'eye_care_ai-1.2.1+alpha-f235d329-build57.apk',
              'browser_download_url':
                  'https://example.com/eye_care_ai-1.2.1+alpha-f235d329-build57.apk',
            },
            {
              'name': 'eye_care_ai-1.4.0+alpha-9bf9069b-build92.apk',
              'browser_download_url':
                  'https://example.com/eye_care_ai-1.4.0+alpha-9bf9069b-build92.apk',
            },
          ],
        },
      ]);

      expect(releases.first.downloadUrl,
          'https://example.com/eye_care_ai-1.4.0+alpha-9bf9069b-build92.apk');
    });

    test('falls back to the highest build number when no exact match exists',
        () {
      final releases = UpdateService.parseReleases([
        {
          'tag_name': 'build-66',
          'assets': [
            {
              'name': 'eye_care_ai-1.2.1+alpha-76243979-build58.apk',
              'browser_download_url': 'https://example.com/build58.apk',
            },
            {
              'name': 'eye_care_ai-1.2.1+alpha-f235d329-build57.apk',
              'browser_download_url': 'https://example.com/build57.apk',
            },
          ],
        },
      ]);

      expect(releases.first.downloadUrl, 'https://example.com/build58.apk');
    });

    test('leaves download url empty when the release has no APK', () {
      final releases = UpdateService.parseReleases([
        {
          'tag_name': 'build-92',
          'assets': [
            {
              'name': 'checksums.txt',
              'browser_download_url': 'https://example.com/checksums.txt',
            },
          ],
        },
      ]);

      expect(releases.first.downloadUrl, isEmpty);
    });
  });

  group('pickReleaseApkUrl', () {
    test('prefers the exact build match over other APKs', () {
      final url = pickReleaseApkUrl([
        {'name': 'app-build58.apk', 'browser_download_url': 'https://x/58.apk'},
        {'name': 'app-build92.apk', 'browser_download_url': 'https://x/92.apk'},
      ], 92);
      expect(url, 'https://x/92.apk');
    });

    test('does not confuse build 9 with build 92', () {
      final url = pickReleaseApkUrl([
        {'name': 'app-build92.apk', 'browser_download_url': 'https://x/92.apk'},
        {'name': 'app-build9.apk', 'browser_download_url': 'https://x/9.apk'},
      ], 9);
      expect(url, 'https://x/9.apk');
    });

    test('ignores non-APK assets', () {
      final url = pickReleaseApkUrl([
        {'name': 'app.aab', 'browser_download_url': 'https://x/app.aab'},
        {'name': 'checksums.txt', 'browser_download_url': 'https://x/sums.txt'},
      ], 92);
      expect(url, isEmpty);
    });

    test('handles null and empty asset lists', () {
      expect(pickReleaseApkUrl(null, 92), isEmpty);
      expect(pickReleaseApkUrl([], 92), isEmpty);
    });

    test('falls back to the first APK when no build number is in the name',
        () {
      final url = pickReleaseApkUrl([
        {'name': 'app.apk', 'browser_download_url': 'https://x/app.apk'},
      ], 92);
      expect(url, 'https://x/app.apk');
    });
  });
}
