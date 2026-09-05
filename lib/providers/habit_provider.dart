import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/device_data_service.dart';
import '../services/notification_service.dart';

class HabitData {
  HabitData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unit,
    required this.target,
    this.current = 0,
    required this.color,
    this.isLive = false,
    this.isComingSoon = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String unit;
  double target;
  double current;
  final int color;
  bool isLive;
  // Thói quen chưa thật sự đo được (chưa có tính năng đứng sau) — hiển thị
  // mờ đi trên UI và khoá tương tác, tránh người dùng tưởng nhầm là app lỗi
  // khi số liệu luôn đứng yên ở 0.
  final bool isComingSoon;

  double get progress {
    if (target == 0) return 0;
    // "phone" (dùng ít hơn tốt hơn) vẫn dùng chung công thức clamp 0-1 như
    // các habit khác — current vượt target thì thanh GIỮ NGUYÊN ĐẦY (100%)
    // thay vì vơi dần về 0, để không mất thông tin trực quan; phần "vượt
    // bao nhiêu" được thể hiện qua MÀU của thanh (xem _HabitCard trong
    // habits_screen.dart: đổi sang màu đỏ cảnh báo khi current > target),
    // không phải qua độ dài thanh.
    return (current / target).clamp(0.0, 1.0);
  }
}

/// Mức cảnh báo hiển thị cạnh tiêu đề mỗi thẻ habit — thay cho chấm tròn
/// trung tính cũ (chỉ báo "có dữ liệu hay không", không nói lên tốt/xấu).
/// none = chưa có dữ liệu/habit chưa hỗ trợ (giữ chấm tròn xám cũ).
enum HabitAlertLevel { none, warning, good }

class HabitProvider extends ChangeNotifier {
  static const _kHasCustomTargetsKey = 'pref_has_custom_habit_targets';
  static const _kHabitTargetPrefix = 'pref_habit_target_';
  static const _kManualSleepHoursKey = 'pref_manual_sleep_hours';
  static const _kManualSleepDateKey = 'pref_manual_sleep_date';

  HabitProvider() {
    ready = _loadSavedPreferences();
  }

  // Awaiting này đảm bảo dữ liệu target đã lưu (nếu có) được nạp XONG trước
  // khi bất kỳ màn hình nào (đặc biệt là khảo sát bắt buộc lần đầu) đọc hoặc
  // ghi vào `habits` — tránh trường hợp việc nạp dữ liệu bất đồng bộ hoàn tất
  // SAU khi khảo sát đã áp dụng kết quả mới, vô tình ghi đè ngược lại giá trị
  // cũ/mặc định (đây là nguyên nhân gây ra lỗi "Outdoor Time luôn hiện 90
  // phút" dù người dùng chọn khác trong khảo sát).
  late final Future<void> ready;

  final List<HabitData> habits = [
    HabitData(
      id: 'reading',
      title: 'Eye Test Count',
      subtitle: 'Counted over the last 7 days',
      icon: '🧪',
      unit: 'times',
      target: 1,
      color: 0xFF3B82F6,
    ),
    HabitData(
      id: 'phone',
      title: 'Phone Usage',
      subtitle: 'Screen-on time (OS)',
      icon: '📱',
      unit: 'hrs',
      target: 6,
      color: 0xFF8B5CF6,
    ),
    HabitData(
      id: 'sleep',
      title: 'Sleep',
      // LƯU Ý: field này không thực sự hiển thị trên UI — habits_screen.dart
      // dùng strings.habitSubtitle(habit.id) (app_strings.dart) để có bản
      // dịch Việt/Anh đầy đủ. Giữ chuỗi này khớp nghĩa để không gây hiểu
      // lầm nếu sau này có chỗ khác đọc trực tiếp field này.
      subtitle: 'Estimated from usage times, or tap to enter',
      icon: '😴',
      unit: 'hrs',
      target: 9,
      color: 0xFF6366F1,
    ),
    HabitData(
      id: 'outdoor',
      title: 'Outdoor Time',
      subtitle: 'GPS location',
      icon: '🌿',
      unit: 'min',
      target: 90,
      color: 0xFF14B8A6,
    ),
    HabitData(
      id: 'breaks',
      title: 'Eye Breaks',
      subtitle: 'Front camera gaze detection',
      icon: '👁️',
      unit: 'breaks',
      target: 12,
      color: 0xFFF97316,
    ),
  ];

