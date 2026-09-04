import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../services/device_data_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// StatisticsScreen hiển thị biểu đồ và số liệu thống kê sức khỏe mắt.
//
// Đây là nơi người dùng xem các xu hướng theo tuần hoặc theo tháng.
// Cả hai tab Weekly và Monthly đều đọc snapshot NGÀY thật đã lưu qua
// DeviceDataService (xem loadCurrentWeekSnapshots / loadCurrentMonthWeeklySnapshots).
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Danh sách loại số liệu mà người dùng có thể chọn.
  // 0 = Score, 1 = Screen Time, 2 = Sleep.
  static const _metrics = ['Score', 'Screen Time', 'Sleep'];

  // Snapshot thật của 7 ngày trong tuần hiện tại (null = chưa có dữ liệu,
  // bao gồm cả các ngày chưa tới trong tuần).
  List<({int score, double screenHours, double sleepHours})?>? _weekSnapshots;

  // Snapshot thật của tháng hiện tại, gộp theo tuần (xem
  // loadCurrentMonthWeeklySnapshots trong DeviceDataService). null = chưa
  // tải xong; phần tử null bên trong = tuần đó chưa có dữ liệu.
  List<({int score, double screenHours, double sleepHours})?>? _monthSnapshots;

  @override
  void initState() {
    super.initState();
    _loadWeekSnapshots();
    _loadMonthSnapshots();
  }

  Future<void> _loadWeekSnapshots() async {
    final snapshots = await DeviceDataService.instance.loadCurrentWeekSnapshots();
    if (!mounted) return;
    setState(() => _weekSnapshots = snapshots);
  }

  Future<void> _loadMonthSnapshots() async {
    final snapshots = await DeviceDataService.instance.loadCurrentMonthWeeklySnapshots();
    if (!mounted) return;
    setState(() => _monthSnapshots = snapshots);
  }

  // Chọn dữ liệu biểu đồ dựa vào tab đang chọn và loại số liệu.
  // HabitProvider.statsTabIndex xác định Weekly / Monthly.
  // HabitProvider.statsMetricIndex xác định Score / Screen Time / Sleep.
  // Giá trị null trong danh sách nghĩa là "chưa có dữ liệu ngày đó" — UI vẽ
  // đoạn đó như một đoạn CHƯA HOÀN THÀNH thay vì bịa số.
  //
  // QUAN TRỌNG: _weekSnapshots/_monthSnapshots chỉ được tải MỘT LẦN lúc mở
  // màn hình (initState) — nếu chỉ dùng đúng số đó, điểm dữ liệu của HÔM NAY
  // sẽ đứng yên ở đúng giá trị lúc mở trang, trong khi thẻ "Sử dụng theo ứng
  // dụng" (_AppUsageBreakdownCard) bên dưới lại đọc TRỰC TIẾP từ
  // HabitProvider nên vẫn tự cập nhật theo từng lượt refresh 60s — đây
  // chính là lý do "Thời gian màn hình" trên biểu đồ và tổng ở "Sử dụng
  // theo ứng dụng" bị LỆCH NHAU dù cùng 1 nguồn dữ liệu gốc. Ghi đè điểm
  // CUỐI CÙNG (hôm nay / tuần này) bằng giá trị SỐNG từ [state] mỗi lần
  // build lại để 2 nơi luôn khớp nhau tuyệt đối.
  List<double?> _getData(HabitProvider state) {
    final isWeekly = state.statsTabIndex == 0;
    final snapshots = isWeekly ? _weekSnapshots : _monthSnapshots;
    if (snapshots == null) return List.filled(7, null);

    final values = snapshots.map((s) {
      if (s == null) return null;
      switch (state.statsMetricIndex) {
        case 1:
          return s.screenHours;
        case 2:
          return s.sleepHours;
        default:
          return s.score.toDouble();
      }
    }).toList();

    if (values.isNotEmpty && isWeekly) {
      // Chỉ ghi đè điểm HÔM NAY ở view Weekly (tuần này) — view Monthly gộp
      // theo tuần nên điểm cuối là "tuần này nói chung", không phải đúng
      // hôm nay, ghi đè ở đó sẽ làm sai lệch số liệu các ngày khác trong tuần.
      // Mảng xếp theo Thứ 2(0)..Chủ nhật(6) (xem loadCurrentWeekSnapshots),
      // nên KHÔNG được giả định "hôm nay" luôn là phần tử CUỐI — chỉ đúng
      // nếu hôm nay là Chủ nhật. Tính đúng chỉ số theo weekday thật.
      final todayIndex = DateTime.now().weekday - 1; // Monday=1 -> 0 ... Sunday=7 -> 6
      final liveValue = switch (state.statsMetricIndex) {
        1 => state.screenTimeHours,
        2 => state.habits.firstWhere((h) => h.id == 'sleep').current,
        _ => state.habitsCompletionPercent.toDouble(),
      };
      if (todayIndex >= 0 && todayIndex < values.length) {
        values[todayIndex] = liveValue;
      }
    }
    return values;
  }

  // Trả về đơn vị hiển thị phụ thuộc vào loại số liệu.
  // Score dùng đơn vị điểm, Screen Time và Sleep dùng giờ.
  String _getUnit(HabitProvider state, AppStrings strings) {
    switch (state.statsMetricIndex) {
      case 1:
        return strings.hourUnit;
      case 2:
        return strings.hourUnit;
      default:
        return strings.pointUnit;
    }
  }

  // Chọn nhãn trục dưới tùy theo Weekly hay Monthly.
  List<String> _getLabels(HabitProvider state, AppStrings strings) {
    return state.statsTabIndex == 0 ? strings.weeklyLabels : strings.monthlyLabels;
  }

  // Chuyển chỉ số metric thành chuỗi hiển thị cho các filter chip và tiêu đề.
  String _metricLabel(AppStrings strings, int index) {
    switch (index) {
      case 1:
        return strings.screenTime;
      case 2:
        return strings.sleep;
      default:
        return strings.score;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lấy trạng thái hiện tại từ HabitProvider.
    // Khi HabitProvider thay đổi, widget này sẽ tự động rebuild.
    final state = context.watch<HabitProvider>();
    final strings = context.watch<LanguageProvider>().strings;
    final data = _getData(state);
    final labels = _getLabels(state, strings);
    final unit = _getUnit(state, strings);
    final realValues = data.whereType<double>().toList();
    
    // maxY được dùng để định nghĩa giới hạn trục dọc của biểu đồ — chỉ tính
    // từ các ngày ĐÃ CÓ dữ liệu thật, bỏ qua các ngày null (chưa tới/chưa mở app).
    // Đảm bảo maxY luôn tối thiểu là 1.0 để tránh tính toán interval = 0.
    final calculatedMaxY = realValues.isEmpty ? 100.0 : realValues.reduce(math.max) * 1.15;
    final maxY = calculatedMaxY <= 0 ? 1.0 : calculatedMaxY;
    
    // Đảm bảo horizontalInterval luôn > 0 để không bị nổ assertion error từ fl_chart
    final horizontalInterval = (maxY / 4) > 0 ? (maxY / 4) : 1.0;
    
    final latestValue = realValues.isEmpty ? null : realValues.last;
    // Số thập phân hiển thị: Score là điểm nguyên (0 số lẻ), Screen Time/Sleep
    // dùng giờ nên làm tròn 1 số lẻ — áp dụng thống nhất cho cả tooltip lẫn
    // nhãn giá trị mới nhất phía trên, tránh 1 nơi hiện "5.1" nơi khác hiện
    // số thô nhiều chữ số lẻ do sai số dấu phẩy động (ví dụ "5.111111...").
    final decimals = state.statsMetricIndex == 0 ? 0 : 1;
    // Chỉ số của điểm dữ liệu THẬT cuối cùng (bỏ qua các ngày null chưa có
    // dữ liệu) — dùng để tự hiện sẵn 1 tooltip ở điểm mới nhất mà KHÔNG cần
    // người dùng phải chạm vào biểu đồ mới thấy giá trị.
    var lastRealIndex = -1;
    for (var i = data.length - 1; i >= 0; i--) {
      if (data[i] != null) {
        lastRealIndex = i;
        break;
      }
    }

    // Tách LineChartBarData ra biến riêng để dùng LẠI y hệt cho cả
    // `lineBarsData` lẫn `showingTooltipIndicators` (fl_chart yêu cầu đúng
    // cùng 1 object LineChartBarData ở cả 2 nơi để khớp tooltip tự hiện với
    // đường/điểm đã vẽ).
    final chartLineBarData = LineChartBarData(
      spots: [
        for (var i = 0; i < data.length; i++)
          if (data[i] != null) FlSpot(i.toDouble(), data[i]!),
      ],
      isCurved: true,
      color: AppColors.statsAccent,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          return FlDotCirclePainter(
            radius: index == data.length - 1 ? 5 : 3,
            color: AppColors.statsAccent,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.statsAccent.withValues(alpha: 0.2),
            AppColors.statsAccent.withValues(alpha: 0.0),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: strings.vi ? 'Quay lại' : 'Back',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.statistics, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              strings.trackTrends,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _TabSwitcher(
              tabs: [strings.weekly, strings.monthly],
              selected: state.statsTabIndex,
              onChanged: state.setStatsTabIndex,
            ),
            const SizedBox(height: 16),
            // Thanh chọn loại dữ liệu ở phía trên: Score, Screen Time, Sleep.
            // Đây là các filter chip, khi người dùng chọn thì state thay đổi.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_metrics.length, (i) {
                  final selected = state.statsMetricIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_metricLabel(strings, i)),
                      selected: selected,
                      onSelected: (_) => state.setStatsMetricIndex(i),
                      selectedColor: AppColors.statsAccent.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.statsAccent,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.statsAccent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: selected
                            ? AppColors.statsAccent.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _metricLabel(strings, state.statsMetricIndex),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        latestValue != null ? '${latestValue.toStringAsFixed(decimals)} $unit' : '—',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.statsAccent,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: horizontalInterval,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppColors.border,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        // BUG ĐÃ SỬA: trước đây KHÔNG cấu hình lineTouchData nên
                        // fl_chart dùng tooltip mặc định — in thẳng giá trị double
                        // thô (vd "5.111111111111112" do sai số dấu phẩy động) và
                        // KHÔNG giới hạn trong khung card, khiến số bị tràn ra
                        // ngoài card khi ở gần mép màn hình. Giờ format tròn số
                        // thập phân + ép tooltip luôn nằm trong khung card.
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '${spot.y.toStringAsFixed(decimals)} $unit',
                                Theme.of(context).textTheme.bodySmall!.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              );
                            }).toList(),
                          ),
                        ),
                        // Tự hiện sẵn 1 tooltip ở điểm dữ liệu MỚI NHẤT (hôm nay/
                        // tuần này) ngay khi mở màn hình — người dùng không cần
                        // phải chạm ("dí tay") vào biểu đồ mới biết giá trị.
                        showingTooltipIndicators: lastRealIndex == -1
                            ? []
                            : [
                                ShowingTooltipIndicators([
                                  LineBarSpot(
                                    chartLineBarData,
                                    0,
                                    FlSpot(lastRealIndex.toDouble(), data[lastRealIndex]!),
                                  ),
                                ]),
                              ],
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              // BUG ĐÃ SỬA: không đặt `interval` khiến fl_chart tự
                              // chọn interval (thường < 1, ví dụ 0.5) để "lấp đầy"
                              // trục ngang khi có ít điểm dữ liệu — dẫn tới
                              // getTitlesWidget bị gọi ở các giá trị lẻ (0.5, 1.5...)
                              // và value.toInt() làm tròn xuống trùng với mốc nguyên
                              // liền trước, hiện nhãn thứ bị LẶP LIÊN TIẾP (ví dụ
                              // "T3 T3 T4 T4 T5 T5 T6"). Cố định interval = 1 để mỗi
                              // mốc trục ngang khớp ĐÚNG 1 nhãn thứ duy nhất.
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.round();
                                // Chỉ vẽ nhãn đúng tại mốc số nguyên (mỗi ngày/tuần) —
                                // bỏ qua mọi giá trị lẻ nếu fl_chart vẫn phát sinh
                                // thêm mốc phụ ngoài interval đã khai báo.
                                if (idx != value || idx < 0 || idx >= labels.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    labels[idx],
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [chartLineBarData],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Thẻ "Hoàn thành thói quen" — trước đây nằm chung 1 Row với thẻ
            // streak dạng vòng tròn vàng, nhưng streak đã CHUYỂN sang hiện ở
            // Trang chủ (badge 🔥 trong _ScoreCard, xem home_screen.dart) để
            // người dùng thấy ngay khi mở app thay vì phải vào tận
            // Thống kê mới biết — tránh trùng lặp 2 nơi, bỏ hẳn khối streak
            // ở đây và cho thẻ còn lại chiếm trọn chiều ngang.
            SectionCard(
              child: Column(
                children: [
                  Text(
                    strings.habitCompletion,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: [
                          PieChartSectionData(
                            value: state.habitsCompletionPercent.toDouble(),
                            color: AppColors.habitsAccent,
                            radius: 14,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: (100 - state.habitsCompletionPercent).toDouble(),
                            color: AppColors.border,
                            radius: 14,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${state.habitsCompletionPercent}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.habitsAccent,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _AppUsageBreakdownCard(),
          ],
        ),
        ),
      ),
    );
  }
}

