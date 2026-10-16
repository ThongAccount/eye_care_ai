import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:light/light.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'usage_service.dart';

// Một dòng dữ liệu sử dụng của MỘT app trong ngày hôm nay, dùng cho biểu đồ
// tròn "App Usage Breakdown" ở trang Thống kê.
class AppUsageBreakdownEntry {
  AppUsageBreakdownEntry({
    required this.packageName,
    required this.appName,
    required this.usage,
    this.launchCount,
  });

  final String packageName;
  final String appName;
  final Duration usage;
  // Số lần mở app hôm nay. null nếu không lấy được (thiếu code native hoặc
  // chưa build lại app sau khi thêm MainActivity.kt).
  final int? launchCount;
}

// DeviceDataService chịu trách nhiệm lấy dữ liệu THẬT từ điện thoại
// (cảm biến, hệ điều hành, GPS) thay vì để người dùng tự nhập tay.
//
// Mỗi hàm getX() trả về:
//  - một giá trị số nếu lấy được dữ liệu thật
//  - null nếu nguồn dữ liệu không khả dụng trên thiết bị/nền tảng hiện tại
//    (ví dụ: iOS không cho đọc tổng screen-time qua API công khai),
//    khi đó UI sẽ hiển thị trạng thái "Chưa có nguồn dữ liệu" thay vì số giả.
//
// LƯU Ý QUAN TRỌNG (đọc trước khi build lên máy thật):
// - Android: cần cấp quyền "Usage access" thủ công trong Settings cho phone usage,
//   và bật Health Connect cho dữ liệu giấc ngủ.
// - iOS: cần bật capability "HealthKit" trong Xcode + khai báo mô tả quyền trong
//   Info.plist (đã thêm sẵn) để đọc giấc ngủ qua HealthKit.
// - Front-camera gaze detection (Eye Breaks) CHƯA được cài ở đây: đây là một
//   tính năng ML riêng (face/gaze detection liên tục qua camera), cần được
//   thiết kế kỹ về hiệu năng pin + quyền riêng tư trước khi triển khai, nên
//   habit "breaks" tạm thời vẫn là số 0 + trạng thái "Chưa có nguồn dữ liệu".
class DeviceDataService {
  DeviceDataService._();
  static final DeviceDataService instance = DeviceDataService._();

  static const _kOutdoorMinutesKey = 'outdoor_minutes_today';
  static const _kOutdoorDateKey = 'outdoor_minutes_date';
  static const _kReadingMinutesKey = 'reading_minutes_today';
  static const _kReadingDateKey = 'reading_minutes_date';

  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _outdoorSampleTimer;
  DateTime? _lastOutdoorSample;
  DateTime? _lastReadingSample;
  double _recentAccelVariance = 0;
  final List<double> _accelWindow = [];

