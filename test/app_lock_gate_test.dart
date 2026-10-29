import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/models/app_usage_limit.dart';
import 'package:eye_care_ai/navigation/root_navigator.dart';
import 'package:eye_care_ai/providers/language_provider.dart';
import 'package:eye_care_ai/providers/usage_limit_provider.dart';
import 'package:eye_care_ai/screens/app_lock_overlay.dart';

/// Key của phần nội dung app — dùng để so kích thước với màn hình khoá.
const ValueKey<String> _bodyKey = ValueKey<String>('app-body');

/// Pump MỘT frame kèm flush microtask (fake-async).
///
/// Cần cho các Future nội bộ (SharedPreferences, provider) hoàn tất TRƯỚC
/// khi cây widget được dựng lại — `tester.pump()` trần không đảm bảo điều đó.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1));
}

/// Dựng app GIỐNG HỆT main.dart: [AppLockGate] được gắn qua
/// `MaterialApp.builder` (nằm NGOÀI navigator nên phủ được mọi route).
///
/// [useRootNavigator] bật `rootNavigatorKey` — chỉ cần cho test mở trang
/// Cài đặt từ màn hình khoá (đường thoát duy nhất ngoài "+5 phút").
Widget _buildApp(
  UsageLimitProvider provider,
  LanguageProvider language, {
  bool useRootNavigator = false,
}) {
  return ChangeNotifierProvider<UsageLimitProvider>.value(
    value: provider,
    child: ChangeNotifierProvider<LanguageProvider>.value(
      value: language,
      child: MaterialApp(
        navigatorKey: useRootNavigator ? rootNavigatorKey : null,
        builder: (context, child) =>
            AppLockGate(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(
          body: SizedBox.expand(
            key: _bodyKey,
            child: Center(child: Text('app content')),
          ),
        ),
      ),
    ),
  );
}

/// Cấu hình "giới hạn 60 phút/ngày, ĐÃ BẬT" trong SharedPreferences — giống
/// người dùng đã bật giới hạn trong Cài đặt. Provider nạp cấu hình này lúc
/// khởi tạo.
void _seedEnabledLimit() {
  SharedPreferences.setMockInitialValues({
    'app_usage_limit': jsonEncode({
      'enabled': true,
      'dailyLimitMinutes': 60,
      'lastResetDate': AppUsageLimit.dateCode(DateTime.now()),
    }),
  });
}

/// Dựng app + chờ provider nạp xong cấu hình trong prefs.
Future<UsageLimitProvider> _pumpLockedApp(
  WidgetTester tester, {
  LanguageProvider? language,
  bool useRootNavigator = false,
}) async {
  final provider = UsageLimitProvider();
  final languageProvider = language ?? LanguageProvider();

  await tester.pumpWidget(
    _buildApp(provider, languageProvider, useRootNavigator: useRootNavigator),
  );
  await _pump(tester);
  await tester.pumpAndSettle();

  // Provider đã nạp xong cấu hình trong prefs và chưa khoá (0 phút đã dùng).
  expect(provider.limit.enabled, isTrue);
  expect(provider.isLocked, isFalse);
  expect(find.byType(AppLockOverlay), findsNothing);

  return provider;
}

/// Dùng hết hạn mức 60 phút -> app phải khoá.
Future<void> _exhaustLimit(WidgetTester tester, UsageLimitProvider provider) async {
  provider.updateConsumedMinutes(60);
  await _pump(tester);
  expect(provider.isLocked, isTrue);
  expect(find.byType(AppLockOverlay), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_seedEnabledLimit);

  testWidgets('lock overlay covers the whole app when the limit is exhausted',
      (WidgetTester tester) async {
    final provider = await _pumpLockedApp(tester);

    await _exhaustLimit(tester, provider);

    // Màn hình khoá phủ TOÀN BỘ app (bằng đúng kích thước màn hình)...
    expect(
      tester.getSize(find.byType(AppLockOverlay)),
      tester.getSize(find.byKey(_bodyKey)),
    );

    // ...và KHÔNG nằm trong navigator (nếu là một route thì Back sẽ gỡ được
    // và nó chỉ phủ các route đã push, không phủ navigator).
    expect(
      find.descendant(
        of: find.byType(Navigator).first,
        matching: find.byType(AppLockOverlay),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppLockGate),
        matching: find.byType(AppLockOverlay),
      ),
      findsOneWidget,
    );
  });

  testWidgets('"+5 minutes" dismisses the lock', (WidgetTester tester) async {
    final provider = await _pumpLockedApp(tester);
    await _exhaustLimit(tester, provider);

    unawaited(provider.grantExtraTime(DateTime.now()));
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(provider.isLocked, isFalse);
    expect(find.byType(AppLockOverlay), findsNothing);
  });

  testWidgets('the "+5 minutes" button unlocks the app',
      (WidgetTester tester) async {
    final provider = await _pumpLockedApp(tester);
    await _exhaustLimit(tester, provider);

    await tester.tap(find.byIcon(Icons.add_alarm_outlined));
    await _pump(tester);
    await tester.pumpAndSettle();

    expect(provider.isLocked, isFalse);
    expect(find.byType(AppLockOverlay), findsNothing);
  });

  testWidgets('the lock stays when another route is pushed',
      (WidgetTester tester) async {
    final provider = await _pumpLockedApp(tester);
    await _exhaustLimit(tester, provider);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('second screen'))),
        ),
      ),
    );
    await _pump(tester);
    await tester.pumpAndSettle();

    // Route mới vẫn nằm dưới lớp khoá — người dùng không dùng được app.
    expect(find.text('second screen'), findsOneWidget);
    expect(find.byType(AppLockOverlay), findsOneWidget);
  });

  testWidgets('the limit settings can be opened from the lock',
      (WidgetTester tester) async {
    final language = LanguageProvider();
    final provider =
        await _pumpLockedApp(tester, language: language, useRootNavigator: true);
    await _exhaustLimit(tester, provider);

    await tester.tap(find.text(language.strings.appLockOpenSettings));
    await _pump(tester);
    await tester.pumpAndSettle();

    // Màn hình khoá tạm ẩn để trang Cài đặt giới hạn nhìn thấy được.
    expect(find.byType(AppLockOverlay), findsNothing);
    expect(find.byType(AppLockSettingsSheetHost), findsOneWidget);

    // Dọn tree để GlobalKey rootNavigatorKey được giải phóng cho test sau.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
