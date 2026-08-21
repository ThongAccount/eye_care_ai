import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:light/light.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Cảnh báo "dùng điện thoại trong bóng tối" — bản chạy NỀN ĐỊNH KỲ, hoạt
/// động kể cả khi app đã bị đóng hẳn (khác với
/// HabitProvider/DeviceDataService.startDarkRoomMonitoring() vốn chỉ nghe
/// cảm biến LIÊN TỤC trong lúc app còn tiến trình sống — xem giải thích ở
/// đó). Đánh đổi đã chọn: KHÔNG real-time (khoảng cách giữa 2 lần kiểm tra
/// tối thiểu ~15 phút — đây là giới hạn CỨNG của Android WorkManager, không
/// thể đặt nhanh hơn), đổi lại KHÔNG cần thông báo "đang chạy nền" thường
/// trực như cách làm bằng Foreground Service.
///
/// File này chạy trong 1 ISOLATE RIÊNG, hoàn toàn tách biệt với isolate
/// chính của app (main.dart) — không dùng chung được biến/singleton nào từ
/// phần còn lại của app (kể cả NotificationService.instance), nên phải tự
/// khởi tạo plugin thông báo VÀ đọc SharedPreferences riêng ở đây.
const String darkRoomBackgroundTaskName = 'dark_room_background_check';
const String _darkRoomUniqueTaskName = 'dark_room_periodic';

// Dùng đúng ngưỡng "tối" (10 lux) như bản foreground để nhất quán định
// nghĩa "phòng tối" trong toàn app.
const int _kDarkLuxThreshold = 10;
const String _kInDarkSessionKey = 'pref_dark_bg_in_dark_session';

class DarkRoomBackgroundService {
  DarkRoomBackgroundService._();

  /// Gọi 1 lần lúc app khởi động (main.dart) — đăng ký task định kỳ, an
  /// toàn khi gọi lại nhiều lần (WorkManager tự bỏ qua nếu task cùng tên đã
  /// tồn tại, nhờ existingWorkPolicy.keep).
  static Future<void> register() async {
    if (!Platform.isAndroid) return; // WorkManager 15 phút + cảm biến ánh sáng: chỉ hỗ trợ Android.
    await Workmanager().initialize(darkRoomBackgroundCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _darkRoomUniqueTaskName,
      darkRoomBackgroundTaskName,
      frequency: const Duration(minutes: 15), // tối thiểu của Android WorkManager, không thể nhanh hơn.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(requiresBatteryNotLow: false),
    );
  }

  static Future<void> unregister() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(_darkRoomUniqueTaskName);
  }
}

@pragma('vm:entry-point')
void darkRoomBackgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == darkRoomBackgroundTaskName) {
      try {
        await _checkDarkRoomOnce();
      } catch (_) {
        // Không để lỗi làm WorkManager coi task thất bại rồi retry dồn dập —
        // bỏ qua, chờ lần kiểm tra kế tiếp sau 15 phút.
      }
    }
    return Future.value(true);
  });
}

Future<void> _checkDarkRoomOnce() async {
  final prefs = await SharedPreferences.getInstance();

  final screenOn = await _isScreenOn();
  if (!screenOn) {
    // Màn hình đang tắt (máy trong túi/trên bàn) -> không phải đang thật sự
    // NHÌN màn hình, dù phòng có tối cũng không liên quan tới mỏi mắt do
    // dùng điện thoại. Reset luôn session để lần bật màn hình tiếp theo
    // trong bóng tối vẫn được cảnh báo bình thường.
    await prefs.setBool(_kInDarkSessionKey, false);
    return;
  }

  final lux = await _readAmbientLuxOnce();
  if (lux == null) return; // Không có/không đọc được cảm biến ánh sáng.

  if (lux >= _kDarkLuxThreshold) {
    // Đủ sáng -> hết 1 đợt tối (nếu có), cho phép cảnh báo lại ở đợt tối kế tiếp.
    await prefs.setBool(_kInDarkSessionKey, false);
    return;
  }

  // Đang tối + màn hình đang bật. Chỉ cảnh báo 1 LẦN cho mỗi ĐỢT tối liên
  // tục (không lặp lại mỗi 15 phút trong khi vẫn đang ở trong bóng tối).
  final alreadyNotifiedThisSession = prefs.getBool(_kInDarkSessionKey) ?? false;
  if (alreadyNotifiedThisSession) return;

  await prefs.setBool(_kInDarkSessionKey, true);
  await _showDarkRoomNotification();
}

Future<bool> _isScreenOn() async {
  const channel = MethodChannel('eye_care_ai/usage_events');
  try {
    final result = await channel.invokeMethod<bool>('isScreenOn');
    return result ?? true; // Không xác định được -> mặc định coi như đang bật (an toàn hơn là bỏ sót cảnh báo).
  } catch (_) {
    return true;
  }
}

Future<int?> _readAmbientLuxOnce({Duration timeout = const Duration(seconds: 3)}) async {
  final completer = Completer<int?>();
  StreamSubscription<int>? sub;
  Timer? timer;
  void finish(int? value) {
    if (completer.isCompleted) return;
    completer.complete(value);
    timer?.cancel();
    sub?.cancel();
  }

  try {
    sub = Light().lightSensorStream.listen(
          (lux) => finish(lux),
          onError: (_) => finish(null),
          cancelOnError: true,
        );
  } catch (_) {
    return null;
  }
  timer = Timer(timeout, () => finish(null));
  return completer.future;
}

// Isolate nền không dùng chung được NotificationService.instance của
// isolate chính (khác bộ nhớ hoàn toàn) — tự tạo 1 plugin instance riêng ở
// đây, và dùng kênh thông báo RIÊNG (không trùng kênh nhắc nghỉ mắt) để
// người dùng phân biệt được 2 loại thông báo.
Future<void> _showDarkRoomNotification() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await plugin.initialize(initSettings);

  const channel = AndroidNotificationChannel(
    'dark_room_background_channel',
    'Dark Room Warning (Background)',
    description: 'Cảnh báo dùng điện thoại trong bóng tối, kiểm tra định kỳ dù app đã đóng',
    importance: Importance.high,
  );
  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await plugin.show(
    1004,
    '🌙 Bạn đang dùng điện thoại trong bóng tối',
    'Ánh sáng yếu khiến mắt phải điều tiết nhiều hơn, dễ gây mỏi mắt. '
        'Hãy bật đèn hoặc giảm độ sáng màn hình cho phù hợp.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'dark_room_background_channel',
        'Dark Room Warning (Background)',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
