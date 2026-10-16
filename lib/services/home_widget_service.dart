import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_data_service.dart';
import 'notification_service.dart';

// Widget ngoài màn hình chính (Notion: Tính năng sắp tới) — hiển thị điểm
// hôm nay, chuỗi ngày và giờ nghỉ mắt kế tiếp. Dùng package `home_widget`
// (RemoteViews, không cần code Kotlin riêng): Dart đẩy dữ liệu, Android vẽ.
//
// Cập nhật mỗi lần mở app (gọi từ main_shell post-frame). Chưa có làm mới
// nền định kỳ — số trên widget là ảnh chụp lúc mở app gần nhất (ghi rõ ở
// commit). Tap vào widget mở app (PendingIntent mặc định của package).
class HomeWidgetService {
  static const _androidProvider =
      'es.antonborri.home_widget.HomeWidgetProvider';

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vi = prefs.getBool('pref_vietnamese') ?? true;
      final now = DateTime.now();

      final snap = await DeviceDataService.instance.loadDailySnapshot(now);
      final streak = await DeviceDataService.instance.calculateStreakDays();
      final nextBreak = await NotificationService.instance
          .getNextRepeatingFireAt();

      await HomeWidget.saveWidgetData<String>('widget_title', 'EyeCare AI');
      await HomeWidget.saveWidgetData<String>(
        'widget_score',
        snap != null ? '${snap.score}' : '--',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_streak',
        vi ? 'Chuỗi $streak ngày' : '$streak-day streak',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_next',
        nextBreak != null
            ? (vi
                  ? 'Nghỉ tiếp theo ${_twoDigits(nextBreak.hour)}:${_twoDigits(nextBreak.minute)}'
                  : 'Next break ${_twoDigits(nextBreak.hour)}:${_twoDigits(nextBreak.minute)}')
            : (vi ? 'Chưa bật nhắc nghỉ mắt' : 'Break reminders off'),
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: _androidProvider);
    } catch (_) {
      // Widget chỉ là phụ — không để lỗi ở đây làm hỏng luồng khởi động app.
    }
  }
}
