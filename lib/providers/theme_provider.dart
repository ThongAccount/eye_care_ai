import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/solar_service.dart';

enum AppThemePreference { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  static const _kThemePrefKey = 'pref_theme_mode'; // 'light' | 'dark' | 'system'
  static const _kAutoNightKey = 'pref_auto_night_mode';
  static const _kNightLatKey = 'pref_night_lat';
  static const _kNightLonKey = 'pref_night_lon';

  ThemeProvider() {
    _loadSavedPreferences();
  }

  AppThemePreference _preference = AppThemePreference.system;
  // Độ sáng thật của MÀN HÌNH hiện tại (light/dark) — dùng khi preference = system.
  final Brightness _platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  AppThemePreference get preference => _preference;

  // "Chế độ đọc ban đêm" (Notion: Tính năng sắp tới): khi bật, app tự chuyển
  // giao diện tối theo giờ hoàng hôn / bình minh tính từ vị trí GPS đã có.
  // Đây là opt-in (mặc định tắt) nên việc override lựa chọn Sáng/Tối lúc ban
  // đêm là hành vi đã được người dùng đồng ý khi bật công tắc.
  bool _autoNightMode = false;
  // null = chưa tính được lần nào (ví dụ vừa cài app, chưa có vị trí).
  bool? _isNightNow;
  // Nhãn "HH:mm – HH:mm" (hoàng hôn – bình minh) để hiện trạng thái ở
  // Settings; null khi đang dùng fallback 18:00–06:00 hoặc chưa tính.
  String? _tonightLabel;

  bool get autoNightMode => _autoNightMode;
  bool? get isNightNow => _isNightNow;
  String? get tonightLabel => _tonightLabel;

  bool get _nightOverride => _autoNightMode && _isNightNow == true;

  bool get isDarkMode {
    if (_nightOverride) return true;
    return switch (_preference) {
      AppThemePreference.dark => true,
      AppThemePreference.light => false,
      AppThemePreference.system => _platformBrightness == Brightness.dark,
    };
  }

  ThemeMode get themeMode {
    if (_nightOverride) return ThemeMode.dark;
    return switch (_preference) {
      AppThemePreference.dark => ThemeMode.dark,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.system => ThemeMode.system,
    };
  }

  Future<void> reload() => _loadSavedPreferences();

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _autoNightMode = prefs.getBool(_kAutoNightKey) ?? false;
    final saved = prefs.getString(_kThemePrefKey);
    if (saved == null) {
      // Chưa từng chọn -> mặc định lấy đúng theo cài đặt sáng/tối của máy.
      _preference = AppThemePreference.system;
    } else {
      _preference = AppThemePreference.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppThemePreference.system,
      );
    }
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference value) async {
    _preference = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePrefKey, value.name);
    notifyListeners();
  }

  Future<void> setAutoNightMode(bool value) async {
    _autoNightMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoNightKey, value);
    if (value) {
      // Bật là tính ngay để giao diện phản ứng lập tức, không chờ lần mở app sau.
      await refreshNightState();
    }
    notifyListeners();
  }

  // Tính lại trạng thái ngày/đêm. Cố ý KHÔNG xin quyền vị trí ở đây (không
  // hiện popup ngoài ngữ cảnh): chỉ dùng khi quyền đã được cấp từ trước (ví
  // dụ người dùng đã bật Outdoor tracking). Không có vị trí -> dùng tọa độ
  // đã lưu lần trước -> vẫn không có -> fallback 18:00–06:00 giờ địa phương.
  // Dùng độ chính xác thấp (fused, nhanh, ít tốn pin): tính hoàng hôn chỉ cần
  // chính xác tới cấp thành phố.
  Future<void> refreshNightState() async {
    try {
      final now = DateTime.now();
      double? lat;
      double? lon;
      final prefs = await SharedPreferences.getInstance();

      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (granted && await Geolocator.isLocationServiceEnabled()) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          ).timeout(const Duration(seconds: 12));
          lat = position.latitude;
          lon = position.longitude;
          await prefs.setDouble(_kNightLatKey, lat);
          await prefs.setDouble(_kNightLonKey, lon);
        } catch (_) {
          // GPS lỗi/timeout -> rơi xuống dùng tọa độ đã lưu / fallback.
        }
      }
      lat ??= prefs.getDouble(_kNightLatKey);
      lon ??= prefs.getDouble(_kNightLonKey);

      if (lat != null && lon != null) {
        final times = SolarService.sunTimes(lat: lat, lon: lon, date: now);
        if (times != null) {
          _isNightNow = now.isAfter(times.sunset) || now.isBefore(times.sunrise);
          _tonightLabel = '${_fmtTime(times.sunset)} – ${_fmtTime(times.sunrise)}';
        }
        // Vùng cực (times == null): giữ nguyên trạng thái cũ, không đoán mò.
      } else {
        _isNightNow = SolarService.isNightFallback(now);
        _tonightLabel = null;
      }
    } catch (_) {
      // Lỗi bất ngờ -> giữ nguyên trạng thái cũ, không crash app.
    }
    notifyListeners();
  }

  static String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Giữ tương thích ngược cho chỗ nào còn gọi toggleDarkMode(bool).
  Future<void> toggleDarkMode(bool value) =>
      setPreference(value ? AppThemePreference.dark : AppThemePreference.light);
}
