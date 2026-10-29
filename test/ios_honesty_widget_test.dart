import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/models/app_strings.dart';
import 'package:eye_care_ai/providers/language_provider.dart';
import 'package:eye_care_ai/providers/setup_provider.dart';
import 'package:eye_care_ai/providers/usage_limit_provider.dart';
import 'package:eye_care_ai/screens/app_lock_overlay.dart';
import 'package:eye_care_ai/screens/setup_wizard_screen.dart';
import 'package:eye_care_ai/widgets/settings_toggle_tile.dart';
import 'package:eye_care_ai/utils/platform_capability.dart';

/// Widget test cho hành vi iOS của "honesty pass" — màn hình không hiển thị
/// cái điều khiển không hoạt được.
///
/// `debugDefaultTargetPlatformOverride` ép nền tảng về iOS, không cần máy Mac.
///
/// LƯU Ý: `debugDefaultTargetPlatformOverride` phải đặt về null TRONG thân
/// test (không chỉ trong tearDown), vì Flutter kiểm tra các biến foundation
/// đã được unset sau khi thân test kết thúc nhưng TRƯỚC tearDown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Setup wizard — iOS shows only applicable steps', () {
    testWidgets('first permission page is Notifications, Usage Access absent',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});

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

      await tester.tap(find.text(strings.setupGetStarted));
      await tester.pumpAndSettle();

      // iOS: trang đầu tiên là Notifications (thông báo), không có Usage Access.
      expect(find.text(strings.setupStepNotificationsTitle), findsOneWidget);
      expect(find.text(strings.setupStepUsageTitle), findsNothing);

      debugDefaultTargetPlatformOverride = null;

      // SetupProvider.refreshStatus() có timeout 6s → cho đồng hồ giả chạy qua.
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('wizard page count on iOS is Welcome + 2 steps + Done',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});

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
      await tester.tap(find.text(strings.setupGetStarted));
      await tester.pumpAndSettle();

      // 4 trang: Welcome, Notifications, Location, Done
      expect(find.byType(PageView), findsOneWidget);
      // Progress dots: 4 dots total
      final dots = find.byType(AnimatedContainer);
      expect(dots, findsNWidgets(4));

      debugDefaultTargetPlatformOverride = null;

      await tester.pump(const Duration(seconds: 7));
    });
  });

  group('SettingsToggleTile — focus mode disabled on iOS', () {
    testWidgets('onChanged is null and description says not available on iOS',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final strings = AppStrings(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsToggleTile(
              title: strings.focusModeTitle,
              description: strings.notAvailableOnIOS,
              value: false,
              onChanged: null,
            ),
          ),
        ),
      );

      expect(find.text(strings.notAvailableOnIOS), findsOneWidget);
      final tile = tester.firstWidget(find.byType(SwitchListTile)) as SwitchListTile;
      expect(tile.onChanged, isNull);
      expect(tile.value, isFalse);

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('AppLockSettingsSheetHost — unavailable on iOS', () {
    testWidgets('shows unavailable text, no switches or presets on iOS',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      SharedPreferences.setMockInitialValues({});

      final language = LanguageProvider();
      final limit = UsageLimitProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageProvider>.value(value: language),
            ChangeNotifierProvider<UsageLimitProvider>.value(value: limit),
          ],
          child: const MaterialApp(home: AppLockSettingsSheetHost()),
        ),
      );
      await tester.pump();

      final strings = language.strings;

      // Hiện rõ trạng thái "không có trên iOS".
      expect(find.text(strings.appLockUnavailableOnIOS), findsOneWidget);
      // Không có công tắc bật/tắt giới hạn.
      expect(find.byType(SwitchListTile), findsNothing);
      // Không có preset thời gian.
      expect(find.byType(RadioListTile<int>), findsNothing);
      // Không có nút thử overlay.
      expect(find.text(strings.appLockTestTitle), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
