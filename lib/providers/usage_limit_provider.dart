import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_usage_limit.dart';
import '../services/app_usage_monitor.dart';

/// Lưu giới hạn sử dụng (app-lock Phase 1) xuống SharedPreferences và cung
/// cấp ChangeNotifier cho Settings + overlay.
///
/// Trạng thái KHOÁ (`isLocked`) được tính ở đây — không phải ở UI — vì nó
/// là điều kiện thật của app-lock: đang bật giới hạn + đã dùng hết hạn mức +
/// chưa dùng phần "+5 phút" đang còn hiệu lực. Khi trạng thái này đổi,
/// provider thông báo cho AppLockGate (xem lib/screens/app_lock_overlay.dart)
/// để vẽ/gỡ màn hình khoá đè lên toàn bộ app.
class UsageLimitProvider extends ChangeNotifier {
  static const _kPrefKey = 'app_usage_limit';

  AppUsageLimit _limit = const AppUsageLimit.disabled();
  AppUsageLimit get limit => _limit;

  /// Số phút đã dùng hôm nay theo DeviceDataService (do monitor đẩy vào).
  int _consumedMinutes = 0;
  int get consumedMinutes => _consumedMinutes;

  /// Đang khoá hay không (đã tính cả lần "+5 phút" và reset ngày).
  bool _locked = false;
  bool get isLocked => _locked;

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
    _refreshLockState();
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _limit = _limit.copyWith(enabled: enabled);
    await _persist();
    if (!enabled) {
      // Tắt limit → tháo gate native ngay.
      await AppUsageMonitor.instance.disarm();
    }
  }

  Future<void> setDailyLimitMinutes(int minutes) async {
    _limit = _limit.copyWith(dailyLimitMinutes: minutes);
    await _persist();
    if (_limit.enabled) {
      // Đổi giới hạn (thường là tăng) → tháo gate để không kẹt.
      await AppUsageMonitor.instance.disarm();
    }
  }

  /// Bấm "+5 phút": mở khoá trong 5 phút. Hết 5 phút mà vẫn vượt hạn mức thì
  /// tự khoá lại — việc đó do _refreshLockState() chạy ở mỗi lần monitor cập
  /// nhật số phút đã dùng (mỗi ~60s).
  Future<void> grantExtraTime(DateTime now) async {
    _limit = _limit.grantExtraTime(now);
    await _persist();
    await AppUsageMonitor.instance.disarm();
  }

  /// Cập nhật số phút đã dùng hôm nay (monitor đẩy vào mỗi ~60s) và tính
  /// lại trạng thái khoá.
  void updateConsumedMinutes(int minutes) {
    final consumedChanged = minutes != _consumedMinutes;
    _consumedMinutes = minutes;
    // Qua nửa đêm → bỏ lần "+5 phút" của hôm qua và ghi lại ngày reset.
    unawaited(_applyDailyResetIfNeeded());
    final wasLocked = _locked;
    _refreshLockState();
    if (consumedChanged || _locked != wasLocked) notifyListeners();
  }

  /// 0 nếu còn thời gian; 0 luôn khi tắt.
  int remainingMinutes() {
    if (!_limit.enabled) return 0;
    final remaining = _limit.dailyLimitMinutes - _consumedMinutes;
    return remaining < 0 ? 0 : remaining;
  }

  /// Sang ngày mới → lần "+5 phút" của hôm qua không còn hiệu lực (và ngày
  /// reset được ghi lại để không reset lặp lại).
  Future<void> _applyDailyResetIfNeeded() async {
    final reset = _limit.resetIfNewDay(DateTime.now());
    if (reset.lastResetDate == _limit.lastResetDate) return;
    _limit = reset;
    await _persist();
  }

  /// Tính lại trạng thái khoá — KHÔNG tự notify (caller quyết định).
  void _refreshLockState() {
    _locked = _limit.enabled &&
        remainingMinutes() <= 0 &&
        !_limit.hasExtraTimeAt(DateTime.now());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      await prefs.setString(_kPrefKey, jsonEncode(_limit.toJson()));
    } catch (_) {
      // Bỏ qua lỗi persist — cấu hình chỉ mất khi app chết đúng lúc.
    }
    _refreshLockState();
    notifyListeners();
  }
}
