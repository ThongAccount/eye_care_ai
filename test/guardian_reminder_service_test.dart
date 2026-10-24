import 'package:flutter_test/flutter_test.dart';
import 'package:eye_care_ai/services/guardian_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuardianReminderService.shouldNotify', () {
    const today = '2026-10-24';

    test('does not notify without a guardian email', () {
      expect(
        GuardianReminderService.shouldNotify(
          guardianEmail: '   ',
          screenHours: 9,
          targetHours: 6,
          notifiedDate: null,
          today: today,
        ),
        isFalse,
      );
    });

    test('does not notify while screen time is below the target', () {
      expect(
        GuardianReminderService.shouldNotify(
          guardianEmail: 'guardian@example.com',
          screenHours: 5.9,
          targetHours: 6,
          notifiedDate: null,
          today: today,
        ),
        isFalse,
      );
    });

    test('does not notify twice on the same day', () {
      expect(
        GuardianReminderService.shouldNotify(
          guardianEmail: 'guardian@example.com',
          screenHours: 9,
          targetHours: 6,
          notifiedDate: today,
          today: today,
        ),
        isFalse,
      );
    });

    test('does not notify when the target is not set', () {
      expect(
        GuardianReminderService.shouldNotify(
          guardianEmail: 'guardian@example.com',
          screenHours: 9,
          targetHours: 0,
          notifiedDate: null,
          today: today,
        ),
        isFalse,
      );
    });

    test('notifies when the target is exceeded and not yet sent today', () {
      expect(
        GuardianReminderService.shouldNotify(
          guardianEmail: 'guardian@example.com',
          screenHours: 7.5,
          targetHours: 6,
          notifiedDate: '2026-10-23',
          today: today,
        ),
        isTrue,
      );
    });
  });

  group('GuardianReminderService.isValidEndpoint', () {
    test('accepts https endpoints only', () {
      expect(
        GuardianReminderService.isValidEndpoint('https://example.com/notify'),
        isTrue,
      );
      expect(
        GuardianReminderService.isValidEndpoint('http://example.com/notify'),
        isFalse,
      );
      expect(GuardianReminderService.isValidEndpoint(''), isFalse);
      expect(GuardianReminderService.isValidEndpoint('https://'), isFalse);
    });
  });
}
