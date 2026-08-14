import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/providers/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts with default locale vi (upstream 53c355d)', () {
      final provider = LanguageProvider();
      expect(provider.locale, const Locale('vi'));
      expect(provider.isVietnamese, isTrue);
    });

    test('toggles locale to vi and persists', () async {
      final provider = LanguageProvider();
      await Future<void>.delayed(Duration.zero);

      await provider.toggleVietnamese(true);

      expect(provider.isVietnamese, isTrue);
      expect(provider.locale, const Locale('vi'));

      final fresh = LanguageProvider();
      await Future<void>.delayed(Duration.zero);
      expect(fresh.isVietnamese, isTrue);
      expect(fresh.locale, const Locale('vi'));
    });

    test('strings reflect locale', () {
      // Default locale is now vi (upstream 53c355d).
      final vi = LanguageProvider();
      expect(vi.strings.home, 'Trang chủ');

      final en = LanguageProvider()..toggleVietnamese(false);
      expect(en.strings.home, 'Home');
    });
  });
}