  // ---------------- Phone Usage: real OS screen-on time ----------------
  // Android: dùng UsageStatsManager thông qua package app_usage.
  // Người dùng phải cấp quyền "Usage access" thủ công (không có runtime dialog).
  // iOS: Apple không cho app bên thứ ba đọc tổng screen-time -> trả về null.
  //
  // LƯU Ý: UsageStatsManager của Android đôi khi trả về NHIỀU dòng cho cùng
  // một package (do dữ liệu được gộp theo nhiều khung ngày/tuần/tháng chồng
  // nhau ở tầng hệ điều hành). Nếu cộng dồn tất cả các dòng một cách ngây thơ,
  // tổng thời gian sẽ bị đếm trùng và cao hơn thực tế (vd: 5h58p thực tế lại
  // hiện thành 8.9h). Cách xử lý: gom theo packageName, chỉ lấy giá trị LỚN
  // NHẤT cho mỗi package (không cộng dồn các dòng trùng), sau đó mới cộng
  // tổng giữa các package khác nhau.
  Future<double?> getPhoneUsageHours() async {
    if (!Platform.isAndroid) return null;
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final breakdown = await getAppUsageBreakdownToday();
      if (breakdown.isEmpty) return null;

      final totalSeconds = breakdown.fold<int>(0, (sum, e) => sum + e.usage.inSeconds);

      // Chặn trên an toàn: tổng thời gian dùng máy không thể vượt quá số giờ
      // thực tế đã trôi qua từ đầu ngày đến giờ. Nếu vượt (do lỗi hệ điều
      // hành hiếm gặp), cắt về mốc này để tránh hiện số vô lý.
      final elapsedSecondsToday = now.difference(startOfDay).inSeconds;
      final clampedSeconds = totalSeconds > elapsedSecondsToday
          ? elapsedSecondsToday
          : totalSeconds;

      return clampedSeconds / 3600.0;
    } catch (_) {
      // Quyền chưa được cấp hoặc thiết bị không hỗ trợ.
      return null;
    }
  }

  // ---------------- Per-app usage breakdown (for the Statistics pie chart) ----------------
  static const _usageEventsChannel = MethodChannel('eye_care_ai/usage_events');

  Future<Map<String, int>> _getLaunchCounts(DateTime start, DateTime end) async {
    if (!Platform.isAndroid) return {};
    try {
      final raw = await _usageEventsChannel.invokeMapMethod<String, dynamic>(
        'getLaunchCounts',
        {
          'startMillis': start.millisecondsSinceEpoch,
          'endMillis': end.millisecondsSinceEpoch,
        },
      );
      return raw?.map((key, value) => MapEntry(key, (value as num).toInt())) ?? {};
    } catch (_) {
      // Kênh native chưa sẵn sàng (vd: chưa rebuild app) -> UI hiện "Chưa có
      // dữ liệu" cho số lần mở thay vì lỗi.
      return {};
    }
  }

  Future<List<AppUsageBreakdownEntry>> getAppUsageBreakdownToday() async {
    if (!Platform.isAndroid) return [];
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final launchCounts = await _getLaunchCounts(startOfDay, now);

      final raw = await _usageEventsChannel.invokeListMethod<dynamic>(
        'getUsageBreakdown',
        {
          'startMillis': startOfDay.millisecondsSinceEpoch,
          'endMillis': now.millisecondsSinceEpoch,
        },
      );

      if (raw == null) return [];

      final entries = raw.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final packageName = map['packageName'] as String;
        return AppUsageBreakdownEntry(
          packageName: packageName,
          appName: map['appName'] as String,
          usage: Duration(milliseconds: (map['usageMillis'] as num).toInt()),
          launchCount: launchCounts[packageName],
        );
      }).toList()
        ..sort((a, b) => b.usage.compareTo(a.usage));

      // Trả về TOÀN BỘ danh sách (không cắt bớt) — màn hình Thống kê sẽ tự
      // gộp các app ít dùng vào một lát "Khác..." để tổng luôn khớp chính
      // xác với tổng thời gian dùng máy thật.
      return entries;
    } catch (_) {
      // Kênh native chưa sẵn sàng (chưa rebuild app sau khi thêm code Kotlin
      // mới) hoặc lỗi khác -> trả về rỗng, UI hiện "Chưa có nguồn dữ liệu".
      return [];
    }
  }

  // Android không cho xin quyền "Usage access" qua runtime dialog, nhưng CÓ
  // một intent hệ thống mở thẳng màn hình danh sách "Usage access" (thay vì
  // chỉ mở trang Settings chung của app) — người dùng chỉ còn phải tìm tên
  // app trong danh sách rồi bật lên, đỡ hơn vài bước so với trước.
  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS');
      await intent.launch();
    } catch (_) {
      // Một số ROM tùy biến không hỗ trợ intent trên -> lùi về mở Settings
      // chung của app để người dùng tự điều hướng tiếp.
      await openAppSettings();
    }
  }

  // Kiểm tra xem quyền Usage Access đã được cấp hay chưa, để UI hiện đúng
  // trạng thái thay vì chỉ đoán qua việc dữ liệu có về hay không.
  Future<bool> hasUsageAccessPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _usageEventsChannel.invokeMethod<bool>('hasUsageAccess');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Sleep: ước lượng từ Usage Events ----------------
  // BỎ Health Connect (package `health`) — không phải máy nào cũng cài đặt
  // sẵn Health Connect, và nó đòi thêm 1 quyền riêng gây phiền cho 1 tính
  // năng phụ. Thay bằng suy luận từ chính Usage Access đã xin ở bước đầu
  // tiên (xem UsageStatsHandler.getSleepEstimate() phía native): lấy mốc
  // dùng máy lần cuối tối qua + lần đầu sáng nay, hiệu số 2 mốc đó xấp xỉ
  // thời gian ngủ. Đây là SUY LUẬN dựa trên thói quen dùng điện thoại,
  // KHÔNG phải đo giấc ngủ thật (không bắt được giấc ngủ trưa, không phát
  // hiện nếu người dùng thức nhưng không đụng máy) — độ chính xác thấp hơn
  // cảm biến chuyên dụng, nhưng không cần thêm quyền nào cả.
  Future<double?> getSleepHours() async {
    try {
      final minutes = await UsageService.getSleepEstimateMinutes();
      if (minutes == null) return null;
      return minutes / 60.0;
    } catch (_) {
      return null;
    }
  }

  // ---------------- Outdoor Time: GPS + cảm biến ánh sáng (lux) ----------------
  // CHỈ dùng GPS (như trước) không đáng tin: điện thoại đời mới dùng
  // A-GPS/định vị qua WiFi có thể cho fix "độ chính xác tốt" (<30m) ngay cả
  // khi đang ở TRONG NHÀ (gần cửa sổ, nhà khung gỗ/mái tôn mỏng, hoặc nhờ
  // WiFi xung quanh định vị hộ) — nghĩa là user đi lại trong nhà vẫn có thể
  // bị tính nhầm là "ngoài trời". Cách đáng tin hơn: kết hợp thêm cảm biến
  // ánh sáng — ánh sáng ban ngày ngoài trời (kể cả trời âm u) thường
  // >= 1000 lux, trong khi đèn trong nhà hiếm khi vượt quá vài trăm lux.
  // Chỉ tính là "ngoài trời" khi CẢ HAI điều kiện cùng đúng: GPS fix tốt
  // VÀ ánh sáng đủ mạnh — giảm mạnh trường hợp báo nhầm theo cả 2 chiều
  // (không chỉ GPS bị lừa bởi WiFi indoor, mà lux đơn lẻ cũng có thể bị lừa
  // bởi ánh nắng chiếu qua cửa sổ dù đang ngồi trong nhà).
  //
  // BUG ĐÃ SỬA (Outdoor Time gần như không bao giờ tăng): ngưỡng cũ (lux
  // >= 1000 VÀ GPS accuracy <= 30m trong đúng 5 giây) trên thực tế QUÁ KHẮT
  // KHE — cảm biến ánh sáng của nhiều điện thoại báo thấp hơn ánh sáng thật
  // khá nhiều (do lớp kính/lớp phủ che cảm biến), nên trời hơi âm u hoặc chỉ
  // đứng dưới bóng cây vẫn có thể không đạt 1000 lux dù rõ ràng đang ở ngoài
  // trời; đồng thời GPS lấy fix mới trong vòng 5 giây rất hay bị timeout
  // (đặc biệt lúc mới bật GPS/tín hiệu yếu), khiến _hasGoodGpsFix() gần như
  // luôn trả về false. Đã nới các mốc này (vẫn giữ nguyên tắc "cần cả 2 tín
  // hiệu" để tránh báo nhầm trong nhà) + thêm phương án dự phòng khi thiếu
  // 1 trong 2 tín hiệu, xem chi tiết ở _detectOutdoorSample/_hasGoodGpsFix.
  static const _kGpsGoodAccuracyMeters = 30.0; // độ chính xác GPS coi là "tốt"

  Future<double> getOutdoorMinutesToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs, _kOutdoorMinutesKey, _kOutdoorDateKey);
    return prefs.getDouble(_kOutdoorMinutesKey) ?? 0;
  }

  Future<void> startOutdoorTracking() async {
    _outdoorSampleTimer?.cancel();
    // Lấy mẫu mỗi 1 phút thay vì 2 phút trước đây — vừa phản hồi nhanh hơn
    // với việc ra/vào nhà, vừa giảm rủi ro "trót ở ngoài trời 90 giây nhưng
    // đúng lúc mẫu lấy vào giữa lúc GPS timeout" làm mất nguyên cả mẫu.
    _outdoorSampleTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final elapsedMinutes = _lastOutdoorSample == null
          ? 1.0
          : DateTime.now().difference(_lastOutdoorSample!).inSeconds / 60.0;
      _lastOutdoorSample = DateTime.now();

      final isOutdoor = await _detectOutdoorSample();
      if (isOutdoor == true) {
        final prefs = await SharedPreferences.getInstance();
        await _resetIfNewDay(prefs, _kOutdoorMinutesKey, _kOutdoorDateKey);
        final current = prefs.getDouble(_kOutdoorMinutesKey) ?? 0;
        await prefs.setDouble(_kOutdoorMinutesKey, current + elapsedMinutes);
      }
      // isOutdoor == false: trong nhà (thiếu GPS tốt, hoặc đủ GPS nhưng
      // ánh sáng không giống ngoài trời), không cộng dồn.
      // isOutdoor == null: không xác định được (mất quyền/dịch vụ vị trí bị
      // tắt) -> bỏ qua mẫu này hoàn toàn thay vì đoán mò.
    });
  }

  // CHỈ DÙNG GPS (theo yêu cầu): trước đây yêu cầu thêm ánh sáng (lux) nên
  // khi người dùng để điện thoại trong cặp/balo/túi (cảm biến ánh sáng bị
  // che, lux ~0) thì thời gian ngoài trời KHÔNG BAO GIỜ tăng dù đang đứng
  // ngoài nắng. Giờ chỉ xét việc có bắt được tín hiệu GPS tốt hay không.
  // Để vẫn phân biệt được trong nhà/ngoài trời mà không cần lux, xem
  // _hasGoodGpsFix: ép dùng chip GPS thuần (không Wi-Fi/cell), trong nhà
  // thường không bắt được fix.
  Future<bool?> _detectOutdoorSample() => _hasGoodGpsFix();

  // Đọc đúng 1 mẫu lux rồi hủy lắng nghe ngay — khác với
  // startDarkRoomMonitoring() ở dưới vốn lắng nghe LIÊN TỤC cho mục đích
  // khác (cảnh báo dùng điện thoại trong bóng tối); ở đây mỗi 1 phút chỉ cần
  // 1 lần đọc tức thời.
  Future<int?> _readAmbientLuxOnce({Duration timeout = const Duration(seconds: 3)}) async {
    if (!Platform.isAndroid) return null; // light sensor not available on iOS
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

  // Kiểm tra quyền vị trí đã được cấp hay chưa (không tự xin quyền ở đây —
  // việc xin quyền runtime nên do UI chủ động gọi requestLocationPermission()
  // để hiển thị đúng ngữ cảnh cho người dùng).
  Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // Xin quyền vị trí runtime. Gọi từ UI (VD: màn hình cài đặt Outdoor Time)
  // trước khi bật tracking, để người dùng hiểu vì sao app cần quyền này.
  Future<bool> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // Lấy 1 fix GPS và đánh giá độ chính xác. Trả về false khi thiếu quyền/dịch
  // vụ vị trí đang tắt/không bắt được fix.
  //
  // `forceLocationManager: true` ép Android dùng chip GPS THUẦN thay vì
  // FusedLocationProvider (vốn trộn Wi-Fi + cell tower nên trong nhà vẫn cho
  // "độ chính xác tốt"). Chip GPS cần nhìn thấy bầu trời: trong nhà/trong
  // cặp trong nhà thường timeout hoặc sai số lớn -> coi là "không ngoài
  // trời". Cố ý KHÔNG dùng getLastKnownPosition() làm dự phòng như trước, vì
  // vị trí cũ thường đến từ Wi-Fi/cell và sẽ làm lọt trường hợp trong nhà.
  // Timeout 15 giây vì GPS thuần "nguội" cần lâu hơn fused.
  Future<bool> _hasGoodGpsFix({double accuracyMeters = _kGpsGoodAccuracyMeters}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      final hasPermission = await hasLocationPermission();
      if (!hasPermission) return false;

      final settings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.best,
              forceLocationManager: true,
              timeLimit: const Duration(seconds: 15),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 15),
            );
      final position = await Geolocator.getCurrentPosition(locationSettings: settings);
      return position.accuracy <= accuracyMeters;
    } catch (_) {
      // Timeout (không thấy vệ tinh = nhiều khả năng đang trong nhà), dịch vụ
      // bị tắt giữa chừng, hoặc lỗi phần cứng.
      return false;
    }
  }

  // ---------------- Reading Time: accelerometer stillness heuristic ----------------
  // Không có plugin ambient-light-sensor nào còn được bảo trì tốt trên
  // pub.dev hiện tại, nên bước đầu chỉ dùng gia tốc kế: nếu điện thoại được
  // cầm khá yên (biến thiên gia tốc thấp) trong khoảng thời gian dài, tính là
  // đang "đọc". Đây là ước lượng gần đúng, không phải đo trực tiếp ánh sáng.
  Future<double> getReadingMinutesToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDay(prefs, _kReadingMinutesKey, _kReadingDateKey);
    return prefs.getDouble(_kReadingMinutesKey) ?? 0;
  }

  void startReadingTracking() {
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 500),
    ).listen((event) {
      final magnitude = event.x * event.x + event.y * event.y + event.z * event.z;
      _accelWindow.add(magnitude);
      if (_accelWindow.length > 20) _accelWindow.removeAt(0);
      if (_accelWindow.length < 5) return;

      final mean = _accelWindow.reduce((a, b) => a + b) / _accelWindow.length;
      final variance = _accelWindow
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          _accelWindow.length;
      _recentAccelVariance = variance;

      final isStill = _recentAccelVariance < 0.05;
      final now = DateTime.now();
      final elapsedMinutes = _lastReadingSample == null
          ? 0.5
          : now.difference(_lastReadingSample!).inSeconds / 60.0;
      _lastReadingSample = now;

      if (isStill && elapsedMinutes < 5) {
        SharedPreferences.getInstance().then((prefs) async {
          await _resetIfNewDay(prefs, _kReadingMinutesKey, _kReadingDateKey);
          final current = prefs.getDouble(_kReadingMinutesKey) ?? 0;
          await prefs.setDouble(_kReadingMinutesKey, current + elapsedMinutes);
        });
      }
    });
  }

  // ---------------- Eye Breaks: confirmed via the in-app break reminder ----------------
  // Trước đây dự tính dùng front-camera gaze detection, nhưng đó là một
  // pipeline ML riêng (hiệu năng pin + quyền riêng tư cần thiết kế kỹ) nên
  // thay vào đó: mỗi lần người dùng nhấn "Đã nghỉ mắt" ở màn hình nhắc nghỉ
  // mắt, số lần được cộng dồn và lưu theo ngày — đây vẫn là dữ liệu THẬT do
  // người dùng xác nhận, không phải số giả định sẵn.
  static const _kBreaksCountKey = 'eye_breaks_today';
  static const _kBreaksDateKey = 'eye_breaks_date';
  // Đếm dồn TOÀN BỘ THỜI GIAN (không reset theo ngày như 2 key ở trên) —
  // dùng riêng cho màn hình Thành tựu (trước đây các thẻ 5 lần/15 lần nghỉ
  // mắt bị hardcode "đã mở khoá" sẵn dù người dùng chưa làm gì; giờ tính
  // thật dựa trên số này, người cài app mới sẽ bắt đầu từ 0).
  static const _kBreaksTotalAllTimeKey = 'eye_breaks_total_alltime';

  Future<int> getEyeBreaksToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDayInt(prefs, _kBreaksCountKey, _kBreaksDateKey);
    return prefs.getInt(_kBreaksCountKey) ?? 0;
  }

  Future<int> getTotalEyeBreaksAllTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBreaksTotalAllTimeKey) ?? 0;
  }

  Future<int> recordEyeBreak() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetIfNewDayInt(prefs, _kBreaksCountKey, _kBreaksDateKey);
    final current = (prefs.getInt(_kBreaksCountKey) ?? 0) + 1;
    await prefs.setInt(_kBreaksCountKey, current);
    final totalAllTime = (prefs.getInt(_kBreaksTotalAllTimeKey) ?? 0) + 1;
    await prefs.setInt(_kBreaksTotalAllTimeKey, totalAllTime);
    return current;
  }

  Future<void> _resetIfNewDayInt(
    SharedPreferences prefs,
    String valueKey,
    String dateKey,
  ) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(dateKey);
    if (storedDate != today) {
      await prefs.setString(dateKey, today);
      await prefs.setInt(valueKey, 0);
    }
  }

  Future<void> _resetIfNewDay(
    SharedPreferences prefs,
    String valueKey,
    String dateKey,
  ) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(dateKey);
    if (storedDate != today) {
      await prefs.setString(dateKey, today);
      await prefs.setDouble(valueKey, 0);
    }
  }

  // ---------------- App-level flags persisted across restarts ----------------
  static const _kSurveyCompletedKey = 'survey_completed';

  Future<bool> isSurveyCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSurveyCompletedKey) ?? false;
  }

  Future<void> setSurveyCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSurveyCompletedKey, value);
  }

  // ---------------- Break reminder: persist the countdown across restarts ----------------
  static const _kBreakReminderEndKey = 'break_reminder_end_at';
  static const _kBreakReminderIntervalKey = 'break_reminder_interval_minutes';

  Future<void> saveBreakReminderEnd(DateTime endAt, int intervalMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBreakReminderEndKey, endAt.toIso8601String());
    await prefs.setInt(_kBreakReminderIntervalKey, intervalMinutes);
  }

  Future<void> clearBreakReminderEnd() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBreakReminderEndKey);
  }

  // Trả về thời điểm kết thúc đã lưu (null nếu không có bộ đếm nào đang chạy).
  Future<DateTime?> loadBreakReminderEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBreakReminderEndKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<int?> loadBreakReminderIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBreakReminderIntervalKey);
  }

  // ---------------- Daily snapshot history (for real Statistics charts) ----------------
  // Mỗi ngày, sau khi đồng bộ dữ liệu thiết bị xong, HabitProvider lưu lại
  // MỘT snapshot của ngày hôm đó (điểm hoàn thành habit, giờ dùng màn hình,
  // giờ ngủ). Biểu đồ tuần ở trang Thống kê đọc từ đây thay vì số liệu giả
  // cố định — những ngày CHƯA TỚI trong tuần hiện tại sẽ không có snapshot,
  // UI sẽ vẽ chúng như đoạn chưa hoàn thành thay vì bịa số.
  static const _kDailySnapshotPrefix = 'daily_snapshot_';

  Future<void> saveDailySnapshot({
    required int score,
    required double screenHours,
    required double sleepHours,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(
      '$_kDailySnapshotPrefix$today',
      '$score|$screenHours|$sleepHours',
    );
  }

  // Trả về snapshot cho một ngày cụ thể, null nếu ngày đó chưa có dữ liệu
  // (chưa tới, hoặc người dùng không mở app hôm đó).
  Future<({int score, double screenHours, double sleepHours})?> loadDailySnapshot(
    DateTime date,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kDailySnapshotPrefix${date.toIso8601String().substring(0, 10)}';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3) return null;
    return (
      score: int.tryParse(parts[0]) ?? 0,
      screenHours: double.tryParse(parts[1]) ?? 0,
      sleepHours: double.tryParse(parts[2]) ?? 0,
    );
  }

  // ---------------- Daily FACTOR snapshot (cho so sánh hôm qua vs hôm nay) ----------------
  // Khác với `daily_snapshot_*` ở trên (chỉ giữ điểm TỔNG + giờ màn hình/ngủ
  // để vẽ biểu đồ), đây lưu riêng % của TỪNG YẾU TỐ trong Eye Health Score
  // (Thời gian màn hình, Môi trường, Nghỉ mắt, Giấc ngủ) của MỖI NGÀY — cần
  // thiết để so sánh "hôm nay so với hôm qua" theo TỪNG yếu tố riêng lẻ (xem
  // HabitProvider.factorDeltas), thay vì chỉ so được mỗi điểm tổng như trước.
  // Giá trị null (yếu tố chưa có dữ liệu hôm đó) được lưu thành chuỗi rỗng,
  // phân biệt với 0% (có dữ liệu nhưng đang xấu).
  //
  // LƯU Ý: định dạng lưu trữ vẫn giữ 5 trường (khớp dữ liệu lịch sử đã lưu
  // trước đây khi còn có "Khoảng cách") để không làm hỏng snapshot cũ trên
  // máy người dùng — trường thứ 2 (distance) giờ LUÔN được ghi rỗng và
  // KHÔNG được đọc lại (loadDailyFactorScores trả về null cho distanceScore).
  static const _kDailyFactorsPrefix = 'daily_factors_';

  Future<void> saveDailyFactorScores({
    double? screenTimeScore,
    double? environmentScore,
    double? eyeBreaksScore,
    double? sleepScore,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    String enc(double? v) => v == null ? '' : v.toStringAsFixed(2);
    await prefs.setString(
      '$_kDailyFactorsPrefix$today',
      // Trường thứ 2 (giữa screenTimeScore và environmentScore) là ô
      // "distance" CŨ, luôn để rỗng — giữ nguyên vị trí cột để không phá
      // định dạng của các snapshot đã lưu từ trước.
      '${enc(screenTimeScore)}||${enc(environmentScore)}|${enc(eyeBreaksScore)}|${enc(sleepScore)}',
    );
  }

  Future<({
        double? screenTimeScore,
        double? environmentScore,
        double? eyeBreaksScore,
        double? sleepScore,
      })?> loadDailyFactorScores(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kDailyFactorsPrefix${date.toIso8601String().substring(0, 10)}';
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 5) return null;
    double? dec(String s) => s.isEmpty ? null : double.tryParse(s);
    return (
      screenTimeScore: dec(parts[0]),
      // parts[1] = ô "distance" cũ — cố tình bỏ qua, không đọc lại.
      environmentScore: dec(parts[2]),
      eyeBreaksScore: dec(parts[3]),
      sleepScore: dec(parts[4]),
    );
  }

  // Trả về danh sách 7 ngày của TUẦN HIỆN TẠI (Thứ 2 -> Chủ nhật). Với các
  // ngày đã qua/hôm nay: snapshot thật nếu có, null nếu không mở app hôm đó.
  // Với các ngày CHƯA TỚI: luôn null (chưa xảy ra thì không thể có dữ liệu).
  Future<List<({int score, double screenHours, double sleepHours})?>> loadCurrentWeekSnapshots() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final result = <({int score, double screenHours, double sleepHours})?>[];
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (day.isAfter(today)) {
        result.add(null);
      } else {
        result.add(await loadDailySnapshot(day));
      }
    }
    return result;
  }

  // Trả về dữ liệu THÁNG HIỆN TẠI, gộp theo tuần (W1..W7, tối đa 7 tuần cho
  // các tháng có 5-6 tuần lịch) để vẽ biểu đồ Monthly bằng dữ liệu thật thay
  // vì số mẫu cố định. Mỗi phần tử là trung bình các ngày có snapshot trong
  // tuần đó; null nếu tuần đó chưa có ngày nào có dữ liệu (chưa tới hoặc
  // người dùng chưa mở app ngày nào trong tuần đó).
  Future<List<({int score, double screenHours, double sleepHours})?>>
      loadCurrentMonthWeeklySnapshots() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // Chỉ số tuần trong tháng: gộp theo cụm 7 ngày kể từ ngày 1, không phải
    // theo tuần lịch Thứ2-CN, để mọi tháng đều chia gọn thành tối đa 7 cụm.
    final buckets = List.generate(
      7,
      (_) => <({int score, double screenHours, double sleepHours})>[],
    );
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(now.year, now.month, d);
      if (day.isAfter(today)) break;
      final snapshot = await loadDailySnapshot(day);
      if (snapshot != null) {
        final weekIndex = ((d - 1) ~/ 7).clamp(0, 6);
        buckets[weekIndex].add(snapshot);
      }
    }

    final result = <({int score, double screenHours, double sleepHours})?>[];

    for (final bucket in buckets) {
      if (bucket.isEmpty) {
        result.add(null);
        continue;
      }

      final avgScore =
          bucket.map((s) => s.score).reduce((a, b) => a + b) / bucket.length;

      final avgScreen =
          bucket.map((s) => s.screenHours).reduce((a, b) => a + b) / bucket.length;

      final avgSleep =
          bucket.map((s) => s.sleepHours).reduce((a, b) => a + b) / bucket.length;

      result.add((
        score: avgScore.round(),
        screenHours: avgScreen,
        sleepHours: avgSleep,
      ));
    }

    return result;
  }
  // BUG ĐÃ SỬA (streak không bao giờ tăng): ngưỡng cũ là 60, nhưng yếu tố
  // "Nghỉ mắt" trong điểm tổng LUÔN được tính vào trung bình (không bị loại
  // trừ như các yếu tố thiếu dữ liệu khác) và bắt đầu từ 0% cho tới khi
  // người dùng thực sự hoàn thành đủ số lần nghỉ mắt trong ngày (mặc định
  // mục tiêu 12 lần/ngày) — chỉ mở app xem qua, dù 3 yếu tố còn lại đều tốt,
  // trung bình 4 yếu tố vẫn khó vượt 60 vì bị yếu tố này kéo xuống ngay từ
  // đầu ngày. Hạ ngưỡng xuống 50 để streak vẫn có ý nghĩa (đòi hỏi thói quen
  // tốt thật sự) nhưng không yêu cầu gần như hoàn hảo cả 4 yếu tố mới đạt.
  static const int _kStreakScoreThreshold = 50;

  // ---------------- Điểm danh đơn giản: chỉ cần mở app hôm đó ----------------
  // THÊM MỚI: ngoài điều kiện điểm sức khỏe mắt tốt, một ngày CŨNG được tính
  // vào chuỗi nếu người dùng ĐƠN GIẢN LÀ CÓ MỞ APP hôm đó — giống kiểu
  // "điểm danh" hằng ngày của các app thói quen phổ biến, để streak không bị
  // quá khắt khe/dễ nản với người mới dùng hoặc những ngày bận không kịp
  // hoàn thành đủ thói quen. Chỉ cần đúng 1 lần mở app/ngày là đủ, gọi hàm
  // này mỗi lần HabitProvider làm mới dữ liệu (xem refreshHabitsFromDevice).
  static const _kCheckInPrefix = 'daily_checkin_';

  Future<void> recordAppOpenCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setBool('$_kCheckInPrefix$todayKey', true);
  }

  Future<bool> _hasCheckIn(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kCheckInPrefix${date.toIso8601String().substring(0, 10)}';
    return prefs.getBool(key) ?? false;
  }

  // Tính chuỗi ngày liên tiếp (streak) thật: đếm ngược từ hôm nay, mỗi ngày
  // được tính vào chuỗi nếu THỎA MÃN ÍT NHẤT MỘT trong 2 điều kiện — điểm
  // sức khỏe mắt hôm đó đạt ngưỡng, HOẶC người dùng đã mở app hôm đó (điểm
  // danh) — dừng lại ở ngày đầu tiên không thỏa mãn cả 2.
  Future<int> calculateStreakDays() async {
    var streak = 0;
    var day = DateTime.now();
    for (var i = 0; i < 365; i++) {
      final dayOnly = DateTime(day.year, day.month, day.day);
      final snapshot = await loadDailySnapshot(dayOnly);
      final goodScore = snapshot != null && snapshot.score >= _kStreakScoreThreshold;
      final checkedIn = await _hasCheckIn(dayOnly);
      if (!goodScore && !checkedIn) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ---------------- Cảnh báo dùng điện thoại trong bóng tối ----------------
  // Dùng lại cảm biến ánh sáng (lux) — lắng nghe liên tục trong khi app ở
  // foreground: nếu lux ở mức "tối" (giống phòng tắt đèn/ban đêm không đèn)
  // trong một khoảng thời gian liên tục đủ dài, coi như người dùng đang nhìn
  // màn hình trong bóng tối và gọi callback `onDarkWarning` MỘT LẦN cho tới
  // khi ánh sáng trở lại bình thường (tránh spam thông báo liên tục).
  //
  // Đây là bản REAL-TIME, chỉ chạy khi app còn tiến trình (mở hoặc vừa
  // chuyển nền). Còn khi app đã bị đóng hẳn, xem thêm bản chạy nền định kỳ
  // ~15 phút ở lib/services/dark_room_background_service.dart (dùng
  // WorkManager, tách biệt hoàn toàn — 2 bản có thể hiếm khi cùng bắn thông
  // báo gần nhau nếu trùng thời điểm, coi là đánh đổi chấp nhận được so với
  // việc phải đồng bộ giữa 2 isolate độc lập).
  StreamSubscription<int>? _darkRoomLightSub;
  DateTime? _darkSince;
  bool _darkWarningFired = false;

  static const _kDarkLuxThreshold = 10; // lux dưới mức này coi là "tối"
  static const _kDarkTriggerDuration = Duration(minutes: 2);

  void startDarkRoomMonitoring(Future<void> Function() onDarkWarning) {
    stopDarkRoomMonitoring();
    if (!Platform.isAndroid) return; // light sensor not available on iOS
    try {
      _darkRoomLightSub = Light().lightSensorStream.listen(
        (lux) {
          if (lux < _kDarkLuxThreshold) {
            _darkSince ??= DateTime.now();
            final elapsed = DateTime.now().difference(_darkSince!);
            if (!_darkWarningFired && elapsed >= _kDarkTriggerDuration) {
              _darkWarningFired = true;
              onDarkWarning();
            }
          } else {
            // Đủ sáng trở lại -> reset để lần "tối" tiếp theo lại được cảnh báo.
            _darkSince = null;
            _darkWarningFired = false;
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Thiết bị không có cảm biến ánh sáng — bỏ qua tính năng này.
    }
  }

  void stopDarkRoomMonitoring() {
    _darkRoomLightSub?.cancel();
    _darkRoomLightSub = null;
    _darkSince = null;
    _darkWarningFired = false;
  }

  void dispose() {
    _accelSub?.cancel();
    _outdoorSampleTimer?.cancel();
    _darkRoomLightSub?.cancel();
    _environmentSampleTimer?.cancel();
  }

  // ---------------- Môi trường (lux): cho Eye Health Score 2.0 ----------------
  // Lấy mẫu lux ánh sáng môi trường định kỳ, dùng cho yếu tố "🌙 Môi trường"
  // trong breakdown điểm sức khỏe mắt.
  //
  // ĐÃ BỎ đo "📏 Khoảng cách" (dùng camera trước) — tính năng này từng ở
  // trạng thái thử nghiệm, độ chính xác chưa đủ tin cậy trên nhiều dòng máy
  // và không mang lại giá trị tương xứng với chi phí pin/quyền riêng tư
  // (phải mở camera định kỳ). Đã gỡ bỏ hoàn toàn khỏi app.
  // CÔNG THỨC MỚI (theo yêu cầu): mỗi ngày mới điểm Môi trường BẮT ĐẦU Ở
  // 100%. Mỗi lần dùng điện thoại, app lấy mẫu lux định kỳ; thời gian dùng
  // máy ở nơi thiếu sáng (lux < _kGoodLuxThreshold) được cộng vào "dim", mọi
  // thời gian lấy mẫu cộng vào "total". Điểm = 100% - (dim / total).
  // VD: dùng máy 5 giờ, trong đó 2 giờ thiếu sáng = 40% -> còn 60%.
  // Trước đây điểm = % số lần đo "đủ sáng" và là 0% khi chưa có mẫu đủ sáng
  // nào (xem hình 1: Môi trường 0%), không đúng ý nghĩa "trừ dần từ 100%".
  static const _kEnvironmentSampleInterval = Duration(minutes: 1);
  // Dart Timer bị Android tạm dừng khi app xuống nền; kẹp trọng số mỗi mẫu để
  // khoảng im lặng dài (app bị đóng băng) không bị tính là thời gian dùng máy.
  static const _kMaxSampleWeightSeconds = 120;
  // Lux dưới mức này coi là "thiếu sáng để nhìn màn hình" (khác ngưỡng
  // _kDarkLuxThreshold=10 dùng cho CẢNH BÁO phòng tối).
  static const _kGoodLuxThreshold = 50;

  static const _kEnvDimSecondsKey = 'env_dim_seconds';
  static const _kEnvTotalSecondsKey = 'env_total_seconds';
  static const _kEnvDateKey = 'env_sample_date';

  Timer? _environmentSampleTimer;
  DateTime? _lastEnvSampleAt;

  void startEnvironmentMonitoring() {
    _environmentSampleTimer?.cancel();
    _sampleEnvironmentOnce(); // lấy mẫu ngay, không chờ hết chu kỳ đầu.
    _environmentSampleTimer = Timer.periodic(_kEnvironmentSampleInterval, (_) {
      _sampleEnvironmentOnce();
    });
  }

  void stopEnvironmentMonitoring() {
    _environmentSampleTimer?.cancel();
    _environmentSampleTimer = null;
  }

  Future<void> _sampleEnvironmentOnce() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetEnvironmentCountersIfNewDay(prefs);

    final now = DateTime.now();
    final weight = _lastEnvSampleAt == null
        ? _kEnvironmentSampleInterval.inSeconds
        : now.difference(_lastEnvSampleAt!).inSeconds.clamp(1, _kMaxSampleWeightSeconds);
    _lastEnvSampleAt = now;

    final lux = await _readAmbientLuxOnce();
    if (lux == null) return; // không đọc được cảm biến -> bỏ mẫu, không phạt.

    final total = (prefs.getInt(_kEnvTotalSecondsKey) ?? 0) + weight;
    await prefs.setInt(_kEnvTotalSecondsKey, total);
    if (lux < _kGoodLuxThreshold) {
      final dim = (prefs.getInt(_kEnvDimSecondsKey) ?? 0) + weight;
      await prefs.setInt(_kEnvDimSecondsKey, dim);
    }
  }

  Future<void> _resetEnvironmentCountersIfNewDay(SharedPreferences prefs) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = prefs.getString(_kEnvDateKey);
    if (storedDate != today) {
      await prefs.setString(_kEnvDateKey, today);
      await prefs.setInt(_kEnvDimSecondsKey, 0);
      await prefs.setInt(_kEnvTotalSecondsKey, 0);
    }
  }

  // Luôn trả về số (không còn null): chưa có mẫu nào hôm nay = 100%.
  Future<double?> getEnvironmentScoreToday() async {
    final prefs = await SharedPreferences.getInstance();
    await _resetEnvironmentCountersIfNewDay(prefs);
    final total = prefs.getInt(_kEnvTotalSecondsKey) ?? 0;
    if (total <= 0) return 100;
    final dim = prefs.getInt(_kEnvDimSecondsKey) ?? 0;
    return (100 - (dim / total) * 100).clamp(0, 100).toDouble();
  }

  // ---------------- AI Auto Break: hôm qua có thiếu mục tiêu nghỉ mắt? ----------------
  // Trả về số lần nghỉ mắt HÔM QUA nếu CHƯA đạt target, null nếu đã đạt hoặc
  // không có dữ liệu hôm qua. Đọc THẲNG giá trị thô đã lưu (không gọi
  // getEyeBreaksToday(), vì hàm đó tự RESET về 0 khi phát hiện sang ngày
  // mới — sẽ mất luôn con số hôm qua cần so sánh).
  Future<int?> checkYesterdayBreaksShortfall(int target) async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_kBreaksDateKey);
    if (storedDate == null) return null;
    final yesterdayKey =
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    if (storedDate != yesterdayKey) return null;
    final count = prefs.getInt(_kBreaksCountKey) ?? 0;
    return count < target ? count : null;
  }
}