import 'package:flutter_test/flutter_test.dart';
import 'package:eye_care_ai/services/update_service.dart';

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
}
