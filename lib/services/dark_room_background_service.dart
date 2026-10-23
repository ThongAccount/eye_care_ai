// ============================================================================
// LỊCH SỬ + VAI TRÒ HIỆN TẠI CỦA FILE NÀY
//
// 1) "Cảnh báo dùng điện thoại trong bóng tối" chạy nền đã được chuyển sang
//    NATIVE KOTLIN (DarkRoomWorker.kt) vì isolate nền của `workmanager` không
//    có các MethodChannel tự đăng ký trong MainActivity.configureFlutterEngine()
//    (gây MissingPluginException). File này vẫn HUỶ task `workmanager` cũ của
//    tính năng đó còn sót lại từ các bản cài trước, tránh báo trùng 2 lần.
//
// 2) MỚI: "Thời gian ngoài trời" chạy nền. Khác với bóng tối, tính năng này
//    chỉ dùng các PLUGIN chuẩn (geolocator, shared_preferences) — plugin chuẩn
//    được đăng ký tự động cho isolate nền của workmanager (không phụ thuộc
//    MainActivity), nên viết thẳng bằng Dart được, không cần Kotlin riêng.
//    Mỗi ~15 phút (mức tối thiểu Android cho phép với tác vụ định kỳ) Worker
//    lấy 1 điểm GPS và cộng thời gian ngoài trời, KỂ CẢ khi app đã đóng —
//    người dùng không phải mở app. Cần quyền vị trí "Luôn cho phép"
//    (ACCESS_BACKGROUND_LOCATION), xin ở bước "Vị trí" của Setup Wizard.
//
// Gọi register() 1 lần lúc khởi động app (xem main.dart). An toàn gọi lại.
// ============================================================================
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'device_data_service.dart';

const String _darkRoomUniqueTaskName = 'dark_room_periodic';
const String _outdoorUniqueTaskName = 'outdoor_time_periodic';
const String _outdoorTaskName = 'outdoor_time_sample';

// PHẢI là hàm top-level + @pragma('vm:entry-point') để còn gọi được khi app
// đã bị hệ điều hành tắt hẳn (chạy trong isolate nền riêng).
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Isolate nền: cần khởi tạo binding + đăng ký plugin trước khi dùng
      // geolocator/shared_preferences.
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      if (task == _outdoorTaskName) {
        await DeviceDataService.instance.sampleOutdoorOnce(fromBackground: true);
      }
    } catch (_) {
      // Lỗi 1 lần lấy mẫu (GPS timeout, thiếu quyền...) không được làm hỏng
      // lịch chạy định kỳ — trả true để WorkManager vẫn chạy lần sau.
    }
    return true;
  });
}

/// Gọi 1 lần lúc khởi động app (xem main.dart).
Future<void> registerDarkRoomBackgroundService() async {
  try {
    await Workmanager().initialize(backgroundCallbackDispatcher);
    // Dọn task cũ của cảnh báo bóng tối (đã chuyển sang Kotlin).
    await Workmanager().cancelByUniqueName(_darkRoomUniqueTaskName);
    // Đăng ký lấy mẫu ngoài trời định kỳ (đăng ký lại cùng tên là idempotent).
    await Workmanager().registerPeriodicTask(
      _outdoorUniqueTaskName,
      _outdoorTaskName,
      frequency: const Duration(minutes: 15),
    );
  } catch (_) {
    // Thiết bị/ROM không hỗ trợ -> bỏ qua, app vẫn chạy bình thường (chỉ mất
    // phần đo ngoài trời lúc app đóng; lúc app mở vẫn có Timer foreground).
  }
}

/// Giữ lại tên cũ `DarkRoomBackgroundService.register()` cho tương thích
/// ngược với lời gọi hiện có trong main.dart.
class DarkRoomBackgroundService {
  DarkRoomBackgroundService._();

  static Future<void> register() => registerDarkRoomBackgroundService();
}