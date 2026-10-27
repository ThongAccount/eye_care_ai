import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eye_care_ai/utils/platform_capability.dart';

/// Test cho chỗ lös "nền tảng có tính năng native Android hay không".
///
/// `hasAndroidNativeFeatures()` dùng `defaultTargetPlatform` (không phải
/// `Platform.isAndroid`), nên test có thể ép nền tảng bằng
/// `debugDefaultTargetPlatformOverride` — kiểm thử hành vi "trên iOS" trong CI
/// mà không cần máy Mac.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('hasAndroidNativeFeatures', () {
    test('returns true with explicit TargetPlatform.android', () {
      expect(hasAndroidNativeFeatures(TargetPlatform.android), isTrue);
    });

    test('returns false with explicit TargetPlatform.iOS', () {
      expect(hasAndroidNativeFeatures(TargetPlatform.iOS), isFalse);
    });

    test('returns true on Android via debugDefaultTargetPlatformOverride', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(hasAndroidNativeFeatures(), isTrue);
    });

    test('returns false on iOS via debugDefaultTargetPlatformOverride', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(hasAndroidNativeFeatures(), isFalse);
    });

    test('explicit param overrides the default platform override', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(hasAndroidNativeFeatures(TargetPlatform.android), isTrue);
      expect(hasAndroidNativeFeatures(TargetPlatform.iOS), isFalse);
    });
  });
}