  bool isRefreshingHabits = false;
  DateTime? habitsLastUpdated;
  int habitsCompletionPercent = 0;
  int eyeBreaksTakenToday = 0;
  // Tổng số lần nghỉ mắt CỘNG DỒN TOÀN BỘ THỜI GIAN (không reset theo
  // ngày) — dùng để tính thật tiến độ các thẻ ở màn hình Thành tựu, xem
  // _refreshTotalEyeBreaks() bên dưới.
  int totalEyeBreaksAllTime = 0;
  int statsTabIndex = 0;
  int statsMetricIndex = 0;
  int streakDays = 0;
  bool hasCustomHabitTargets = false;
  bool surveyCompleted = false;

  // Danh sách dùng chung cho Trang chủ + Thống kê — CHỈ fetch 1 lần mỗi khi
  // refreshHabitsFromDevice() chạy, để 2 màn hình luôn hiện CÙNG MỘT con số
  // (trước đây Thống kê tự fetch riêng, dễ lệch với Trang chủ do khác thời
  // điểm truy vấn).
  List<AppUsageBreakdownEntry> appUsageBreakdown = [];

  int get eyeHealthScore => habitsCompletionPercent;
  double get screenTimeHours => totalScreenTimeHoursToday;

  // ---------------- Eye Health Score 2.0: breakdown 5 yếu tố ----------------
  // Mỗi yếu tố là % 0-100 độc lập (null = CHƯA có đủ dữ liệu để tính, khác
  // với 0% = có dữ liệu nhưng đang xấu) — xem _updateHabitsCompletion() bên
  // dưới để biết công thức từng yếu tố. `habitsCompletionPercent` (điểm
  // tổng) = trung bình cộng của các yếu tố ĐANG CÓ dữ liệu (bỏ qua null,
  // không tính là 0 — tránh phạt oan người dùng chưa cấp đủ quyền/chưa đủ
  // mẫu, ví dụ mới cài app được vài phút).
  double? screenTimeScore;
  double? distanceScore;
  double? environmentScore;
  double? eyeBreaksScore;
  double? sleepScore;
  // Chênh lệch điểm tổng so với snapshot NGÀY HÔM QUA (dương = tăng, âm =
  // giảm, null = chưa có snapshot hôm qua để so sánh — ví dụ ngày đầu dùng
  // app). Cập nhật trong refreshHabitsFromDevice() sau khi có điểm hôm nay.
  int? eyeHealthScoreDelta;

  // Tổng thời gian dùng điện thoại THẬT của hôm nay, lấy TRỰC TIẾP từ tổng
  // appUsageBreakdown (KHÔNG qua clamp) — dùng riêng cho việc HIỂN THỊ (thẻ
  // Trang chủ, biểu đồ Thống kê) để luôn khớp 100% với thẻ "Sử dụng theo ứng
  // dụng" (cũng cộng từ đúng list này). `habits[phone].current` vẫn bị clamp
  // về tối đa target*2 (xem _applyHabitValue) — clamp đó CHỈ nên ảnh hưởng
  // thanh tiến độ/vòng tròn hoàn thành habit (progress bar không thể vẽ quá
  // 100%*2 một cách hợp lý), không được lẫn vào số giờ hiển thị thật. Trước
  // đây `screenTimeHours` đọc thẳng `current` đã bị clamp, nên khi người
  // dùng tự đặt mục tiêu thấp (ví dụ 3h) mà dùng máy nhiều hơn target*2, số
  // hiển thị bị "ăn bớt" so với tổng thật ở thẻ Sử dụng theo ứng dụng.
  double totalScreenTimeHoursToday = 0;
  double get outdoorHours => habits.firstWhere((h) => h.id == 'outdoor').current / 60;
  int get breakCount => habits.firstWhere((h) => h.id == 'breaks').current.round();

  /// Nạp lại từ SharedPreferences — gọi sau khi CloudBackupService ghi dữ
  /// liệu khôi phục vào local storage, để provider (đang sống suốt vòng đời
  /// app, không bị tạo lại khi đăng nhập) cập nhật đúng giá trị mới.
  Future<void> reload() => _loadSavedPreferences();

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    hasCustomHabitTargets = prefs.getBool(_kHasCustomTargetsKey) ?? hasCustomHabitTargets;

