import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:light/light.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'eye_timeline_service.dart';

/// Đọc ánh sáng môi trường (lux) + độ sáng màn hình hiện tại, rồi tính và áp
/// dụng độ sáng ĐỀ XUẤT khớp với môi trường — hậu thuẫn cho tính năng "Gợi ý
/// độ sáng" ở màn hình Cài đặt (trước đây chỉ là 1 dialog tip tĩnh, không
/// làm được gì thật với máy).
class BrightnessService {
  BrightnessService._();
  static final BrightnessService instance = BrightnessService._();

  /// Đọc 1 mẫu lux từ cảm biến ánh sáng — chỉ lấy giá trị ĐẦU TIÊN trong
  /// [timeout] rồi hủy đăng ký ngay (khác với DeviceDataService vốn lắng
  /// nghe liên tục cho tính năng cảnh báo phòng tối), vì ở đây chỉ cần 1 lần
  /// đọc tức thời khi người dùng mở dialog, không cần theo dõi liên tục.
  Future<int?> readAmbientLux({Duration timeout = const Duration(seconds: 3)}) async {
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

  /// Độ sáng màn hình hệ thống hiện tại (0.0 - 1.0), null nếu không đọc được.
  Future<double?> getCurrentSystemBrightness() async {
    try {
      return await ScreenBrightness.instance.system;
    } catch (_) {
      return null;
    }
  }

  /// App có được phép đổi độ sáng HỆ THỐNG hay chưa (quyền đặc biệt của
  /// Android, không xin được bằng popup thường — xem [openSystemSettings]).
  Future<bool> canChangeSystemBrightness() async {
    if (!Platform.isAndroid) return true; // iOS: app luôn tự đổi được app-level brightness.
    try {
      return await ScreenBrightness.instance.canChangeSystemBrightness;
    } catch (_) {
      return false;
    }
  }

  /// Mở đúng màn hình hệ thống "Cho phép sửa đổi cài đặt hệ thống" cho app
  /// này — người dùng chỉ cần bật gạt 1 lần, không cần tìm trong Settings.
  Future<void> openSystemSettings() async {
    if (!Platform.isAndroid) return;
    final packageInfo = await PackageInfo.fromPlatform();
    final intent = AndroidIntent(
      action: 'android.settings.action.MANAGE_WRITE_SETTINGS',
      data: 'package:${packageInfo.packageName}',
    );
    await intent.launch();
  }

  /// Ánh xạ lux đo được -> độ sáng màn hình đề xuất (0.0 - 1.0). Dựa theo
  /// nguyên tắc "Auto-brightness" phổ biến: môi trường càng sáng thì màn
  /// hình càng cần sáng hơn để chữ vẫn rõ, môi trường tối thì hạ thấp để đỡ
  /// chói/mỏi mắt — các mốc lux lấy theo thang đo lux tiêu chuẩn (phòng tối
  /// <10 lux, trong nhà bình thường vài trăm lux, ngoài trời nắng >1000 lux).
  double suggestBrightnessForLux(int lux) {
    if (lux < 10) return 0.08;
    if (lux < 50) return 0.20;
    if (lux < 150) return 0.35;
    if (lux < 300) return 0.50;
    if (lux < 1000) return 0.70;
    return 1.0;
  }

  /// Áp dụng độ sáng HỆ THỐNG mới. Trả về true nếu thành công; false nếu bị
  /// từ chối do thiếu quyền (gọi [canChangeSystemBrightness]/[openSystemSettings]
  /// trước đó để tránh rơi vào trường hợp này).
  Future<bool> applySystemBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setSystemScreenBrightness(value.clamp(0.0, 1.0));
      // Ghi vào Dòng thời gian mắt. "Tự động điều chỉnh độ sáng" gọi hàm này
      // liên tục (mỗi ~1.5 giây) nên PHẢI chặn spam: tối đa 1 sự kiện/20 phút.
      unawaited(EyeTimelineService.instance.log(
        TimelineEventType.brightnessAdjusted,
        minGap: const Duration(minutes: 20),
      ));
      return true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}