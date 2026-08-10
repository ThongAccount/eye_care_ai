import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_icon.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// HabitsScreen hiển thị tiến trình các thói quen tốt cho mắt trong ngày.
// Đây là màn hình CHỈ XEM (read-only): giá trị `current` của mỗi thói quen
// được HabitProvider nạp từ DeviceDataService (cảm biến / hệ điều hành của máy),
// người dùng không còn tự nhập tay như trước.
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  @override
  void initState() {
    super.initState();
    final habit = context.read<HabitProvider>();
    habit.startHabitTracking();
    // Chạy sau frame đầu để tránh gọi notifyListeners() trong lúc build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      habit.refreshHabitsFromDevice();
    });
  }

  @override
  Widget build(BuildContext context) {
    final habit = context.watch<HabitProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: language.isVietnamese ? 'Quay lại' : 'Back',
        ),
        title: Text(strings.dailyHabits),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: habit.refreshHabitsFromDevice,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.dailyHabits, style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            strings.trackRoutines,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    _CompletionBadge(percent: habit.habitsCompletionPercent),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      strings.vi
                          ? 'Cập nhật lần cuối: ${_formatTime(habit.habitsLastUpdated)}'
                          : 'Last updated: ${_formatTime(habit.habitsLastUpdated)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    if (habit.isRefreshingHabits)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: CircularProgressIndicator(
                                value: habit.habitsCompletionPercent / 100,
                                strokeWidth: 6,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.habitsAccent,
                                ),
                              ),
                            ),
                            Text(
                              '${habit.habitsCompletionPercent}%',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.habitsAccent,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.todaysProgress,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.completedHabits(habit.habits.where((h) => h.progress >= 1).length, habit.habits.length),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...habit.habits.map((habitItem) {
                  Widget card = habitItem.id == 'sleep'
                      ? InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showManualSleepSheet(context, habitItem.current),
                          child: Stack(
                            children: [
                              _HabitCard(habit: habitItem),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.edit_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _HabitCard(habit: habitItem);

                  if (habitItem.isComingSoon) {
                    card = IgnorePointer(
                      child: Opacity(
                        opacity: 0.45,
                        child: Stack(
                          children: [
                            card,
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      strings.featureInDevelopment,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  );
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(strings.changeTargetButton),
                    onPressed: () => _showChangeTargetSheet(context, habit, strings),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangeTargetSheet(BuildContext context, HabitProvider habit, AppStrings strings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _ChangeTargetSheet(habitProvider: habit, strings: strings),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '—';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

void _showManualSleepSheet(BuildContext context, double currentHours) {
  final strings = context.read<LanguageProvider>().strings;
  double value = currentHours > 0 ? currentHours : 7;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.manualSleepTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  strings.manualSleepDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => setState(() => value = (value - 0.5).clamp(0, 16)),
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        '${value.toStringAsFixed(1)} ${strings.vi ? "giờ" : "hrs"}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => setState(() => value = (value + 0.5).clamp(0, 16)),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      context.read<HabitProvider>().setManualSleepHours(value);
                      Navigator.pop(context);
                    },
                    child: Text(strings.save),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppTheme.gradientFor(Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$percent% Complete',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit});

  final HabitData habit;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final habitProvider = context.watch<HabitProvider>();
    final color = Color(habit.color);
    // Habit "phone" hiển thị số giờ dùng THẬT (không bị clamp về target*2
    // như habit.current) — nhất quán với thẻ "Sử dụng theo ứng dụng" và điểm
    // sức khỏe mắt, đều dùng chung totalScreenTimeHoursToday.
    final displayCurrent = habit.id == 'phone' ? habitProvider.totalScreenTimeHoursToday : habit.current;
    final valueText = habit.unit == 'hrs' ? displayCurrent.toStringAsFixed(1) : displayCurrent.round().toString();
    // Vượt mục tiêu dùng điện thoại -> đổi thanh tiến độ + số liệu sang màu
    // đỏ cảnh báo (thay vì làm thanh vơi đi, giữ nguyên đầy 100% để không
    // mất thông tin trực quan, chỉ đổi MÀU để báo hiệu nguy hiểm).
    final isPhoneOverTarget = habit.id == 'phone' && displayCurrent > habit.target;
    final barColor = isPhoneOverTarget ? AppColors.error : color;
    final targetText = habit.unit == 'hrs'
        ? habit.target.toStringAsFixed(0)
        : habit.target.round().toString();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: AppIcon(habit.icon, size: 20, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            strings.habitTitle(habit.id),
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _HabitAlertIndicator(level: habitProvider.alertLevelFor(habit)),
                      ],
                    ),
                    Text(
                      strings.habitSubtitle(habit.id),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    valueText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: barColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    strings.vi
                        ? 'trong $targetText ${strings.habitUnit(habit.unit)}'
                        : 'of $targetText ${strings.habitUnit(habit.unit)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedProgressBar(
            progress: habit.progress,
            color: barColor,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.vi
                    ? '${(habit.progress * 100).round()}% mục tiêu ngày'
                    : '${(habit.progress * 100).round()}% of daily goal',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: barColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                _statusLabel(habit, strings, isPhoneOverTarget: isPhoneOverTarget),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isPhoneOverTarget
                          ? AppColors.error
                          : habit.isLive
                              ? (habit.progress >= 0.8 ? AppColors.success : AppColors.textMuted)
                              : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(HabitData habit, AppStrings strings, {bool isPhoneOverTarget = false}) {
    if (!habit.isLive) {
      return strings.vi ? 'Chưa có nguồn dữ liệu' : 'No data source yet';
    }
    // Vượt mục tiêu dùng điện thoại: KHÔNG được hiện "Đã đạt mục tiêu!" (nghe
    // như khen) dù thanh vẫn đang đầy 100% — phải nói rõ đây là VƯỢT, không
    // phải ĐẠT, khớp với màu đỏ cảnh báo vừa đổi ở thanh tiến độ.
    if (isPhoneOverTarget) {
      return strings.vi ? 'Đã vượt mục tiêu!' : 'Over target!';
    }
    if (habit.progress >= 1) {
      return strings.vi ? 'Đã đạt mục tiêu!' : 'Goal reached!';
    }
    if (habit.progress >= 0.8) {
      return strings.vi ? 'Sắp đạt mục tiêu!' : 'Almost there!';
    }
    return strings.vi ? 'Đang theo dõi...' : 'Tracking...';
  }
}

// Thay cho chấm tròn trung tính cũ (chỉ nói "có dữ liệu hay không") — hiện
// dấu "!" (cảnh báo) khi chỉ số đang ở hướng XẤU cho sức khỏe mắt, hoặc dấu
// ✓ (tốt) khi đang ở hướng TỐT, tuỳ theo HabitAlertLevel đã tính theo đúng
// chiều riêng của từng loại habit (xem HabitProvider.alertLevelFor).
class _HabitAlertIndicator extends StatelessWidget {
  const _HabitAlertIndicator({required this.level});

  final HabitAlertLevel level;

  @override
  Widget build(BuildContext context) {
    switch (level) {
      case HabitAlertLevel.warning:
        return const Icon(Icons.error_rounded, size: 15, color: AppColors.warning);
      case HabitAlertLevel.good:
        return const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success);
      case HabitAlertLevel.none:
        return Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textMuted),
        );
    }
  }
}

// _ChangeTargetSheet: cho phép người dùng tự chỉnh lại mục tiêu (target)
// của từng habit bằng nút +/-, tách biệt với target được đề xuất từ khảo sát.
class _ChangeTargetSheet extends StatefulWidget {
  const _ChangeTargetSheet({required this.habitProvider, required this.strings});

  final HabitProvider habitProvider;
  final AppStrings strings;

  @override
  State<_ChangeTargetSheet> createState() => _ChangeTargetSheetState();
}

class _ChangeTargetSheetState extends State<_ChangeTargetSheet> {
  late final Map<String, double> _localTargets;

  @override
  void initState() {
    super.initState();
    _localTargets = {
      for (final h in widget.habitProvider.habits) h.id: h.target,
    };
  }

  double _stepFor(String unit) {
    switch (unit) {
      case 'hrs':
        return 0.5;
      case 'min':
        return 10;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.changeTargetButton, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            strings.changeTargetSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          // Loại habit đang phát triển (ví dụ 'reading'/Eye Test Count) ra
          // khỏi danh sách đổi mục tiêu — chưa có tính năng thật thì cho
          // đổi target cũng vô nghĩa.
          ...widget.habitProvider.habits.where((h) => !h.isComingSoon).map((h) {
            final step = _stepFor(h.unit);
            final value = _localTargets[h.id] ?? h.target;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  AppIcon(h.icon, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(strings.habitTitle(h.id), style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: value > step
                        ? () => setState(() => _localTargets[h.id] = value - step)
                        : null,
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      '${value % 1 == 0 ? value.round().toString() : value.toStringAsFixed(1)} ${strings.habitUnit(h.unit)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () => setState(() => _localTargets[h.id] = value + step),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.habitsAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                for (final entry in _localTargets.entries) {
                  await widget.habitProvider.setHabitTarget(entry.key, entry.value);
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(strings.changeTargetSave),
            ),
          ),
        ],
      ),
    );
  }
}