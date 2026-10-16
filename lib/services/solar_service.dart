import 'dart:math' as math;

// Giờ mặt trời mọc/lặn theo thuật toán NOAA (thuần Dart, không cần package,
// không cần mạng) — dùng cho "Chế độ đọc ban đêm": tự chuyển giao diện tối
// theo giờ hoàng hôn / bình minh dựa trên vị trí GPS đã có sẵn.
//
// Công thức: https://gml.noaa.gov/grad/solcalc/solareqns.PDF
// - Góc thiên đỉnh chính thức cho hoàng hôn/bình minh: 90.833°
// - Vùng cực (mặt trời không mọc/lặn trong ngày) -> trả về null, caller tự
//   dùng fallback (mặc định 18:00–06:00 giờ địa phương).
class SolarTimes {
  const SolarTimes({required this.sunrise, required this.sunset});

  /// Giờ mặt trời mọc / lặn theo GIỜ ĐỊA PHƯƠNG của máy.
  final DateTime sunrise;
  final DateTime sunset;
}

class SolarService {
  static const double _zenithDeg = 90.833;

  static double _toRad(double deg) => deg * math.pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / math.pi;

  /// Tính giờ mọc/lặn của [date] (lấy ngày/tháng/năm theo giờ địa phương) tại
  /// tọa độ [lat]/[lon]. Trả về null khi không tính được (vùng cực).
  static SolarTimes? sunTimes({
    required double lat,
    required double lon,
    DateTime? date,
  }) {
    try {
      final now = date ?? DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final jan1 = DateTime(now.year, 1, 1);
      final n = day.difference(jan1).inDays + 1; // day of year
      final lngHour = lon / 15.0;

      final sunriseUtc = _sunEventUtc(
        dayOfYear: n,
        lat: lat,
        lngHour: lngHour,
        isSunrise: true,
      );
      final sunsetUtc = _sunEventUtc(
        dayOfYear: n,
        lat: lat,
        lngHour: lngHour,
        isSunrise: false,
      );
      if (sunriseUtc == null || sunsetUtc == null) return null;

      final offset = now.timeZoneOffset;
      return SolarTimes(
        sunrise: day
            .add(Duration(hours: sunriseUtc.$1, minutes: sunriseUtc.$2))
            .add(offset),
        sunset: day
            .add(Duration(hours: sunsetUtc.$1, minutes: sunsetUtc.$2))
            .add(offset),
      );
    } catch (_) {
      return null;
    }
  }

  /// true khi [now] (giờ địa phương) đang là ban đêm tại [lat]/[lon].
  /// Không tính được (vùng cực / lỗi) -> null để caller dùng fallback.
  static bool? isNight({
    required double lat,
    required double lon,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final times = sunTimes(lat: lat, lon: lon, date: t);
    if (times == null) return null;
    return t.isAfter(times.sunset) || t.isBefore(times.sunrise);
  }

  /// Fallback khi chưa có vị trí GPS: coi 18:00–06:00 là ban đêm.
  static bool isNightFallback(DateTime now) => now.hour >= 18 || now.hour < 6;

  /// Trả về (giờ, phút) UTC của sự kiện, hoặc null khi mặt trời không
  /// mọc/lặn trong ngày (vùng cực).
  static (int, int)? _sunEventUtc({
    required int dayOfYear,
    required double lat,
    required double lngHour,
    required bool isSunrise,
  }) {
    // 1. Giờ dự kiến (số giờ kể từ 0h UTC).
    final t = dayOfYear + ((isSunrise ? 6.0 : 18.0) - lngHour) / 24.0;
    // 2. Vị trí trung bình của mặt trời.
    final m = (0.9856 * t) - 3.289;
    // 3. Kinh độ thật (độ, chuẩn hóa 0–360).
    var l =
        (m +
            (1.916 * math.sin(_toRad(m))) +
            (0.020 * math.sin(_toRad(2 * m))) +
            282.634) %
        360.0;
    if (l < 0) l += 360.0;
    // 4. Xích kinh (giờ).
    var ra = _toDeg(math.atan(0.91764 * math.tan(_toRad(l))));
    ra = (ra % 360.0 + 360.0) % 360.0;
    // 4b. Đưa RA về cùng góc phần tư với L.
    final lQuadrant = (l / 90.0).floor() * 90.0;
    final raQuadrant = (ra / 90.0).floor() * 90.0;
    ra = (ra + (lQuadrant - raQuadrant)) / 15.0;
    // 5. Xích vĩ.
    final sinDec = 0.39782 * math.sin(_toRad(l));
    final cosDec = math.cos(math.asin(sinDec.clamp(-1.0, 1.0)));
    // 6. Góc giờ tại mọc/lặn.
    final cosH =
        (math.cos(_toRad(_zenithDeg)) - (sinDec * math.sin(_toRad(lat)))) /
        (cosDec * math.cos(_toRad(lat)));
    if (cosH > 1 || cosH < -1) return null; // đêm/ban ngày vùng cực
    var h = _toDeg(math.acos(cosH.clamp(-1.0, 1.0)));
    if (isSunrise) h = 360.0 - h;
    h = h / 15.0;
    // 7. Giờ địa phương trung bình -> giờ UTC.
    final localMean = h + ra - (0.06571 * t) - 6.622;
    var utc = (localMean - lngHour) % 24.0;
    if (utc < 0) utc += 24.0;
    final hour = utc.floor();
    final minute = ((utc - hour) * 60.0).round();
    if (minute >= 60) return (hour + 1, 0);
    return (hour, minute);
  }
}
