import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// PHẢI là hàm top-level hoặc static + có @pragma('vm:entry-point') — đây là
// yêu cầu bắt buộc của flutter_local_notifications để callback này còn gọi
// được khi app đã bị hệ điều hành tắt hẳn (chạy trong 1 isolate nền riêng,
// tách biệt hoàn toàn với isolate chính của app). Chỉ dùng để ghi nhận việc
// nhấn thông báo lúc app đã đóng — việc điều hướng thật sự tới EyeBreakScreen
// vẫn diễn ra bình thường vì Android sẽ tự khởi động lại isolate chính của
// app khi người dùng nhấn thông báo, và NotificationService.initialize() gọi
// lại ở đó sẽ nhận được response qua getNotificationAppLaunchDetails() (xem
// main.dart) — hàm dưới đây chỉ là bắt buộc về mặt kỹ thuật của plugin, bản
// thân nó không cần làm gì thêm.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {}

// NotificationService quản lý toàn bộ thông báo cục bộ của app.
//
// Có 2 loại thông báo cho tính năng nhắc nghỉ mắt:
// 1. showInstantNotification: bắn ngay lập tức (dùng khi countdown đang chạy
//    trong app và vừa về 0 trong lúc người dùng đang mở app).
// 2. scheduleBreakAlarm: LÊN LỊCH TRƯỚC cho một thời điểm trong tương lai,
//    do hệ điều hành tự bắn đúng giờ dù app đã bị đóng/thu nhỏ — đây là cách
//    đảm bảo người dùng vẫn được nhắc kể cả khi không mở app.
//
// ÂM THANH RIÊNG: nếu bạn thêm 1 file âm thanh vào
// android/app/src/main/res/raw/eye_break_alert.mp3 (hoặc .wav/.ogg — KHÔNG có
// khoảng trắng/ký tự hoa trong tên file, chỉ chữ thường/số/gạch dưới), app sẽ
// tự dùng file đó làm âm thanh thông báo thay vì âm mặc định của hệ thống.
// Nếu chưa có file này, code vẫn chạy bình thường với âm thanh mặc định.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'eye_break_channel';
  static const _channelName = 'Eye Break Reminder';
  static const _alarmNotificationId = 1001;

  // Thông báo GHIM (ongoing) hiển thị thời gian còn lại trong lúc đếm ngược
  // đang chạy — kênh riêng vì cần im lặng (không kêu/rung mỗi lần cập nhật
  // nội dung), khác hẳn với thông báo hết-giờ ở trên.
  static const _ongoingChannelId = 'break_ongoing_channel';
  static const _ongoingChannelName = 'Break Reminder Countdown';
  static const ongoingNotificationId = 1002;

  // Đổi tên này nếu bạn đặt tên file âm thanh khác trong thư mục res/raw.
  static const String _customSoundResourceName = 'eye_break_alert';
  // QUAN TRỌNG: đặt true CHỈ SAU KHI bạn đã thật sự thêm file
  // android/app/src/main/res/raw/eye_break_alert.mp3 (hoặc .wav/.ogg) vào
  // project. Nếu để true mà file không tồn tại, Android sẽ ném
  // PlatformException(invalid_sound, ...) ở CẢ 3 chế độ lên lịch báo thức
  // trong scheduleBreakAlarm() -> báo thức không bao giờ được đặt thành
  // công, và vì lỗi trước đây bị nuốt im lặng nên trông y hệt "bị OEM chặn"
  // dù không phải vậy. Đây là nguyên nhân thật của lỗi "không nhắc nghỉ mắt"
  // đã gặp — để false để dùng âm thanh mặc định của hệ thống, luôn hoạt động.
  static const bool _useCustomSound = false;

  // --- Báo thức LẶP LẠI cho break reminder ---
  // TRƯỚC ĐÂY dùng android_alarm_manager_plus (AndroidAlarmManager.periodic)
  // để lặp báo thức qua một Dart isolate nền riêng. Vấn đề: main.dart gọi
  // AndroidAlarmManager.initialize() ngay khi app khởi động (để "sẵn sàng"),
  // việc này tự spawn 1 background-execution engine. Khi báo thức lặp tới
  // giờ và cố spawn isolate của RIÊNG NÓ để chạy callback, plugin phát hiện
  // "đã có 1 isolate nền" (do bước initialize ở trên) và IN CẢNH BÁO RỒI BỎ
  // QUA LUÔN, không gọi callback: "Attempted to start a duplicate background
  // isolate. Returning..." — đây là nguyên nhân thật của việc "hết giờ vẫn
  // không có thông báo gì", lỗi này không ném exception nên trước đây không
  // ai biết. Đây là hạn chế đã biết của android_alarm_manager_plus khi tiến
  // trình Flutter chính vẫn còn sống (app ở nền, chưa bị hệ điều hành kill).
  //
  // GIẢI PHÁP: dùng notifications.periodicallyShowWithDuration() của chính
  // flutter_local_notifications — đây là báo thức lặp HOÀN TOÀN NATIVE (do
  // Android tự bắn qua AlarmManager + hiện notification bằng code Java/Kotlin
  // của plugin), KHÔNG cần khởi động bất kỳ Dart isolate nào để hiển thị
  // thông báo. Vì không có isolate nào được spawn khi báo thức bắn, không
  // thể xảy ra xung đột "duplicate isolate" nữa.
  static const int _repeatingNotificationId = 5001;
  static const String _kRepeatIntervalMinutesKey = 'pref_break_repeat_interval_minutes';
  static const String _kOngoingTitleKey = 'pref_break_ongoing_title';
  static const String _kOngoingSuffixKey = 'pref_break_ongoing_suffix';
  // Mốc giờ BẮT ĐẦU của chu kỳ lặp (lúc bấm Start) — vì báo thức lặp giờ là
  // native thuần tuý (không có callback Dart nào chạy mỗi lần bắn để tự ghi
  // lại "lần kế tiếp"), nên mốc giờ nhắc kế tiếp được TÍNH TOÁN LẠI trong
  // Dart (endAt = startedAt + n * interval, với n đủ lớn để > hiện tại) thay
  // vì đọc từ một giá trị được ghi bởi background isolate như trước.
  static const String _kRepeatStartedAtKey = 'pref_break_repeat_started_at_millis';

  bool _initialized = false;

  // Gọi khi người dùng NHẤN vào thông báo "Đến giờ nghỉ mắt" (payload =
  // breakReminderPayload) — main.dart gán hàm này để điều hướng thẳng tới
  // EyeBreakScreen thông qua 1 navigatorKey toàn cục, tách biệt tầng service
  // (ở đây) khỏi tầng UI/route.
  void Function()? onBreakReminderTapped;

  // Payload đính kèm thông báo hết-giờ-nghỉ-mắt — dùng để phân biệt với các
  // thông báo khác (vd cảnh báo dùng điện thoại trong bóng tối) khi người
  // dùng nhấn vào, tránh điều hướng nhầm màn hình.
  static const String breakReminderPayload = 'break_reminder';

  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload == breakReminderPayload) {
      onBreakReminderTapped?.call();
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      // Xử lý trường hợp app đã bị tắt hẳn (không chỉ thu nhỏ) và người dùng
      // mở lại app bằng cách nhấn vào thông báo — plugin yêu cầu callback nền
      // này phải là 1 hàm TOP-LEVEL hoặc STATIC (không được là closure/method
      // của instance), xem _onBackgroundNotificationResponse bên dưới.
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Tạo kênh thông báo với âm thanh riêng (nếu có file) — phải tạo kênh
    // TRƯỚC khi gửi thông báo đầu tiên, vì Android không cho đổi âm thanh của
    // một kênh đã tồn tại (phải tạo kênh mới nếu muốn đổi âm sau này).
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Nhắc nghỉ mắt theo quy tắc 20-20-20',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: _useCustomSound ? RawResourceAndroidNotificationSound(_customSoundResourceName) : null,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    await androidPlugin?.createNotificationChannel(channel);

    // Kênh riêng cho thông báo ghim đếm ngược: importance thấp, không âm
    // thanh/rung vì được cập nhật liên tục (mỗi giây) chứ không phải bắn 1
    // lần như thông báo hết giờ.
    const ongoingChannel = AndroidNotificationChannel(
      _ongoingChannelId,
      _ongoingChannelName,
      description: 'Hiển thị thời gian còn lại tới lần nhắc nghỉ mắt tiếp theo',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    await androidPlugin?.createNotificationChannel(ongoingChannel);

    await androidPlugin?.requestNotificationsPermission();

    await notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  // Các quyền dưới đây (báo thức chính xác, miễn trừ tối ưu pin) dùng
  // package permission_handler / plugin cần một Activity ĐÃ ATTACH xong để
  // hoạt động. Nếu gọi quá sớm (trước runApp/trước khi Activity gắn xong —
  // ví dụ ngay trong main() trước khi khung hình đầu tiên được vẽ), plugin sẽ
  // ném lỗi "Permission launcher not found" và không hiện dialog gì cả.
  //
  // => Hàm này PHẢI được gọi SAU khi widget tree đã build xong lần đầu, ví
  // dụ trong initState() của widget gốc kèm addPostFrameCallback, KHÔNG được
  // gọi trong main() trước runApp().
  Future<void> requestDeferredSystemPermissions() async {
    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // requestExactAlarmsPermission() MỞ THẲNG một màn hình Settings của hệ
    // thống (ảnh "Chuông báo và lời nhắc") — nếu gọi lại mỗi lần app khởi
    // động thì người dùng cứ bị đưa tới màn đó liên tục dù đã cấp/từ chối rồi
    // trước đó. Chỉ gọi hàm này MỘT LẦN DUY NHẤT trong vòng đời cài đặt app.
    final prefs = await SharedPreferences.getInstance();
    const askedKey = 'pref_exact_alarm_permission_asked';
    if (!(prefs.getBool(askedKey) ?? false)) {
      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (_) {
        // Bỏ qua nếu Activity chưa sẵn sàng hoặc thiết bị không hỗ trợ.
      }
      await prefs.setBool(askedKey, true);
    }

    // NHIỀU HÃNG MÁY (Xiaomi/MIUI, Oppo, Vivo, Samsung...) tự ý "diệt" tiến
    // trình app chạy nền để tiết kiệm pin — khi đó timer đang đếm VÀ báo thức
    // đã lên lịch đều có thể không bắn đúng giờ. Xin miễn trừ tối ưu hoá pin
    // giúp giảm đáng kể tình trạng này. Cũng chỉ hỏi 1 LẦN DUY NHẤT như quyền
    // báo thức chính xác ở trên, để không làm phiền người dùng mỗi lần mở app.
    const batteryAskedKey = 'pref_battery_optimization_asked';
    if (!(prefs.getBool(batteryAskedKey) ?? false)) {
      try {
        await Permission.ignoreBatteryOptimizations.request();
      } catch (_) {
        // Bỏ qua nếu thiết bị/ROM không hỗ trợ dialog này.
      }
      await prefs.setBool(batteryAskedKey, true);
    }
  }

  NotificationDetails _details({bool insistent = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Nhắc nghỉ mắt theo quy tắc 20-20-20',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        sound: _useCustomSound ? RawResourceAndroidNotificationSound(_customSoundResourceName) : null,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
        // FLAG_INSISTENT (4): lặp lại âm thanh + rung liên tục cho đến khi
        // người dùng chạm vào thông báo, giống chuông báo thức. Chỉ bật cho
        // thông báo hết-giờ-nghỉ-mắt thật sự, không dùng cho thông báo phụ.
        additionalFlags: insistent ? Int32List.fromList(<int>[4]) : null,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }
  Future<void> showNightModeSuggestion({
    required int currentPercent,
    required int suggestedPercent,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'night_mode_advisor',
      'Night Mode Advisor',
      channelDescription: 'Gợi ý giảm độ sáng màn hình vào ban đêm',
      importance: Importance.high,
      priority: Priority.high,
    );

    await notifications.show(
      2001,
      '🌙 Gợi ý giảm độ sáng',
      'Phòng đang tối nhưng màn hình ở $currentPercent%. Giảm xuống $suggestedPercent% để dễ chịu hơn?',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    bool insistent = false,
  }) async {
    await initialize();
    await notifications.show(0, title, body, _details(insistent: insistent));
  }

  // Lên lịch một thông báo cho thời điểm `when` trong tương lai — hệ điều
  // hành sẽ tự bắn đúng giờ này dù app đang đóng hay chạy nền.
  Future<void> scheduleBreakAlarm(
    DateTime when, {
    required String title,
    required String body,
  }) async {
    await initialize();
    await cancelBreakAlarm();

    final scheduledDate = tz.TZDateTime.from(when, tz.local);
    // THỨ TỰ ƯU TIÊN CÁC CHẾ ĐỘ LÊN LỊCH (từ đáng tin cậy nhất):
    // 1. alarmClock: hệ thống coi như MỘT BÁO THỨC THẬT — gần như miễn nhiễm
    //    với Doze/App Standby và các trình diệt tiến trình nền của OEM
    //    (Xiaomi/MIUI, Oppo, Vivo...), đây là lý do chính khiến bản trước
    //    "hết giờ vẫn không báo" khi app bị hệ điều hành đóng ở nền. Nhược
    //    điểm nhỏ: có thể hiện icon đồng hồ báo thức trên thanh trạng thái.
    // 2. exactAllowWhileIdle: dùng nếu alarmClock ném lỗi (hiếm, một số ROM
    //    chặn riêng chế độ này).
    // 3. inexactAllowWhileIdle: phương án cuối, không cần quyền đặc biệt,
    //    đảm bảo vẫn có thông báo dù có thể trễ vài phút.
    //
    // TRƯỚC ĐÂY: nếu CẢ 3 chế độ đều ném lỗi (ví dụ do OEM chặn quyền báo
    // thức), lỗi bị `catch (_) {}` nuốt im lặng — báo thức coi như KHÔNG BAO
    // GIỜ được đặt, nhưng không ai biết vì sao. Giờ log rõ lỗi từng chế độ,
    // và verify lại bằng pendingNotificationRequests() sau khi "thành công"
    // để biết chắc hệ điều hành có thực sự nhận báo thức hay không.
    for (final mode in [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await notifications.zonedSchedule(
          _alarmNotificationId,
          title,
          body,
          scheduledDate,
          _details(insistent: true),
          androidScheduleMode: mode,
          payload: breakReminderPayload,
        );
        final pending = await notifications.pendingNotificationRequests();
        final registered = pending.any((p) => p.id == _alarmNotificationId);
        debugPrint(
          '[NotificationService] scheduleBreakAlarm mode=$mode at=$scheduledDate '
          'registeredWithOS=$registered',
        );
        if (registered) return;
      } catch (e, st) {
        debugPrint('[NotificationService] scheduleBreakAlarm mode=$mode FAILED: $e\n$st');
      }
    }
    debugPrint(
      '[NotificationService] scheduleBreakAlarm: ALL modes failed for $scheduledDate — '
      'no alarm was registered with the OS. This is almost always an OEM restriction '
      '(MIUI Autostart / battery optimization), not a plugin bug.',
    );
  }

  // --- Nhắc nghỉ mắt LẶP LẠI vô hạn ---
  // Khác với scheduleBreakAlarm() ở trên (chỉ bắn ĐÚNG 1 LẦN), hàm này dùng
  // periodicallyShowWithDuration() để hệ điều hành TỰ LẶP LẠI việc bắn thông
  // báo mỗi `intervalMinutes` phút — kể cả khi app đã bị tắt hẳn (không chỉ
  // thu nhỏ). Toàn bộ việc bắn + hiện thông báo diễn ra HOÀN TOÀN Ở PHÍA
  // NATIVE (Android AlarmManager + code Java/Kotlin của plugin), không có
  // Dart isolate nào được khởi động ở mỗi lần bắn — do đó title/body/kênh
  // âm thanh/rung phải đặt CỐ ĐỊNH ngay khi gọi hàm này, dùng lại y hệt cho
  // mọi lần bắn tiếp theo (không có cách nào "đổi nội dung" cho lần bắn kế
  // tiếp mà không hủy và đặt lại từ đầu). Cứ thế lặp lại đến khi
  // cancelRepeatingBreakAlarm() được gọi (khi người dùng vào app và tắt Break
  // Reminder).
  //
  // title đổi ngôn ngữ giữa chừng (người dùng đổi Settings) sẽ chỉ có hiệu
  // lực từ lần bấm Start tiếp theo — chấp nhận được vì đây là trade-off của
  // việc không còn phụ thuộc vào một Dart isolate nền dễ vỡ.
  Future<void> scheduleRepeatingBreakAlarm({
    required int intervalMinutes,
    required String title,
    required String body,
    required String ongoingTitle,
    required String ongoingRemainingSuffix,
  }) async {
    await initialize();
    await cancelRepeatingBreakAlarm();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRepeatIntervalMinutesKey, intervalMinutes);
    await prefs.setString(_kOngoingTitleKey, ongoingTitle);
    await prefs.setString(_kOngoingSuffixKey, ongoingRemainingSuffix);
    final startedAt = DateTime.now();
    await prefs.setInt(_kRepeatStartedAtKey, startedAt.millisecondsSinceEpoch);

    // periodicallyShowWithDuration lên lịch báo thức lặp HOÀN TOÀN NATIVE
    // (Android AlarmManager tự bắn + tự hiện notification bằng code của
    // plugin) — không có Dart isolate nào chạy khi báo thức bắn, nên chi
    // tiết thông báo (kênh, âm thanh, rung, insistent...) phải được đặt CỐ
    // ĐỊNH ngay tại đây, sẽ được dùng lại y hệt cho MỌI lần bắn tiếp theo.
    //
    // Lưu ý: kể từ Android 4.4 (KitKat), MỌI báo thức LẶP LẠI qua AlarmManager
    // (kể cả setExact) đều được hệ điều hành coi là "inexact" cho các lần lặp
    // sau lần đầu, để tiết kiệm pin — có thể trễ vài phút, đây là giới hạn
    // CỦA HỆ ĐIỀU HÀNH, không phải lỗi app. Vẫn dùng exactAllowWhileIdle cho
    // lần bắn ĐẦU TIÊN được chính xác nhất có thể; fallback về inexact nếu
    // thiết bị từ chối quyền báo thức chính xác.
    try {
      await notifications.periodicallyShowWithDuration(
        _repeatingNotificationId,
        title,
        body,
        Duration(minutes: intervalMinutes),
        _details(insistent: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: breakReminderPayload,
      );
    } catch (e, st) {
      debugPrint('[NotificationService] periodicallyShowWithDuration exact FAILED: $e\n$st');
      await notifications.periodicallyShowWithDuration(
        _repeatingNotificationId,
        title,
        body,
        Duration(minutes: intervalMinutes),
        _details(insistent: true),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: breakReminderPayload,
      );
    }

    final nextFireAt = startedAt.add(Duration(minutes: intervalMinutes));
    // Cập nhật ngay thông báo ghim với mốc giờ nhắc kế tiếp.
    await showStaticOngoingUntil(
      endAt: nextFireAt,
      title: ongoingTitle,
      untilPrefix: ongoingRemainingSuffix,
    );
  }

  Future<void> cancelRepeatingBreakAlarm() async {
    await notifications.cancel(_repeatingNotificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRepeatStartedAtKey);
    await prefs.remove(_kRepeatIntervalMinutesKey);
    await cancelOngoingCountdown();
  }

  // Vì báo thức lặp giờ là native thuần (không có callback Dart nào ghi lại
  // "lần kế tiếp" mỗi khi bắn), mốc giờ nhắc kế tiếp được TÍNH TOÁN LẠI từ
  // mốc bắt đầu (startedAt) + interval — dùng để đồng bộ UI đếm ngược trong
  // app, tránh lệch với báo thức thật của hệ điều hành.
  Future<DateTime?> getNextRepeatingFireAt() async {
    final prefs = await SharedPreferences.getInstance();
    final startedMillis = prefs.getInt(_kRepeatStartedAtKey);
    final intervalMinutes = prefs.getInt(_kRepeatIntervalMinutesKey);
    if (startedMillis == null || intervalMinutes == null || intervalMinutes <= 0) return null;

    final startedAt = DateTime.fromMillisecondsSinceEpoch(startedMillis);
    final intervalMs = intervalMinutes * 60 * 1000;
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    // Số chu kỳ đã trôi qua kể từ lúc bắt đầu, làm tròn LÊN để luôn ra mốc
    // TƯƠNG LAI gần nhất (nếu vừa khớp đúng lúc bắn thì nhảy sang chu kỳ kế).
    final cyclesPassed = (elapsedMs / intervalMs).floor() + 1;
    return startedAt.add(Duration(milliseconds: intervalMs * cyclesPassed));
  }


  // Yêu cầu quyền hiển thị thông báo (Android 13+ cần popup thật, các bản
  // cũ hơn/iOS thường tự cấp) — dùng riêng cho bước "Thông báo" trong Setup
  // Wizard, tách khỏi initialize() vì initialize() chạy quá sớm trong
  // main() (trước runApp), lúc đó gọi lại không hiện popup được nếu quyền
  // đã bị từ chối trước đó (chỉ hỏi được đúng 1 lần theo vòng đời OS).
  Future<bool> requestNotificationPermission() async {
    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? await androidPlugin.areNotificationsEnabled() ?? false;
    }
    final iosPlugin =
        notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true) ?? true;
  }

  // dùng để UI hiện gợi ý bật quyền này nếu bị tắt (khác với lúc mới cài,
  // requestExactAlarmsPermission() chỉ tự hỏi đúng 1 lần).
  Future<bool> canScheduleExactAlarms() async {
    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? true;
  }

  // Mở thẳng màn hình Settings hệ thống để người dùng tự cấp lại quyền báo
  // thức chính xác nếu trước đó đã từ chối.
  Future<void> openExactAlarmSettings() async {
    final androidPlugin =
        notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  // Android 14+ (API 34) THẮT CHẶT thêm: kể cả đã có quyền
  // USE_FULL_SCREEN_INTENT trong Manifest, thông báo hết-giờ-nghỉ-mắt vẫn có
  // thể chỉ hiện dạng thông báo thường (không tự bật màn hình / hiện pop-up
  // toàn màn hình) nếu người dùng chưa bật riêng công tắc "Hiển thị toàn màn
  // hình" cho app trong Settings — đây là nguyên nhân phổ biến khiến "Break
  // Reminder" có báo nhưng không thấy pop-up như các app báo thức khác.
  // Hàm này mở thẳng đúng màn hình cài đặt đó trên máy Android 14+.
  Future<void> openFullScreenIntentSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final intent = AndroidIntent(
        action: 'android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT',
        data: 'package:com.eyecare.eye_care_ai',
      );
      await intent.launch();
    } catch (_) {
      // Máy chạy Android < 14 không có màn hình cài đặt này -> bỏ qua.
    }
  }

  // "Chạy nền": nhiều hãng máy Android (Xiaomi, OPPO, Vivo, Samsung...) tự
  // ý dừng/đóng băng app đứng yên trong nền để tiết kiệm pin, kể cả khi đã
  // đặt báo thức chính xác đúng cách — đây là nguyên nhân phổ biến khiến
  // thông báo hết giờ nghỉ mắt bị trễ hoặc không kêu, ĐỘC LẬP với việc thiếu
  // receiver (đã sửa) hay thiếu quyền full-screen intent. Mở thẳng dialog hệ
  // thống xin loại trừ app khỏi tối ưu hoá pin để tăng độ tin cậy của báo
  // thức khi app không mở.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.eyecare.eye_care_ai',
      );
      await intent.launch();
    } catch (_) {
      // Nếu dialog trực tiếp bị chặn (một số ROM tùy biến không hỗ trợ) ->
      // đưa người dùng vào màn hình danh sách tối ưu hoá pin chung để tự tìm app.
      try {
        const fallback = AndroidIntent(
          action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        );
        await fallback.launch();
      } catch (_) {}
    }
  }

  Future<void> cancelBreakAlarm() async {
    await notifications.cancel(_alarmNotificationId);
  }

  // Hiện/cập nhật thông báo GHIM trên thanh thông báo, hiển thị mm:ss còn
  // lại. `ongoing: true` + `autoCancel: false` khiến người dùng không vuốt bỏ
  // được (chỉ biến mất khi cancelOngoingCountdown() được gọi, tức là khi
  // dừng/hết giờ) — đúng ý "ghim luôn trên thanh thông báo". `onlyAlertOnce`
  // đảm bảo mỗi lần cập nhật không kêu/rung lại.
  Future<void> updateOngoingCountdown({
    required int secondsRemaining,
    required String title,
    required String remainingSuffix,
    DateTime? endAt,
  }) async {
    await initialize();
    final clamped = secondsRemaining < 0 ? 0 : secondsRemaining;
    final details = AndroidNotificationDetails(
      _ongoingChannelId,
      _ongoingChannelName,
      channelDescription: 'Hiển thị thời gian còn lại tới lần nhắc nghỉ mắt tiếp theo',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showWhen: false,
    );

    // Hiện giờ đồng hồ sẽ nhắc (VD "Sẽ nhắc lúc 15:40") thay vì đếm ngược
    // mm:ss, vì đếm ngược theo phút/giây dễ gây cảm giác "chưa đủ đô" và khó
    // liếc nhanh trên thanh thông báo hơn một mốc giờ cố định.
    final at = endAt ?? DateTime.now().add(Duration(seconds: clamped));
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');

    await notifications.show(
      ongoingNotificationId,
      title,
      '$remainingSuffix $hh:$mm',
      NotificationDetails(android: details),
    );
  }

  Future<void> cancelOngoingCountdown() async {
    await notifications.cancel(ongoingNotificationId);
  }

  // Khi app bị đưa xuống nền, Timer trong Dart không còn chạy được nữa nên
  // updateOngoingCountdown() sẽ ngừng cập nhật — người dùng kéo thanh thông
  // báo ra sẽ thấy mm:ss "đứng hình" mãi ở giá trị cuối cùng trước khi rời
  // app, gây cảm giác app bị treo. Để tránh nhầm lẫn này, ngay khi app
  // chuyển xuống nền, đổi nội dung thông báo ghim sang giờ hẹn CỐ ĐỊNH
  // (VD: "Sẽ nhắc lúc 15:40") thay vì con số đang chạy — báo thức thật
  // (scheduleBreakAlarm) vẫn tự bắn đúng giờ này dù thông báo ghim không
  // còn "tick" nữa.
  Future<void> showStaticOngoingUntil({
    required DateTime endAt,
    required String title,
    required String untilPrefix,
  }) async {
    await initialize();
    final hh = endAt.hour.toString().padLeft(2, '0');
    final mm = endAt.minute.toString().padLeft(2, '0');
    const details = AndroidNotificationDetails(
      _ongoingChannelId,
      _ongoingChannelName,
      channelDescription: 'Hiển thị thời gian còn lại tới lần nhắc nghỉ mắt tiếp theo',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showWhen: false,
    );
    await notifications.show(
      ongoingNotificationId,
      title,
      '$untilPrefix $hh:$mm',
      const NotificationDetails(android: details),
    );
  }
}