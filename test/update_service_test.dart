import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateService release parsing', () {
    test('extracts build number from standard prerelease tag', () {
      expect(_parseBuild('build-42'), 42);
    });

    test('returns 0 for invalid tag', () {
      expect(_parseBuild('v1.2.0'), 0);
      expect(_parseBuild(''), 0);
      expect(_parseBuild('build-'), 0);
      expect(_parseBuild('build-abc'), 0);
    });

    test('extracts download url from asset list', () {
      final assets = [
        {'name': 'eye_care_ai.apk', 'browser_download_url': 'https://example.com/app.apk'},
        {'name': 'checksums.txt', 'browser_download_url': 'https://example.com/checksums.txt'},
      ];
      expect(_findApkUrl(assets), 'https://example.com/app.apk');
    });

    test('returns empty string when no apk asset exists', () {
      final assets = [
        {'name': 'checksums.txt', 'browser_download_url': 'https://example.com/checksums.txt'},
      ];
      expect(_findApkUrl(assets), '');
    });

    test('handles empty assets list', () {
      expect(_findApkUrl([]), '');
    });
  });
}

int _parseBuild(String tag) {
  final match = RegExp(r'build-(\d+)').firstMatch(tag);
  return match != null ? int.tryParse(match.group(1) ?? '') ?? 0 : 0;
}

String _findApkUrl(List<dynamic>? assets) {
  if (assets == null) return '';
  final apk = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] ?? '').toString().toLowerCase().endsWith('.apk'),
        orElse: () => {},
  );
  return (apk['browser_download_url'] ?? '').toString();
}