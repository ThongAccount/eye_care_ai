import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  static const _kVietnameseKey = 'pref_vietnamese';

  LanguageProvider() {
    _loadSavedPreferences();
  }

  // Mặc định TIẾNG VIỆT cho lần cài đặt mới (chưa từng lưu lựa chọn trong
  // SharedPreferences) — app hướng tới người dùng Việt Nam là chính, không
  // nên mặc định tiếng Anh rồi bắt người dùng tự vào Cài đặt đổi lại.
  bool _isVietnamese = true;

  bool get isVietnamese => _isVietnamese;
  Locale get locale => _isVietnamese ? const Locale('vi') : const Locale('en');
  AppStrings get strings => AppStrings(_isVietnamese);

  Future<void> reload() => _loadSavedPreferences();

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isVietnamese = prefs.getBool(_kVietnameseKey) ?? _isVietnamese;
    notifyListeners();
  }

  Future<void> toggleVietnamese(bool value) async {
    _isVietnamese = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVietnameseKey, value);
    notifyListeners();
  }
}
