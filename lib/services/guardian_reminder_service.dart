import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Nhắc nhở NGƯỜI BẢO HỘ khi người dùng vượt quá mục tiêu thời gian dùng
/// điện thoại.
///
/// Vì sao tách riêng 1 service:
///  - Phần "kiểm tra nền" chạy HOÀN TOÀN NATIVE (WorkManager — xem
///    GuardianReminderWorker.kt) vì Dart isolate nền không có MethodChannel
///    riêng của app (xem dark_room_background_service.dart), và cũng không
///    đọc được UsageStatsManager chính xác như bản native.
///  - Phần "gửi" có 2 đường:
///    1. Endpoint HTTPS do người vận hành cấu hình lúc build:
///         flutter build apk --dart-define=GUARDIAN_EMAIL_ENDPOINT=https://...
///       Worker nền POST thẳng tới endpoint này (không cần app mở).
///    2. Nếu CHƯA cấu hình endpoint -> đường lùi `mailto:` (mở app mail của
///       máy), đúng như hành vi cũ của nút "Gửi mail nhắc thử".
///
/// TUYỆT ĐỐI không hardcode API key/secret trong repo: endpoint (và mọi tham
/// số nhạy cảm khác) do người vận hành cung cấp lúc build, và endpoint chỉ
/// được chấp nhận nếu là HTTPS (email người bảo hộ là dữ liệu cá nhân).
class GuardianReminderService {
  GuardianReminderService._();

  static final GuardianReminderService instance = GuardianReminderService._();

  /// Endpoint HTTPS nhận POST để gửi mail cho người bảo hộ — cấu hình lúc
  /// build bằng `--dart-define=GUARDIAN_EMAIL_ENDPOINT=...`.
  /// RỖNG (mặc định) => không gửi gì tự động từ nền, dùng đường lùi mailto.
  static const String endpoint = String.fromEnvironment(
    'GUARDIAN_EMAIL_ENDPOINT',
  );

  // Khoá SharedPreferences — tiền tố "flutter." do plugin shared_preferences
  // tự thêm, nên worker Kotlin đọc được cùng 1 file.
  static const String endpointPrefKey = 'pref_guardian_endpoint';
  static const String guardianEmailPrefKey = 'pref_guardian_email';
  static const String notifiedDatePrefKey = 'pref_guardian_notified_date';
  static const String pendingDatePrefKey = 'pref_guardian_pending_date';
  static const String phoneTargetPrefKey = 'pref_habit_target_phone';

  /// Mục tiêu mặc định (giờ) — giống hệt HabitProvider và DailySnapshotWorker.
  static const double defaultPhoneTargetHours = 6.0;

  /// Endpoint có dùng được không (phải là HTTPS và không rỗng).
  bool get hasEndpoint => isValidEndpoint(endpoint);

  /// Chỉ chấp nhận endpoint HTTPS — email người bảo hộ là dữ liệu cá nhân,
  /// không được gửi qua kết nối không mã hoá.
  static bool isValidEndpoint(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('https://') &&
        trimmed.length > 'https://'.length;
  }

  /// Chép endpoint (biến compile-time) vào SharedPreferences để worker NATIVE
  /// đọc được — dart-define chỉ tồn tại trong binary Dart, code Kotlin không
  /// thấy. Ghi đè mỗi lần app khởi động để đổi endpoint không cần cài lại.
  Future<void> syncEndpointToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(endpointPrefKey, endpoint.trim());
  }

  /// Điều kiện gửi nhắc: đã có email người bảo hộ, thời gian màn hình hôm
  /// nay VƯỢT mục tiêu, và hôm nay chưa gửi rồi.
  ///
  /// Hàm thuần (pure) để test được dễ — logic này được mirror sang Kotlin
  /// (GuardianReminderWorker.kt) vì worker chạy ngoài Dart.
  static bool shouldNotify({
    required String guardianEmail,
    required double screenHours,
    required double targetHours,
    required String? notifiedDate,
    required String today,
  }) {
    if (guardianEmail.trim().isEmpty) return false;
    if (targetHours <= 0) return false;
    if (screenHours <= targetHours) return false;
    if (notifiedDate == today) return false;
    return true;
  }

  /// Ngày (yyyy-MM-dd) theo múi giờ máy.
  static String today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// POST nhắc nhở tới endpoint HTTPS. Trả về true nếu endpoint trả 2xx.
  /// Không đánh dấu "đã gửi hôm nay" — việc đó do worker NATIVE làm, để
  /// nút gửi thử trong Settings không khoá luôn nhắc nền của ngày hôm đó.
  Future<bool> postReminder({
    required String guardianEmail,
    double? screenHours,
    double? targetHours,
    String? date,
  }) async {
    if (!hasEndpoint) return false;
    final email = guardianEmail.trim();
    if (email.isEmpty) return false;

    final payload = <String, dynamic>{
      'to': email,
      'date': date ?? today(),
      'source': 'eyecare-ai-android',
    };
    if (screenHours != null) payload['screenHours'] = screenHours;
    if (targetHours != null) payload['targetHours'] = targetHours;

    try {
      final response = await Dio().post(
        endpoint.trim(),
        data: payload,
        options: Options(
          headers: const {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final status = response.statusCode ?? 0;
      return status >= 200 && status < 300;
    } catch (_) {
      // Mất mạng / endpoint lỗi -> trả về false, người dùng vẫn có đường lùi
      // mailto: (đừng ném lỗi ra UI).
      return false;
    }
  }

  /// Đường lùi khi chưa (hoặc không) gửi được qua endpoint: mở app mail của
  /// máy với nội dung nhắc nhở sẵn — giữ nguyên hành vi cũ của nút "Gửi mail
  /// nhắc thử" trong Settings.
  Future<bool> openMailtoFallback({
    required String guardianEmail,
    required String subject,
    required String body,
  }) async {
    final email = guardianEmail.trim();
    if (email.isEmpty) return false;
    final uri = Uri.parse(
      'mailto:$email?cc=eyecareai.app@gmail.com'
      '&subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) await clearPendingReminder();
      return launched;
    } catch (_) {
      return false;
    }
  }

  /// Gửi nhắc: có endpoint -> POST thật (nếu POST lỗi thì vẫn mở app mail để
  /// không bị "chết âm thầm"); không có endpoint -> mở app mail.
  Future<bool> sendReminderOrFallback({
    required String guardianEmail,
    required String subject,
    required String body,
  }) async {
    if (hasEndpoint) {
      final sent = await postReminder(guardianEmail: guardianEmail);
      if (sent) return true;
    }
    return openMailtoFallback(
      guardianEmail: guardianEmail,
      subject: subject,
      body: body,
    );
  }

  /// Ngày mà worker nền phát hiện vượt giờ nhưng KHÔNG gửi được (vì chưa cấu
  /// hình endpoint) — app hiện trạng thái này cho người dùng.
  Future<String?> pendingReminderDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(pendingDatePrefKey);
  }

  Future<void> clearPendingReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingDatePrefKey);
  }
}
