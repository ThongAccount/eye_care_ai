import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/models/app_usage_limit.dart';
import 'package:eye_care_ai/providers/usage_limit_provider.dart';

/// JSON của AppUsageLimit — dùng để dựng trạng thái đã lưu trong prefs.
String _limitJson({
  required bool enabled,
  required int dailyLimitMinutes,
  required int lastResetDate,
  int? lastExtraTimeGrantMillis,
}) {
  return jsonEncode({
    'enabled': enabled,
    'dailyLimitMinutes': dailyLimitMinutes,
    'lastResetDate': lastResetDate,
    if (lastExtraTimeGrantMillis != null)
      'lastExtraTimeGrant': lastExtraTimeGrantMillis,
  });
}

/// Đợi provider nạp xong cấu hình trong SharedPreferences (nhiều microtask).
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UsageLimitProvider lock state', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('is not locked while the limit is disabled', () async {
      final provider = UsageLimitProvider();
      await _settle();

      provider.updateConsumedMinutes(600);
      expect(provider.isLocked, isFalse);
    });

    test('locks only when the daily limit is exhausted', () async {
      final provider = UsageLimitProvider();
      await _settle();

      await provider.setEnabled(true);
      await provider.setDailyLimitMinutes(60);

      provider.updateConsumedMinutes(59);
      expect(provider.isLocked, isFalse);

      provider.updateConsumedMinutes(60);
      expect(provider.isLocked, isTrue);
    });

    test('"+5 minutes" unlocks the app', () async {
      final provider = UsageLimitProvider();
      await _settle();

      await provider.setEnabled(true);
      await provider.setDailyLimitMinutes(60);
      provider.updateConsumedMinutes(60);
      expect(provider.isLocked, isTrue);

      await provider.grantExtraTime(DateTime.now());
      expect(provider.isLocked, isFalse);
    });

    test('locks again when the extra 5 minutes have expired', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'app_usage_limit': _limitJson(
          enabled: true,
          dailyLimitMinutes: 60,
          lastResetDate: AppUsageLimit.dateCode(now),
          lastExtraTimeGrantMillis:
              now.subtract(const Duration(minutes: 6)).millisecondsSinceEpoch,
        ),
      });

      final provider = UsageLimitProvider();
      await _settle();

      provider.updateConsumedMinutes(60);
      expect(provider.isLocked, isTrue);
    });

    test('daily reset clears yesterday extra-time grant and re-arms the gate',
        () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'app_usage_limit': _limitJson(
          enabled: true,
          dailyLimitMinutes: 60,
          lastResetDate:
              AppUsageLimit.dateCode(now.subtract(const Duration(days: 1))),
          lastExtraTimeGrantMillis:
              now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
        ),
      });

      final provider = UsageLimitProvider();
      await _settle();

      // Ngày mới: lần "+5 phút" của hôm qua bị bỏ.
      expect(provider.limit.lastExtraTimeGrant, isNull);

      // Hôm nay mới dùng 10 phút -> chưa khoá.
      provider.updateConsumedMinutes(10);
      expect(provider.isLocked, isFalse);

      // Dùng hết hạn mức của ngày mới -> khoá lại (gate re-arm).
      provider.updateConsumedMinutes(60);
      expect(provider.isLocked, isTrue);
    });

    test('disabling the limit unlocks the app', () async {
      final provider = UsageLimitProvider();
      await _settle();

      await provider.setEnabled(true);
      await provider.setDailyLimitMinutes(60);
      provider.updateConsumedMinutes(60);
      expect(provider.isLocked, isTrue);

      await provider.setEnabled(false);
      expect(provider.isLocked, isFalse);
    });
  });
}