    for (final habit in habits) {
      final key = '$_kHabitTargetPrefix${habit.id}';
      if (prefs.containsKey(key)) {
        habit.target = prefs.getDouble(key) ?? habit.target;
      }
    }

    notifyListeners();
  }

  Future<void> _saveHabitTarget(String habitId, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_habitTargetKey(habitId), value);
  }

  String _habitTargetKey(String habitId) => '$_kHabitTargetPrefix$habitId';

  Future<void> _saveHasCustomHabitTargets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasCustomTargetsKey, true);
  }

  void startHabitTracking() {
    final service = DeviceDataService.instance;
    // Không còn cần theo dõi "Reading Time" bằng cảm biến nữa — thẻ này đã
    // đổi thành "Eye Test Count" (đang phát triển, xem HabitData(id: 'reading')
    // ở trên), không có nguồn dữ liệu thật để bật lên.
    service.startOutdoorTracking();
    // Lấy mẫu môi trường (lux) + khoảng cách mắt-màn hình định kỳ, dùng cho
    // 2 yếu tố "🌙 Môi trường" / "📏 Khoảng cách" trong Eye Health Score 2.0
    // (xem DeviceDataService.startEnvironmentMonitoring để biết các ràng
    // buộc an toàn riêng tư/pin — không tự xin quyền camera, không giữ
    // camera mở liên tục).
    service.startEnvironmentMonitoring();
    // Cảnh báo dùng điện thoại trong bóng tối: gửi thông báo hệ thống khi
    // môi trường xung quanh tối liên tục quá lâu trong lúc app đang mở.
    service.startDarkRoomMonitoring(() async {
      await NotificationService.instance.showInstantNotification(
        title: '🌙 Bạn đang dùng điện thoại trong bóng tối',
        body: 'Ánh sáng yếu khiến mắt phải điều tiết nhiều hơn, dễ gây mỏi mắt. '
            'Hãy bật đèn hoặc giảm độ sáng màn hình cho phù hợp.',
      );
    });
  }

  Future<void> refreshHabitsFromDevice() async {
    isRefreshingHabits = true;
    notifyListeners();

    final service = DeviceDataService.instance;
    // Mỗi nguồn dữ liệu có timeout RIÊNG (không dùng chung Future.wait không
    // giới hạn thời gian) — nếu một nguồn bị treo (ví dụ hộp thoại xin quyền
    // sức khỏe/GPS chưa được người dùng phản hồi), nó sẽ tự trả về null sau
    // vài giây thay vì làm toàn bộ refresh không bao giờ hoàn tất. Đây chính
    // là lý do trước đây trang chủ đôi khi mãi hiện 0 cho tới khi người dùng
    // chuyển sang tab khác rồi quay lại (lúc đó refresh mới có cơ hội chạy
    // lại và may mắn không bị treo).
    //
    // QUAN TRỌNG: getAppUsageBreakdownToday() chỉ gọi Ở ĐÂY, MỘT LẦN DUY
    // NHẤT — Trang chủ và Thống kê đều đọc lại cùng kết quả này (appUsageBreakdown)
    // thay vì mỗi màn hình tự query native riêng, vốn là lý do 2 nơi từng
    // hiện số giờ khác nhau (query ở 2 thời điểm khác nhau).
    final results = await Future.wait([
      service.getAppUsageBreakdownToday().timeout(const Duration(seconds: 6), onTimeout: () => <AppUsageBreakdownEntry>[]),
      service.getSleepHours().timeout(const Duration(seconds: 6), onTimeout: () => null),
      service.getOutdoorMinutesToday().timeout(const Duration(seconds: 6), onTimeout: () => 0),
      service.getEyeBreaksToday().timeout(const Duration(seconds: 6), onTimeout: () => 0),
      _getEyeTestCountLast7Days().timeout(const Duration(seconds: 6), onTimeout: () => 0),
    ]);

    appUsageBreakdown = results[0] as List<AppUsageBreakdownEntry>;
    final totalUsageSeconds = appUsageBreakdown.fold<int>(0, (sum, e) => sum + e.usage.inSeconds);
    final phoneHours = appUsageBreakdown.isEmpty ? null : totalUsageSeconds / 3600.0;
    // Cập nhật biến hiển thị KHÔNG bị clamp — luôn = đúng tổng của
    // appUsageBreakdown, cùng 1 con số với thẻ "Sử dụng theo ứng dụng".
    totalScreenTimeHoursToday = phoneHours ?? 0;

    // 'reading' giờ là "Eye Test Count" — đếm số lần người dùng đã hoàn
    // thành bài Kiểm tra mắt (EyeTestScreen) trong 7 ngày gần nhất, lấy từ
    // lịch sử lưu ở SharedPreferences key 'eye_test_history'.
    final eyeTestCount = results[4] as int;
    _applyHabitValue('reading', eyeTestCount.toDouble());
    _applyHabitValue('phone', phoneHours);
    // Ước lượng tự động (suy luận từ giờ dùng máy tối qua/sáng nay, xem
    // UsageStatsHandler.getSleepEstimate() phía native) có thể null nếu
    // người dùng không chạm máy đủ rõ ràng ở 2 đầu mút đêm-sáng. Dùng số giờ
    // ngủ nhập tay hôm nay (nếu có, xem _showManualSleepSheet ở
    // habits_screen.dart — bấm vào thẻ Giấc ngủ để nhập) làm phương án dự
    // phòng, để habit này luôn dùng được thay vì mãi hiện "Chưa có nguồn dữ
    // liệu".
    double? sleepValue = results[1] as double?;
    sleepValue ??= await _getManualSleepHoursToday();
    _applyHabitValue('sleep', sleepValue);
    _applyHabitValue('outdoor', results[2] as double?);
    final breaks = results[3] as int;
    _applyHabitValue('breaks', breaks.toDouble());
    eyeBreaksTakenToday = breaks;
    totalEyeBreaksAllTime = await service.getTotalEyeBreaksAllTime();

    await _updateHabitsCompletion();
    habitsLastUpdated = DateTime.now();
    isRefreshingHabits = false;

    // Chênh lệch điểm tổng so với hôm qua — đọc TRƯỚC khi ghi đè snapshot
    // hôm nay bên dưới (2 key khác nhau nên thứ tự không ảnh hưởng, nhưng
    // đọc trước cho rõ ý: đang so với NGÀY HÔM QUA, không phải bản ghi vừa
    // lưu). null nếu hôm qua không mở app / chưa có snapshot để so sánh.
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdaySnapshot = await service.loadDailySnapshot(
      DateTime(yesterday.year, yesterday.month, yesterday.day),
    );
    eyeHealthScoreDelta = yesterdaySnapshot == null
        ? null
        : habitsCompletionPercent - yesterdaySnapshot.score;

    // Lưu snapshot thật của hôm nay + tính lại streak thật (thay cho số liệu
    // giả cố định trước đây).
    await service.saveDailySnapshot(
      score: habitsCompletionPercent,
      screenHours: screenTimeHours,
      sleepHours: habits.firstWhere((h) => h.id == 'sleep').current,
    );
    streakDays = await service.calculateStreakDays();

    notifyListeners();
  }

  // Ngưỡng "ngủ quá nhiều" — không có trong yêu cầu gốc con số cụ thể, chọn
  // +25% so với mục tiêu (mục tiêu 8h -> trên 10h coi là ngủ quá nhiều) làm
  // mốc hợp lý về mặt sức khỏe giấc ngủ (ngủ dư quá nhiều cũng không tốt).
  static const _sleepOversleepMultiplier = 1.25;

  /// Mức cảnh báo TỐT/XẤU của 1 habit — hướng "tốt" khác nhau tuỳ habit:
  /// - phone: current > target là XẤU (dùng nhiều), còn lại (ít/đủ) là TỐT.
  /// - sleep: current quá thấp HOẶC quá cao so target đều XẤU, ở giữa là TỐT.
  /// - outdoor / breaks: current < target là XẤU (ít), >= target là TỐT.
  HabitAlertLevel alertLevelFor(HabitData habit) {
    if (!habit.isLive || habit.isComingSoon) return HabitAlertLevel.none;
    switch (habit.id) {
      case 'phone':
        // Dùng đúng số THẬT (totalScreenTimeHoursToday), không dùng
        // habit.current đã bị clamp — để nhất quán với điểm sức khỏe mắt và
        // thẻ "Sử dụng theo ứng dụng" (xem _updateHabitsCompletion bên dưới).
        return totalScreenTimeHoursToday > habit.target ? HabitAlertLevel.warning : HabitAlertLevel.good;
      case 'sleep':
        final oversleepAt = habit.target * _sleepOversleepMultiplier;
        if (habit.current < habit.target || habit.current > oversleepAt) {
          return HabitAlertLevel.warning;
        }
        return HabitAlertLevel.good;
      case 'outdoor':
      case 'breaks':
        return habit.current < habit.target ? HabitAlertLevel.warning : HabitAlertLevel.good;
      default:
        return HabitAlertLevel.none;
    }
  }

  // Đếm số lần hoàn thành bài Kiểm tra mắt (EyeTestScreen) trong 7 ngày gần
  // nhất, đọc từ cùng key 'eye_test_history' mà eye_test_screen.dart dùng để
  // lưu lịch sử (tối đa 10 lần gần nhất, mỗi entry có field 'date' dạng ISO8601).
  Future<int> _getEyeTestCountLast7Days() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('eye_test_history');
    if (raw == null) return 0;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      return list.where((e) {
        final dateStr = e['date'] as String?;
        if (dateStr == null) return false;
        final date = DateTime.tryParse(dateStr);
        return date != null && date.isAfter(cutoff);
      }).length;
    } catch (_) {
      // Dữ liệu cũ hỏng/không đọc được -> coi như chưa có lần test nào.
      return 0;
    }
  }

  void _applyHabitValue(String id, double? value) {
    final habit = habits.firstWhere((h) => h.id == id);
    if (value == null) {
      habit.isLive = false;
      return;
    }
    habit.current = value.clamp(0, habit.target * 2);
    habit.isLive = true;
  }

  // Ngưỡng "ngủ quá nhiều" đã khai báo ở trên (_sleepOversleepMultiplier) —
  // dùng lại cho công thức %sleepScore bên dưới.

  // ---------------- Eye Health Score 2.0: công thức từng yếu tố ----------------
  // Mỗi hàm trả về % 0-100 (không null — null chỉ xảy ra ở TẦNG GỌI khi
  // habit chưa isLive/chưa có mẫu, xem _updateHabitsCompletion).
  //
  // 📱 Thời gian màn hình: dùng CÀNG ÍT so với target càng tốt. Mốc 70% ứng
  // với đúng bằng target (không phải 0%, vì "đạt đúng mục tiêu" vẫn nên được
  // coi là ổn, không phải thất bại) — dưới target thì cộng dần lên tối đa
  // 100% (ở 0 giờ), vượt target thì trừ dần về 0% (ở gấp đôi target).
  double _screenTimeScoreFor(double hours, double target) {
    if (target <= 0) return 100;
    final ratio = hours / target;
    if (ratio <= 1) return (70 + (1 - ratio) * 30).clamp(0, 100).toDouble();
    return (70 - (ratio - 1) * 70).clamp(0, 100).toDouble();
  }

  // 😴 Giấc ngủ: ngủ càng gần/trong khoảng mục tiêu càng tốt — thiếu ngủ
  // (dưới target) trừ điểm tuyến tính, NGỦ TRONG KHOẢNG [target, ngưỡng ngủ
  // quá nhiều] coi là 100% (không phạt ngủ hơn target một chút), vượt hẳn
  // ngưỡng oversleep mới bắt đầu trừ điểm trở lại.
  double _sleepScoreFor(double hours, double target) {
    if (target <= 0) return 100;
    if (hours < target) return ((hours / target) * 100).clamp(0, 100).toDouble();
    final oversleepAt = target * _sleepOversleepMultiplier;
    if (hours <= oversleepAt) return 100;
    final over = hours - oversleepAt;
    return (100 - (over / target) * 100).clamp(0, 100).toDouble();
  }

  // 💧 Nghỉ mắt: càng gần/vượt target càng tốt, đơn giản là % hoàn thành
  // (giống HabitData.progress, nhân rõ ra 0-100 thay vì 0-1).
  double _simpleProgressScoreFor(double current, double target) {
    if (target <= 0) return 0;
    return ((current / target) * 100).clamp(0, 100).toDouble();
  }

  Future<void> _updateHabitsCompletion() async {
    final phone = habits.firstWhere((h) => h.id == 'phone');
    final sleep = habits.firstWhere((h) => h.id == 'sleep');
    final breaks = habits.firstWhere((h) => h.id == 'breaks');

    // 📱 Thời gian màn hình — dùng số giờ THẬT (không bị clamp) để nhất
    // quán với thẻ "Sử dụng theo ứng dụng".
    screenTimeScore = phone.isLive
        ? _screenTimeScoreFor(totalScreenTimeHoursToday, phone.target)
        : null;

    // 😴 Giấc ngủ.
    sleepScore = sleep.isLive ? _sleepScoreFor(sleep.current, sleep.target) : null;

    // 💧 Nghỉ mắt.
    eyeBreaksScore = breaks.isLive
        ? _simpleProgressScoreFor(breaks.current, breaks.target)
        : null;

    // 📏 Khoảng cách + 🌙 Môi trường — lấy từ mẫu lux/khoảng cách thu thập
    // được trong ngày (xem DeviceDataService.startEnvironmentMonitoring).
    // null nếu CHƯA có mẫu nào hôm nay (chưa cấp quyền camera, máy không có
    // cảm biến ánh sáng, hoặc mới mở app chưa tới chu kỳ lấy mẫu đầu).
    final service = DeviceDataService.instance;
    distanceScore = await service.getDistanceScoreToday();
    environmentScore = await service.getEnvironmentScoreToday();

    // Điểm tổng = trung bình cộng CÁC YẾU TỐ ĐANG CÓ DỮ LIỆU — bỏ qua (không
    // tính là 0) những yếu tố null, để không phạt oan người dùng chưa cấp đủ
    // quyền/chưa đủ mẫu trong ngày.
    final available = <double>[
      if (screenTimeScore != null) screenTimeScore!,
      if (distanceScore != null) distanceScore!,
      if (environmentScore != null) environmentScore!,
      if (eyeBreaksScore != null) eyeBreaksScore!,
      if (sleepScore != null) sleepScore!,
    ];
    habitsCompletionPercent = available.isEmpty
        ? 0
        : (available.reduce((a, b) => a + b) / available.length).round();
  }

  Future<double?> _getManualSleepHoursToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_kManualSleepDateKey);
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    if (savedDate != todayKey) return null;
    return prefs.getDouble(_kManualSleepHoursKey);
  }

  // Cho phép người dùng tự nhập số giờ ngủ đêm qua khi Health Connect không
  // có dữ liệu (chưa cài app, hoặc chưa có app nào ghi dữ liệu ngủ vào đó).
  // Giá trị chỉ áp dụng cho hôm nay, ngày mai sẽ tự làm mới.
  Future<void> setManualSleepHours(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    await prefs.setDouble(_kManualSleepHoursKey, hours);
    await prefs.setString(_kManualSleepDateKey, todayKey);

    _applyHabitValue('sleep', hours);
    await _updateHabitsCompletion();
    notifyListeners();
  }

  Future<void> recordEyeBreak() async {
    final total = await DeviceDataService.instance.recordEyeBreak();
    eyeBreaksTakenToday = total;
    totalEyeBreaksAllTime += 1;
    final habit = habits.firstWhere((h) => h.id == 'breaks');
    habit.current = total.toDouble();
    habit.isLive = true;
    await _updateHabitsCompletion();
    notifyListeners();
  }

  void setStatsTabIndex(int index) {
    statsTabIndex = index;
    notifyListeners();
  }

  void setStatsMetricIndex(int index) {
    statsMetricIndex = index;
    notifyListeners();
  }

  Future<void> markSurveyCompleted() async {
    surveyCompleted = true;
    await DeviceDataService.instance.setSurveyCompleted(true);
    notifyListeners();
  }

  void setSurveyCompleted(bool value) {
    surveyCompleted = value;
    notifyListeners();
  }

  Future<void> setHabitTarget(String habitId, double value) async {
    final index = habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    habits[index].target = value;
    await _saveHabitTarget(habitId, value);
    hasCustomHabitTargets = true;
    await _saveHasCustomHabitTargets();
    await _updateHabitsCompletion();
    notifyListeners();
  }

  Future<void> applySurveyTargets(Map<String, double> targets) async {
    for (final entry in targets.entries) {
      final index = habits.indexWhere((h) => h.id == entry.key);
      if (index == -1) continue;
      habits[index].target = entry.value;
      await _saveHabitTarget(habits[index].id, entry.value);
    }
    hasCustomHabitTargets = true;
    await _saveHasCustomHabitTargets();
    await _updateHabitsCompletion();
    notifyListeners();
  }
}