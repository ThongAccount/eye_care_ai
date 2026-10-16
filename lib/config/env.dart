import 'local_env.dart';

class Env {
  // ƯU TIÊN --dart-define=NIM_API_KEY=... (dùng cho build CI/release qua
  // GitHub Actions, xem .github/workflows/build-apk.yml). Nếu KHÔNG được
  // truyền (ví dụ bấm "Run"/"Debug" bình thường trong IDE, không gõ cờ
  // --dart-define), fallback sang `localNimApiKey` khai báo trong
  // local_env.dart (file cục bộ, không commit key thật lên git) — nhờ vậy
  // chạy debug bình thường vẫn gọi được AI, không cần tải bản APK chính
  // thức chỉ để có key.
  static const String _dartDefineNimApiKey = String.fromEnvironment(
    'NIM_API_KEY',
    defaultValue: '',
  );

  static String get nimApiKey =>
      _dartDefineNimApiKey.isNotEmpty ? _dartDefineNimApiKey : localNimApiKey;

  static const commitHash = String.fromEnvironment(
    'COMMIT_HASH',
    defaultValue: '',
  );
}