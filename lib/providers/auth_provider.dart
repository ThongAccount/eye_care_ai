import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Theo dõi trạng thái đăng nhập, dùng bởi _AppGate (main.dart) và Settings.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _sub = AuthService.instance.authStateChanges.listen((user) {
      _user = user;
      // Sự kiện ĐẦU TIÊN từ authStateChanges (dù là user thật hay null) mới
      // là lúc Firebase Auth THỰC SỰ đã đọc xong phiên đăng nhập đã lưu từ
      // bộ nhớ máy (native SDK khôi phục bất đồng bộ, không đồng bộ ngay cả
      // khi Firebase.initializeApp() đã xong) — trước đó, `currentUser` đọc
      // ngay lúc khởi tạo provider (bên dưới) có thể trả về null NHẦM dù
      // người dùng vẫn đang đăng nhập, do đọc quá sớm trong lúc SDK còn đang
      // khôi phục phiên cũ. Đây chính là nguyên nhân app cứ mở lên là đòi
      // đăng nhập lại dù người dùng chưa từng đăng xuất.
      _authReady = true;
      notifyListeners();
    });
  }

  StreamSubscription<User?>? _sub;
  User? _user = AuthService.instance.currentUser;
  // false trong khoảng thời gian (thường vài chục-vài trăm mili-giây) chờ
  // Firebase Auth khôi phục xong phiên đăng nhập cũ từ bộ nhớ máy — _AppGate
  // PHẢI đợi cờ này = true rồi mới được quyết định hiện LoginScreen hay
  // không, nếu không sẽ đôi khi "chớp" sang LoginScreen oan trước khi kịp
  // nhận sự kiện khôi phục phiên thật.
  bool _authReady = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get authReady => _authReady;
  String get displayName => _user?.displayName ?? _user?.email?.split('@').first ?? '';

  Future<void> signOut() => AuthService.instance.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}