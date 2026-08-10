import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_usage_limit.dart';

/// Lưu giới hạn sử dụng (app-lock Phase 1) xuống SharedPreferences và cung
/// cấp ChangeNotifier cho Settings + overlay.
class UsageLimitProvider extends ChangeNotifier {
  static const _kPrefKey = 'app_usage_limit';

  AppUsageLimit _limit = const AppUsageLimit.disabled();
  AppUsageLimit get limit => _limit;

  /// Số phút đã dùng hôm nay theo DeviceDataService (do monitor đẩy vào).
  int _consumedMinutes = 0;
  int get consumedMinutes => _consumedMinutes;

  UsageLimitProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      final raw = prefs.getString(_kPrefKey);
      if (raw != null) {
        _limit = AppUsageLimit.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      }
      _limit = _limit.resetIfNewDay(DateTime.now());
    } catch (_) {
      _limit = const AppUsageLimit.disabled();
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _limit = _limit.copyWith(enabled: enabled);
    await _persist();
  }

  Future<void> setDailyLimitMinutes(int minutes) async {
    _limit = _limit.copyWith(dailyLimitMinutes: minutes);
    await _persist();
  }

  Future<void> grantExtraTime(DateTime now) async {
    _limit = _limit.grantExtraTime(now);
    await _persist();
    notifyListeners();
  }

  void updateConsumedMinutes(int minutes) {
    if (_consumedMinutes == minutes) return;
    _consumedMinutes = minutes;
    notifyListeners();
  }

  /// 0 nếu còn thời gian; 0 luôn khi tắt.
  int remainingMinutes() {
    if (!_limit.enabled) return 0;
    final remaining = _limit.dailyLimitMinutes - _consumedMinutes;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isLocked => _limit.enabled && remainingMinutes() <= 0;

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      await prefs.setString(_kPrefKey, jsonEncode(_limit.toJson()));
    } catch (_) {
      // Bỏ qua lỗi persist — cấu hình chỉ mất khi app chết đúng lúc.
    }
    notifyListeners();
  }
}