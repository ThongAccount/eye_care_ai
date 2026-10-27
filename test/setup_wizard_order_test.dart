import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/providers/language_provider.dart';
import 'package:eye_care_ai/providers/setup_provider.dart';
import 'package:eye_care_ai/screens/setup_wizard_screen.dart';

/// Thứ tự onboarding theo "value first" (docs/growth/retention-plan.md,
/// Move 3): quyền thông báo (popup runtime, một chạm) đến TRƯỚC, Usage
/// Access (chuyển hướng Cài đặt hệ thống) để CUỐI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Setup wizard order', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('the first permission asked is notifications, not usage access', () {
      expect(kSetupWizardStepOrder.first, SetupStepId.notifications);
      expect(
        kSetupWizardStepOrder.indexOf(SetupStepId.notifications),
        lessThan(kSetupWizardStepOrder.indexOf(SetupStepId.usageAccess)),
      );
    });

    test('the reordering loses no step', () {
      expect(kSetupWizardStepOrder.length, SetupStepId.values.length);
      expect(kSetupWizardStepOrder.toSet(), SetupStepId.values.toSet());
    });

    testWidgets('the first permission page shown is Notifications',
        (tester) async {
      // Màn hình dài hơn mặc định của test để trang bước quyền không bị
      // RenderFlex overflow.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final language = LanguageProvider();
      final setup = SetupProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageProvider>.value(value: language),
            ChangeNotifierProvider<SetupProvider>.value(value: setup),
          ],
          child: const MaterialApp(home: SetupWizardScreen()),
        ),
      );
      await tester.pump();

      final strings = language.strings;

      // Rời trang Welcome -> trang quyền đầu tiên.
      await tester.tap(find.text(strings.setupGetStarted));
      await tester.pumpAndSettle();

      expect(find.text(strings.setupStepNotificationsTitle), findsOneWidget);
      expect(find.text(strings.setupStepUsageTitle), findsNothing);

      // SetupProvider.refreshStatus() có timeout 6s; trong test các lệnh hỏi
      // quyền không bao giờ trả lời nên timer đó còn treo -> cho đồng hồ giả
      // chạy qua mốc timeout trước khi kết thúc test.
      await tester.pump(const Duration(seconds: 7));
    });
  });
}
