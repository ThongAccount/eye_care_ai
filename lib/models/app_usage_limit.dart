/// Giới hạn sử dụng hằng ngày cho app-lock (Phase 1).
///
/// Không dùng freezed/build_runner (production build không chạy codegen —
/// lý do scaffold cũ bị xóa ở f44a978). Đây là class Dart thuần, JSON
/// round-trip tay ra SharedPreferences.
class AppUsageLimit {
  const AppUsageLimit({
    required this.enabled,
    required this.dailyLimitMinutes,
    this.lastResetDate,
    this.lastExtraTimeGrant,
  });

  final bool enabled;
  final int dailyLimitMinutes;

  /// Ngày (yyyyMMdd) của lần reset gần nhất — so với hôm nay để biết có cần
  /// reset ngưỡng “đã cấp thêm giờ” hay không. Lưu trữ dạng int để tránh
  /// phụ thuộc intl và parse ISO.
  final int? lastResetDate;

  /// Mốc thời gian (epoch millis) của lần bấm "+5 phút" gần nhất — chặn bấm
  /// liên tục (cooldown 1 lần cấp thêm mỗi lần khóa).
  final DateTime? lastExtraTimeGrant;

  static int dateCode(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  AppUsageLimit copyWith({
    bool? enabled,
    int? dailyLimitMinutes,
    int? lastResetDate,
    DateTime? lastExtraTimeGrant,
  }) {
    return AppUsageLimit(
      enabled: enabled ?? this.enabled,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      lastExtraTimeGrant: lastExtraTimeGrant ?? this.lastExtraTimeGrant,
    );
  }

  const AppUsageLimit.disabled()
      : enabled = false,
        dailyLimitMinutes = 60,
        lastResetDate = null,
        lastExtraTimeGrant = null;

  /// Đã được cấp thêm giờ trong lần khóa HIỆN TẠI chưa.
  bool get hasExtraTimeInCurrentLock =>
      lastExtraTimeGrant != null &&
      lastResetDate != null &&
      dateCode(lastExtraTimeGrant!) == lastResetDate &&
      DateTime.now().difference(lastExtraTimeGrant!) < const Duration(minutes: 5);

  factory AppUsageLimit.fromJson(Map<String, dynamic> json) {
    return AppUsageLimit(
      enabled: json['enabled'] as bool? ?? false,
      dailyLimitMinutes: json['dailyLimitMinutes'] as int? ?? 60,
      lastResetDate: json['lastResetDate'] as int?,
      lastExtraTimeGrant: json['lastExtraTimeGrant'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastExtraTimeGrant'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'dailyLimitMinutes': dailyLimitMinutes,
      'lastResetDate': lastResetDate,
      if (lastExtraTimeGrant != null)
        'lastExtraTimeGrant': lastExtraTimeGrant!.millisecondsSinceEpoch,
    };
  }

  /// Nếu hôm nay khác ngày reset gần nhất → coi như ngày mới: reset mốc
  /// “đã cấp thêm giờ” (consumed minutes tự về 0 vì breakdown là theo ngày
  /// của DeviceDataService).
  AppUsageLimit resetIfNewDay(DateTime now) {
    final today = dateCode(now);
    if (lastResetDate == today) return this;
    return AppUsageLimit(
      enabled: enabled,
      dailyLimitMinutes: dailyLimitMinutes,
      lastResetDate: today,
      lastExtraTimeGrant: null,
    );
  }

  /// Số phút còn lại: limit trừ minutes đã dùng hôm nay (dừng ở 0).
  int remainingMinutes(int consumedMinutes, DateTime now) {
    if (!enabled) return dailyLimitMinutes;
    final remaining = dailyLimitMinutes - consumedMinutes;
    return remaining < 0 ? 0 : remaining;
  }

  /// Bấm "+5 phút": được phép nếu chưa cấp thêm trong lần khóa này.
  AppUsageLimit grantExtraTime(DateTime now) {
    return copyWith(
      lastResetDate: dateCode(now),
      lastExtraTimeGrant: now,
    );
  }
}