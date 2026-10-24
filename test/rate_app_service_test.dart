import 'package:flutter_test/flutter_test.dart';
import 'package:eye_care_ai/services/rate_app_service.dart';

void main() {
  group('RateAppService buildStoreUri', () {
    test('builds the Play Store deep link when the listing is published', () {
      final uri = RateAppService.buildStoreUri(
        platform: 'android',
        playPublished: true,
        appStorePublished: false,
        appStoreId: '',
      );

      expect(uri?.toString(), 'market://details?id=com.eyecare.eye_care_ai');
    });

    test('returns null for Android when the Play listing is not published', () {
      final uri = RateAppService.buildStoreUri(
        platform: 'android',
        playPublished: false,
        appStorePublished: false,
        appStoreId: '',
      );

      expect(uri, isNull);
    });

    test('builds the App Store review url when the listing is published', () {
      final uri = RateAppService.buildStoreUri(
        platform: 'iOS',
        playPublished: false,
        appStorePublished: true,
        appStoreId: '123',
      );

      expect(uri?.toString(),
          'https://apps.apple.com/app/id123?action=write-review');
    });

    test('returns null for iOS when the App Store id is empty', () {
      final uri = RateAppService.buildStoreUri(
        platform: 'iOS',
        playPublished: false,
        appStorePublished: true,
        appStoreId: '',
      );

      expect(uri, isNull);
    });

    test('returns null for platforms without a store listing', () {
      final uri = RateAppService.buildStoreUri(
        platform: 'macOS',
        playPublished: true,
        appStorePublished: true,
        appStoreId: '123',
      );

      expect(uri, isNull);
    });
  });
}
