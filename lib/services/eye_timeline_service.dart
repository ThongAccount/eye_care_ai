import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Các loại sự kiện hiện trên "Dòng thời gian mắt". Chỉ lưu LOẠI + giá trị số
/// (nếu có) — câu chữ hiển thị được dựng lúc vẽ UI, nên đổi ngôn ngữ vẫn đúng
/// với cả sự kiện cũ.
enum TimelineEventType {
  brightEnvironment, // chuyển sang môi trường đủ sáng
  dimEnvironment, // chuyển sang môi trường thiếu sáng
  screenSession, // 1 phiên dùng màn hình liên tục (value = số phút)
  eyeBreak, // hoàn thành 1 lần nghỉ mắt
  darkRoom, // dùng máy trong phòng quá tối
  brightnessAdjusted, // độ sáng màn hình được chỉnh
}

class TimelineEvent {
  const TimelineEvent({required this.time, required this.type, this.value});

  final DateTime time;
  final TimelineEventType type;
  final int? value;

  Map<String, dynamic> toJson() => {
        't': time.millisecondsSinceEpoch,
        'k': type.name,
        if (value != null) 'v': value,
      };

  static TimelineEvent? fromJson(Map<String, dynamic> json) {
    final millis = json['t'];
    final kind = json['k'];
    if (millis is! int || kind is! String) return null;
    final type = TimelineEventType.values.where((e) => e.name == kind);
    if (type.isEmpty) return null;
    return TimelineEvent(
      time: DateTime.fromMillisecondsSinceEpoch(millis),
      type: type.first,
      value: json['v'] is int ? json['v'] as int : null,
    );
  }
}

/// Ghi lại các sự kiện liên quan tới mắt theo từng ngày để biến dữ liệu cảm
/// biến thành thứ người dùng đọc được (xem EyeTimelineScreen).
///
/// Lưu cục bộ trong SharedPreferences, mỗi ngày 1 key `timeline_YYYY-MM-DD`,
/// tối đa [_maxPerDay] sự kiện/ngày và chỉ giữ [_keepDays] ngày gần nhất.
class EyeTimelineService {
  EyeTimelineService._();
  static final EyeTimelineService instance = EyeTimelineService._();

  static const _prefix = 'timeline_';
  static const _maxPerDay = 200;
  static const _keepDays = 7;

  /// Tăng mỗi khi có sự kiện mới — màn hình timeline lắng nghe để tự cập nhật.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  // Nhớ thời điểm ghi gần nhất của từng loại ngay trong RAM để chặn spam
  // (vd tự chỉnh độ sáng liên tục) mà không phải đọc SharedPreferences.
  final Map<TimelineEventType, DateTime> _lastLoggedAt = {};
  // Xếp hàng các lần ghi để không bao giờ đọc-sửa-ghi chồng lên nhau.
  Future<void> _queue = Future.value();

  String _key(DateTime d) => '$_prefix${d.toIso8601String().substring(0, 10)}';

  /// Ghi 1 sự kiện. [minGap]: nếu cùng loại vừa được ghi trong khoảng này thì
  /// bỏ qua (chống spam).
  Future<void> log(
    TimelineEventType type, {
    int? value,
    Duration? minGap,
    DateTime? at,
  }) {
    final time = at ?? DateTime.now();
    if (minGap != null) {
      final last = _lastLoggedAt[type];
      if (last != null && time.difference(last) < minGap) return Future.value();
    }
    _lastLoggedAt[type] = time;
    _queue = _queue.then((_) => _write(TimelineEvent(time: time, type: type, value: value)));
    return _queue;
  }

  Future<void> _write(TimelineEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(event.time);
      final list = _decode(prefs.getString(key));
      final isFirstOfDay = list.isEmpty;
      list.add(event);
      if (list.length > _maxPerDay) list.removeRange(0, list.length - _maxPerDay);
      await prefs.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));
      if (isFirstOfDay) await _pruneOld(prefs);
      revision.value++;
    } catch (_) {
      // Timeline chỉ là phần phụ — không bao giờ để lỗi ghi log ảnh hưởng app.
    }
  }

  Future<void> _pruneOld(SharedPreferences prefs) async {
    final cutoff = DateTime.now().subtract(const Duration(days: _keepDays));
    final cutoffKey = _key(cutoff);
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      if (key.compareTo(cutoffKey) < 0) await prefs.remove(key);
    }
  }

  /// Sự kiện của 1 ngày, sắp theo thời gian tăng dần.
  Future<List<TimelineEvent>> loadDay(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(_key(day)));
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  List<TimelineEvent> _decode(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((m) => TimelineEvent.fromJson(Map<String, dynamic>.from(m)))
          .whereType<TimelineEvent>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}