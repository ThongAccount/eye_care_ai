import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_care_ai/providers/setup_provider.dart';

/// Test cho hành vi iOS của SetupProvider — "áp dụng bước theo nền tảng".
///
/// Trên iOS chỉ còn 2 bước có thể thỏa mãn được (thông báo + vị trí), cả 6
/// bước còn lại là Android-only và KHÔNG được hỏi, KHÔNG được đếm — để banner
/// "hoàn tất thiết lập" có thể tắt trên iOS thay vì bị treo mãi mãi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('applicableSetupSteps', () {
    test('Android returns all 8 steps in the defined order', () {
      final steps = applicableSetupSteps(TargetPlatform.android);
      expect(steps.length, 8);
      expect(steps, kSetupWizardStepOrder);
      expect(steps.first, SetupStepId.notifications);
      expect(steps.last, SetupStepId.usageAccess);
    });

    test('iOS returns only notifications + location, in that order', () {
      final steps = applicableSetupSteps(TargetPlatform.iOS);
      expect(steps.length, 2);
      expect(steps, [SetupStepId.notifications, SetupStepId.location]);
    });

    test('iOS excludes every Android-only step', () {
      final steps = applicableSetupSteps(TargetPlatform.iOS);
      for (final id in kAndroidOnlySetupSteps) {
        expect(steps, isNot(contains(id)));
      }
    });

    test('iOS keeps notifications before location', () {
      final steps = applicableSetupSteps(TargetPlatform.iOS);
      expect(
        steps.indexOf(SetupStepId.notifications),
        lessThan(steps.indexOf(SetupStepId.location)),
      );
    });

    test('iOS via debugDefaultTargetPlatformOverride', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final steps = applicableSetupSteps();
      expect(steps.length, 2);
      expect(steps, [SetupStepId.notifications, SetupStepId.location]);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('allApplicableGranted / counts', () {
    test('iOS — both granted → allApplicableGranted true', () {
      expect(
        allApplicableGranted(
          {SetupStepId.notifications, SetupStepId.location},
          TargetPlatform.iOS,
        ),
        isTrue,
      );
    });

    test('iOS — missing location → allApplicableGranted false', () {
      expect(
        allApplicableGranted(
          {SetupStepId.notifications},
          TargetPlatform.iOS,
        ),
        isFalse,
      );
    });

    test('iOS — Android-only steps do not affect allApplicableGranted', () {
      expect(
        allApplicableGranted(
          {
            SetupStepId.notifications,
            SetupStepId.location,
            SetupStepId.usageAccess,
            SetupStepId.focusMode,
          },
          TargetPlatform.iOS,
        ),
        isTrue,
      );
    });

    test('iOS — grantedCount only counts applicable steps', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final provider = SetupProvider();
      // statuses start all false; grantedCount counts applicable + granted.
      expect(provider.grantedCount, 0);
      expect(provider.totalCount, 2);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android — totalCount is 8', () {
      final provider = SetupProvider();
      expect(provider.totalCount, 8);
    });
  });
}