// _AppUsageBreakdownCard: biểu đồ tròn phân chia thời gian dùng máy hôm nay
// theo TỪNG APP (tổng thời gian hiện ở chính giữa). Bấm vào một lát cắt để
// xem chi tiết thời gian đã dùng app đó.
//
// Đọc từ HabitProvider.appUsageBreakdown (dữ liệu CHUNG với Trang chủ) thay
// vì tự query native riêng — đảm bảo số giờ ở đây luôn khớp với Trang chủ.
class _AppUsageBreakdownCard extends StatefulWidget {
  const _AppUsageBreakdownCard();

  @override
  State<_AppUsageBreakdownCard> createState() => _AppUsageBreakdownCardState();
}

class _AppUsageBreakdownCardState extends State<_AppUsageBreakdownCard> {
  int? _selectedIndex;

  // Bảng màu tương phản rõ ràng (Material categorical palette) — tránh 2 lát
  // liền kề trông giống hệt nhau như trước.
  static const _sliceColors = [
    Color(0xFF3B82F6), // blue
    Color(0xFFEF4444), // red
    Color(0xFF22C55E), // green
    Color(0xFFF97316), // orange
    Color(0xFFA855F7), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFEAB308), // yellow
  ];

  Future<void> _refresh() async {
    setState(() => _selectedIndex = null);
    await context.read<HabitProvider>().refreshHabitsFromDevice();
  }

  String _formatDuration(Duration d, bool vi) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return vi ? '$m phút' : '${m}m';
    if (m == 0) return vi ? '$h giờ' : '${h}h';
    return vi ? '$h giờ $m phút' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final allEntries = context.watch<HabitProvider>().appUsageBreakdown;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(strings.appUsageBreakdownTitle, style: Theme.of(context).textTheme.titleSmall),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: _refresh,
                tooltip: strings.vi ? 'Làm mới' : 'Refresh',
              ),
            ],
          ),
          Builder(
            builder: (context) {
              if (allEntries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        strings.appDataUnavailable,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => DeviceDataService.instance.openUsageAccessSettings(),
                        child: Text(strings.grantUsageAccess),
                      ),
                    ],
                  ),
                );
              }

              // Hiện tối đa 7 app riêng lẻ, phần còn lại gộp vào lát "Khác..."
              // để tổng của biểu đồ luôn khớp CHÍNH XÁC với tổng thời gian
              // dùng máy thật (không bị "biến mất" phần chênh lệch).
              const maxIndividualSlices = 7;
              final entries = allEntries.take(maxIndividualSlices).toList();
              final otherSeconds = allEntries
                  .skip(maxIndividualSlices)
                  .fold<int>(0, (sum, e) => sum + e.usage.inSeconds);
              final hasOther = otherSeconds > 0;

              final totalSeconds =
                  allEntries.fold<int>(0, (sum, e) => sum + e.usage.inSeconds);
              final totalDuration = Duration(seconds: totalSeconds);
              final sliceCount = entries.length + (hasOther ? 1 : 0);

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 56,
                            sections: List.generate(sliceCount, (i) {
                              final isOtherSlice = hasOther && i == entries.length;
                              final value = isOtherSlice
                                  ? otherSeconds.toDouble()
                                  : entries[i].usage.inSeconds.toDouble();
                              final isSelected = _selectedIndex == i;
                              return PieChartSectionData(
                                value: value,
                                color: isOtherSlice ? AppColors.textMuted : _sliceColors[i % _sliceColors.length],
                                radius: isSelected ? 46 : 40,
                                showTitle: false,
                              );
                            }),
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                if (!event.isInterestedForInteractions ||
                                    response == null ||
                                    response.touchedSection == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedIndex = response.touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(totalDuration, strings.vi),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              strings.appUsageTotalToday,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(entries.length, (i) {
                    final entry = entries[i];
                    final color = _sliceColors[i % _sliceColors.length];
                    return InkWell(
                      onTap: () => _showAppDetail(context, entry, strings),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.appName,
                                style: Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatDuration(entry.usage, strings.vi),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (hasOther)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.vi ? 'Khác...' : 'Other...',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            _formatDuration(Duration(seconds: otherSeconds), strings.vi),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAppDetail(BuildContext context, AppUsageBreakdownEntry entry, AppStrings strings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.appName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.timer_outlined,
                label: strings.appUsageDurationLabel,
                value: _formatDuration(entry.usage, strings.vi),
              ),
              _DetailRow(
                icon: Icons.open_in_new_rounded,
                label: strings.appOpenCountLabel,
                value: entry.launchCount != null ? '${entry.launchCount}' : strings.appDataUnavailable,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? AppColors.statsAccent
                            : AppColors.textMuted,
                      ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}