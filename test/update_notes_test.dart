import 'package:flutter_test/flutter_test.dart';
import 'package:eye_care_ai/services/update_service.dart';

Map<String, dynamic> _release({
  required String tag,
  required String name,
  String body = '',
  String apkName = 'app.apk',
}) {
  return <String, dynamic>{
    'tag_name': tag,
    'name': name,
    'body': body,
    'assets': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': apkName,
        'browser_download_url': 'https://example.test/$apkName',
      },
    ],
  };
}

void main() {
  group('UpdateService.sanitizeNotes', () {
    test('drops the legacy "**Commit:**" header', () {
      final out = UpdateService.sanitizeNotes(
        '**Commit:** abc1234\n\n- Something new\n',
      );

      expect(out.contains('Commit:'), isFalse);
      expect(out.contains('abc1234'), isFalse);
      expect(out.contains('- Something new'), isTrue);
    });

    test('removes markdown bold markers', () {
      expect(
        UpdateService.sanitizeNotes('**Version:** 1.4.0'),
        'Version: 1.4.0',
      );
    });

    test('keeps bullet lines intact', () {
      expect(UpdateService.sanitizeNotes('- A\n- B'), '- A\n- B');
    });

    test('keeps indented description lines under a bullet', () {
      expect(
        UpdateService.sanitizeNotes('- A\n  detail line'),
        '- A\n  detail line',
      );
    });

    test('returns an empty string for an empty body', () {
      expect(UpdateService.sanitizeNotes('   \n\n'), '');
    });
  });

  group('UpdateService.parseReleases', () {
    test('keeps only releases tagged build-<number>', () {
      final parsed = UpdateService.parseReleases(<Map<String, dynamic>>[
        _release(tag: 'build-90', name: 'v1.4.0 (build 90)'),
        _release(tag: 'v1.3.0', name: 'manual release'),
      ]);

      expect(parsed.length, 1);
      expect(parsed.first.buildNumber, 90);
      expect(parsed.first.versionName, 'v1.4.0 (build 90)');
    });

    test('sorts newest build first', () {
      final parsed = UpdateService.parseReleases(<Map<String, dynamic>>[
        _release(tag: 'build-87', name: 'old'),
        _release(tag: 'build-90', name: 'new'),
        _release(tag: 'build-89', name: 'middle'),
      ]);

      expect(
        parsed.map((r) => r.buildNumber).toList(),
        <int>[90, 89, 87],
      );
    });

    test('takes the apk asset url', () {
      final parsed = UpdateService.parseReleases(<Map<String, dynamic>>[
        _release(tag: 'build-90', name: 'v1', apkName: 'app-90.apk'),
      ]);

      expect(parsed.first.downloadUrl, 'https://example.test/app-90.apk');
    });

    test('returns an empty list for a non-list payload', () {
      expect(UpdateService.parseReleases(null), isEmpty);
      expect(UpdateService.parseReleases(<dynamic>[]), isEmpty);
    });
  });

  group('UpdateService.aggregateNotes', () {
    test('joins the notes of every newer release, newest first', () {
      final parsed = UpdateService.parseReleases(<Map<String, dynamic>>[
        _release(
          tag: 'build-90',
          name: 'v1.4.0 (build 90)',
          body: '- Newest change',
        ),
        _release(
          tag: 'build-89',
          name: 'v1.4.0 (build 89)',
          body: '- Middle change',
        ),
      ]);

      final notes = UpdateService.aggregateNotes(parsed);

      expect(notes.contains('Newest change'), isTrue);
      expect(notes.contains('Middle change'), isTrue);
      expect(
        notes.indexOf('Newest change') < notes.indexOf('Middle change'),
        isTrue,
      );
      expect(notes.contains('v1.4.0 (build 90)'), isTrue);
    });

    test('skips releases whose notes are empty', () {
      final parsed = UpdateService.parseReleases(<Map<String, dynamic>>[
        _release(tag: 'build-90', name: 'v1', body: ''),
        _release(tag: 'build-89', name: 'v0', body: '- Something'),
      ]);

      final notes = UpdateService.aggregateNotes(parsed);

      expect(notes.contains('v1'), isFalse);
      expect(notes.contains('Something'), isTrue);
    });
  });
}
