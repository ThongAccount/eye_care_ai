// ============================================================================
// LỊCH SỬ / TẠI SAO FILE NÀY GIỜ GẦN NHƯ RỖNG:
//
// Tính năng "cảnh báo dùng điện thoại trong bóng tối chạy nền" TRƯỚC ĐÂY
// được implement hoàn toàn ở đây bằng package `workmanager` (Flutter) gọi
// vào 1 Dart callback chạy trong isolate nền riêng.
//
// BUG PHÁT HIỆN: Dart isolate nền đó gọi MethodChannel
// "eye_care_ai/usage_events" (hàm "isScreenOn") để tránh cảnh báo nhầm khi
// màn hình đang tắt — nhưng kênh đó CHỈ được đăng ký trong
// MainActivity.configureFlutterEngine(), tức CHỈ tồn tại trên FlutterEngine
// gắn với Activity đang mở. FlutterEngine "headless" mà `workmanager` tự
// tạo để chạy nền hoàn toàn TÁCH BIỆT, không bao giờ đi qua
// configureFlutterEngine() đó -> mọi lệnh gọi kênh từ isolate nền đều ném
// MissingPluginException, bị nuốt im lặng (mặc định trả về true), khiến
// bước kiểm tra màn hình mất tác dụng và code cứ cố đọc cảm biến ánh sáng cả
// khi máy đang khoá màn hình -> Android không gửi sự kiện cảm biến khi màn
// hình tắt -> lux=null vĩnh viễn dù task nền vẫn chạy đều (đã xác nhận qua
// debug logging).
//
// FIX: toàn bộ logic thật (đọc PowerManager, đọc cảm biến ánh sáng, gửi
// thông báo) đã chuyển sang NATIVE KOTLIN — xem
// android/app/src/main/kotlin/com/eyecare/eye_care_ai/DarkRoomWorker.kt,
// được đăng ký lặp mỗi 15 phút trực tiếp bằng androidx.work.WorkManager
// ngay trong MainActivity.onCreate() (không qua Dart/MethodChannel nào cả
// -> không còn phụ thuộc FlutterEngine, đáng tin cậy tuyệt đối kể cả khi
// app bị hệ điều hành dọn sạch khỏi bộ nhớ).
//
// File này CHỈ còn giữ 1 việc: dọn dẹp (huỷ) task `workmanager` CŨ đã đăng
// ký trên máy người dùng TỪ CÁC BẢN CÀI TRƯỚC, để tránh chạy song song 2 cơ
// chế cùng lúc (báo trùng 2 lần). Gọi register() (từ main.dart, giữ nguyên
// tên hàm để không phải sửa main.dart) sẽ thực hiện việc dọn dẹp 1 lần này.
// ============================================================================
import 'package:workmanager/workmanager.dart';

const String _darkRoomUniqueTaskName = 'dark_room_periodic';

// Dispatcher rỗng — chỉ tồn tại để thoả tham số bắt buộc của
// Workmanager().initialize(). Không còn task nào dùng callback này (worker
// thật đã chuyển hẳn sang native Kotlin, xem giải thích ở đầu file), nhưng
// initialize() yêu cầu 1 @pragma('vm:entry-point') hợp lệ để không lỗi khi
// Android thử warm-up isolate nền (dù giờ sẽ không có task nào gọi tới).
@pragma('vm:entry-point')
void _noopCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async => true);
}

/// Gọi 1 lần lúc khởi động app (xem main.dart) — huỷ task `workmanager` cũ
/// nếu còn sót lại từ bản cài trước khi có bản fix chuyển sang native
/// Kotlin. An toàn để gọi nhiều lần / gọi cả khi task không tồn tại.
Future<void> registerDarkRoomBackgroundService() async {
  try {
    await Workmanager().initialize(_noopCallbackDispatcher);
    await Workmanager().cancelByUniqueName(_darkRoomUniqueTaskName);
  } catch (_) {
    // Có thể workmanager chưa từng initialize trên máy này (cài mới hoàn
    // toàn, chưa từng chạy bản cũ) -> không có gì để huỷ, bỏ qua an toàn.
  }
}

/// Giữ lại tên cũ `DarkRoomBackgroundService.register()` cho tương thích
/// ngược với lời gọi hiện có trong main.dart.
class DarkRoomBackgroundService {
  DarkRoomBackgroundService._();

  static Future<void> register() => registerDarkRoomBackgroundService();
}