import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auto_break_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/device_data_service.dart';
import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_icon.dart';
import '../widgets/settings_toggle_tile.dart';
import '../widgets/shared_widgets.dart';

// EyeBreakScreen thay thế hoàn toàn màn hình Eye Test cũ.
// Đây là một bộ đếm giờ nhắc người dùng nghỉ mắt theo chu kỳ (mặc định theo
// quy tắc 20-20-20). Khi hết giờ, một màn hình toàn màn hình hiện ra yêu cầu
// người dùng nhìn xa trong 20 giây, sau đó tự xác nhận đã nghỉ — số lần nghỉ
// này được ghi nhận THẬT (qua HabitProvider.recordEyeBreak) và đồng bộ với habit
// "Eye Breaks" ở trang Habits.
//
// THÊM MỚI: card "Tự động nhắc nghỉ mắt" (AutoBreakProvider) — khác hẳn bộ
// đếm thủ công ở trên (người dùng phải tự bấm "Bắt đầu" và chọn khoảng thời
// gian cố định). Ở chế độ tự động: countdown được TÍNH RA từ mục tiêu số
// lần nghỉ/ngày (habit 'breaks') chia cho thời gian dùng máy thật, và việc
// "đã nghỉ mắt hay chưa" được suy luận tự động qua UsageStatsManager (nếu
// sau khi nhắc mà máy KHÔNG ghi nhận thêm thao tác trong 20 giây, coi như
// người dùng đã rời mắt khỏi màn hình) — không cần camera, không cần bấm
// xác nhận thủ công.
//
// BUG ĐÃ SỬA (2 đồng hồ đếm ngược hiển thị 2 con số khác nhau): trước đây
// "Tự động nhắc nghỉ mắt" (AutoBreakProvider) và "Nhắc nghỉ mắt" thủ công
// (ReminderProvider, đặt hẹn giờ cố định) là 2 cơ chế HOÀN TOÀN ĐỘC LẬP,
// không có gì ngăn cả 2 cùng bật một lúc — mỗi cái tự đếm ngược theo lịch
// riêng (thủ công thì cố định, tự động thì tính lại theo usage thật), ra 2
// con số/2 thông báo khác nhau ngay trong cùng 1 lúc, khiến người dùng tưởng
// app bị lỗi "đếm sai". Giờ 2 cơ chế LOẠI TRỪ LẪN NHAU: bật bên nào sẽ tự
// tắt bên còn lại (xem _ensureOnlyOneReminderActive), và khi "Tự động" đang
// bật, phần đếm ngược thủ công bị làm mờ + khoá thao tác kèm ghi chú lý do,
// thay vì vẫn hiển thị số liệu cũ gây hiểu lầm là đang chạy song song.
class EyeBreakScreen extends StatefulWidget {
  const EyeBreakScreen({super.key});

  @override
  State<EyeBreakScreen> createState() => _EyeBreakScreenState();
}

class _EyeBreakScreenState extends State<EyeBreakScreen>
    with WidgetsBindingObserver {
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _breakPromptShowing = false;
  DateTime? _endAt;
  int _intervalMinutes = 20;
  // Mỗi chu kỳ đếm ngược chỉ được tính 1 lần nghỉ mắt (tránh cộng đôi khi cả
  // Timer lẫn lúc app mở lại từ nền cùng phát hiện đã hết giờ).
  bool _cycleCounted = false;

  static const _intervalOptions = [10, 20, 30, 45];

  @override
  void dispose() {
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedReminder();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _endAt != null) {
      _syncWithRealNextFireTime();
    } else if (state == AppLifecycleState.paused && _endAt != null) {
      final strings = context.read<LanguageProvider>().strings;
      NotificationService.instance.showStaticOngoingUntil(
        endAt: _endAt!,
        title: strings.breakNotificationTitle,
        untilPrefix: strings.breakNotificationUntil,
      );
    }
  }

  void _recomputeFromEndAt() {
    if (_endAt == null) return;
    final remaining = _endAt!.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _countdownTimer?.cancel();
      FocusModeService.instance.disable();
      setState(() {
        _secondsRemaining = 0;
        _breakPromptShowing = true;
      });
      _countBreakOnce();
    } else {
      setState(() => _secondsRemaining = remaining);
    }
  }

  Future<void> _syncWithRealNextFireTime() async {
    // Đếm ngược đã hết trong lúc app ở nền (báo thức native đã báo) -> tính 1
    // lần nghỉ mắt trước khi mốc _endAt bị ghi đè bằng lần nhắc kế tiếp.
    if (_endAt != null && !_endAt!.isAfter(DateTime.now())) {
      await _countBreakOnce();
    }
    final realNext = await NotificationService.instance
        .getNextRepeatingFireAt();
    if (!mounted) return;
    if (realNext != null) {
      _endAt = realNext;
    }
    _recomputeFromEndAt();
    if (_secondsRemaining > 0) {
      _updateOngoingNotification();
    }
  }

  Future<void> _loadSavedReminder() async {
    final reminder = context.read<ReminderProvider>();
    final endAt = await DeviceDataService.instance.loadBreakReminderEnd();
    final interval = await DeviceDataService.instance
        .loadBreakReminderIntervalMinutes();
    if (endAt != null && interval != null) {
      final now = DateTime.now();
      final secondsLeft = endAt.difference(now).inSeconds;
      _endAt = endAt;
      _intervalMinutes = interval;
      if (secondsLeft > 0) {
        await reminder.toggleEyeBreakReminder(true);
        _secondsRemaining = secondsLeft;
        await _scheduleRepeatingAlarm(interval);
        _startCountdown(reminder);
        _updateOngoingNotification();
      } else {
        _secondsRemaining = 0;
        _breakPromptShowing = true;
      }
      setState(() {});
    }
  }

  // Đảm bảo CHỈ MỘT trong 2 cơ chế nhắc nghỉ mắt (thủ công / tự động) đang
  // hoạt động tại một thời điểm — tắt bên còn lại trước khi bật bên mới, để
  // không bao giờ có 2 đồng hồ đếm ngược khác nhau chạy song song.
  Future<void> _ensureOnlyOneReminderActive({required bool keepAuto}) async {
    final reminder = context.read<ReminderProvider>();
    final autoBreak = context.read<AutoBreakProvider>();
    if (keepAuto) {
      if (reminder.isEyeBreakReminderActive) {
        _stopReminder(reminder);
      }
    } else {
      if (autoBreak.enabled) {
        await autoBreak.setEnabled(false);
      }
    }
  }

  Future<void> _startFromButton(ReminderProvider reminder) async {
    await _ensureOnlyOneReminderActive(keepAuto: false);
    final habitProvider = context.read<HabitProvider>();
    final target = habitProvider.habits
        .firstWhere((h) => h.id == 'breaks')
        .target;
    if (habitProvider.eyeBreaksTakenToday >= target &&
        !reminder.unlimitedOverrideToday) {
      await reminder.activateUnlimitedForToday();
    }
    await _startReminder(reminder);
  }

  Future<void> _startReminder(ReminderProvider reminder) async {
    _countdownTimer?.cancel();
    _cycleCounted = false;
    final endAt = DateTime.now().add(
      Duration(minutes: reminder.reminderMinutes),
    );
    _endAt = endAt;
    _intervalMinutes = reminder.reminderMinutes;
    _secondsRemaining = reminder.reminderMinutes * 60;
    await reminder.toggleEyeBreakReminder(true);
    await _saveReminderEnd(reminder.reminderMinutes, endAt);
    await _scheduleRepeatingAlarm(reminder.reminderMinutes);
    _startCountdown(reminder);
    _updateOngoingNotification();
    if (reminder.focusModeEnabled) {
      FocusModeService.instance.enable();
    }
    setState(() {});
  }

  void _updateOngoingNotification() {
    if (!mounted) return;
    final strings = context.read<LanguageProvider>().strings;
    NotificationService.instance.updateOngoingCountdown(
      secondsRemaining: _secondsRemaining,
      title: strings.breakNotificationTitle,
      remainingSuffix: strings.breakNotificationRemaining,
      endAt: _endAt,
    );
  }

  Future<void> _scheduleRepeatingAlarm(int intervalMinutes) async {
    final strings = context.read<LanguageProvider>().strings;
    final reminder = context.read<ReminderProvider>();
    final waterHint = reminder.waterReminderEnabled
        ? ' ${strings.eyeBreakWaterHint}.'
        : '';
    await NotificationService.instance.scheduleRepeatingBreakAlarm(
      intervalMinutes: intervalMinutes,
      title: strings.eyeBreakTimeUp,
      body:
          '${strings.eyeBreakLookAway}. ${strings.eyeBreakTapToOpen}.$waterHint',
      ongoingTitle: strings.breakNotificationTitle,
      ongoingRemainingSuffix: strings.breakNotificationUntil,
    );
  }

  void _startCountdown(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_endAt == null) return;
      final remaining = _endAt!.difference(DateTime.now()).inSeconds;
      setState(() {
        _secondsRemaining = remaining;
        if (remaining <= 0) {
          _breakPromptShowing = true;
          _countdownTimer?.cancel();
          FocusModeService.instance.disable();
          final nextFireAt = _endAt!.add(Duration(minutes: _intervalMinutes));
          _endAt = nextFireAt;
          final strings = context.read<LanguageProvider>().strings;
          NotificationService.instance.showStaticOngoingUntil(
            endAt: nextFireAt,
            title: strings.breakNotificationTitle,
            untilPrefix: strings.breakNotificationUntil,
          );
        }
      });
      if (remaining <= 0) _countBreakOnce();
      if (_secondsRemaining > 0) {
        _updateOngoingNotification();
      }
    });
  }

  void _stopReminder(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    _endAt = null;
    reminder.toggleEyeBreakReminder(false);
    DeviceDataService.instance.clearBreakReminderEnd();
    NotificationService.instance.cancelRepeatingBreakAlarm();
    FocusModeService.instance.disable();
    setState(() {
      _secondsRemaining = 0;
      _breakPromptShowing = false;
    });
  }

  // Đếm ngược về 0 = tính ĐÚNG 1 lần nghỉ mắt (theo yêu cầu), không cần bấm
  // xác nhận. Nếu vừa đạt mục tiêu ngày và chưa bật "không giới hạn" thì tự
  // dừng nhắc như trước.
  Future<void> _countBreakOnce() async {
    if (_cycleCounted || !mounted) return;
    _cycleCounted = true;
    final habitProvider = context.read<HabitProvider>();
    final reminder = context.read<ReminderProvider>();
    await habitProvider.recordEyeBreak();
    if (!mounted) return;

    final target = habitProvider.habits.firstWhere((h) => h.id == 'breaks').target;
    final reachedTarget = habitProvider.eyeBreaksTakenToday >= target;
    if (reachedTarget && !reminder.unlimitedOverrideToday) {
      final strings = context.read<LanguageProvider>().strings;
      _stopReminder(reminder);
      ScaffoldMessenger.of(context).showSnackBar(
        // `target` là double -> phải .round(), bản cũ `target as int` sẽ crash.
        SnackBar(content: Text(strings.eyeBreakTargetReached(target.round()))),
      );
    }
  }

  // Nút "Xong" ở màn nhìn xa 20 giây: lần nghỉ đã được tính lúc hết giờ, nên
  // chỉ đóng màn và bắt đầu chu kỳ kế tiếp.
  Future<void> _confirmBreakTaken(ReminderProvider reminder) async {
    setState(() => _breakPromptShowing = false);
    await _startReminder(reminder);
  }

  Future<void> _saveReminderEnd(int intervalMinutes, DateTime endAt) async {
    await DeviceDataService.instance.saveBreakReminderEnd(
      endAt,
      intervalMinutes,
    );
  }

  Future<void> _dismissPrompt(ReminderProvider reminder) async {
    setState(() => _breakPromptShowing = false);
    await _startReminder(reminder);
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatAutoCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<ReminderProvider>();
    final autoBreak = context.watch<AutoBreakProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;
    // Khi "Tự động nhắc nghỉ mắt" đang bật, phần đếm ngược THỦ CÔNG bên dưới
    // bị khoá + làm mờ (xem giải thích ở đầu file) — 2 cơ chế không bao giờ
    // cùng hiển thị số liệu một lúc nữa.
    final manualLockedByAuto = autoBreak.enabled;

    if (_breakPromptShowing) {
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
        ),
        body: SafeArea(
          child: _BreakPromptView(
            onDone: () => _confirmBreakTaken(reminder),
            onSkip: () => _dismissPrompt(reminder),
          ),
        ),
      );
    }

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
        title: Text(strings.eyeBreakTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.eyeBreakTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                strings.eyeBreakSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // ---------------- Tự động nhắc nghỉ mắt (mới) ----------------
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsToggleTile(
                      title: strings.vi
                          ? 'Tự động nhắc nghỉ mắt'
                          : 'Auto eye-break reminders',
                      description: strings.vi
                          ? 'Không cần đặt hẹn giờ — tự chia mục tiêu nghỉ mắt/ngày thành các khoảng đếm ngược đều nhau. Hết giờ mới nhắc và tự tính là 1 lần nghỉ mắt (không cần bấm xác nhận). Bật cái này sẽ tự tắt "Nhắc nghỉ mắt" thủ công bên dưới để tránh 2 đồng hồ đếm ngược khác nhau.'
                          : "No need to set a timer — splits your daily break goal into even countdowns. When it hits zero you get reminded and it counts as 1 eye break automatically (no confirmation tap). Turning this on will automatically turn off the manual reminder below, so you never see two different countdowns.",
                      value: autoBreak.enabled,
                      onChanged: (v) async {
                        if (v) {
                          await _ensureOnlyOneReminderActive(keepAuto: true);
                        }
                        await autoBreak.setEnabled(v);
                      },
                    ),
                    if (autoBreak.enabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: autoBreak.progress,
                                minHeight: 6,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.testAccent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatAutoCountdown(autoBreak.secondsRemaining),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.vi
                            ? 'Mỗi ${(autoBreak.intervalSeconds / 60).round()} phút nhắc 1 lần và tính 1 lần nghỉ mắt'
                            : 'Reminds every ${(autoBreak.intervalSeconds / 60).round()} min and counts 1 eye break',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (manualLockedByAuto)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.vi
                                ? 'Đang tắt "Nhắc nghỉ mắt" thủ công vì Tự động nhắc nghỉ mắt đang bật ở trên — tắt Tự động nếu bạn muốn tự đặt hẹn giờ cố định.'
                                : 'The manual reminder below is off while Auto eye-break reminders is on above — turn Auto off if you want a fixed manual timer instead.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IgnorePointer(
                ignoring: manualLockedByAuto,
                child: Opacity(
                  opacity: manualLockedByAuto ? 0.4 : 1.0,
                  child: SectionCard(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: CircularProgressIndicator(
                                  value:
                                      reminder.isEyeBreakReminderActive &&
                                          reminder.reminderMinutes > 0
                                      ? _secondsRemaining /
                                            (reminder.reminderMinutes * 60)
                                      : 1,
                                  strokeWidth: 10,
                                  backgroundColor: AppColors.border,
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.testAccent,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    reminder.isEyeBreakReminderActive
                                        ? _formatCountdown(_secondsRemaining)
                                        : '--:--',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  Text(
                                    reminder.isEyeBreakReminderActive
                                        ? strings.eyeBreakNextIn
                                        : strings.eyeBreakStart,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!reminder.isEyeBreakReminderActive) ...[
                          Text(
                            strings.eyeBreakIntervalLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: _intervalOptions.map((minutes) {
                              final selected = reminder.reminderMinutes == minutes;
                              return ChoiceChip(
                                label: Text(
                                  '$minutes ${strings.vi ? "phút" : "min"}',
                                ),
                                selected: selected,
                                onSelected: (_) =>
                                    reminder.setReminderMinutes(minutes),
                                selectedColor: AppColors.testAccent.withValues(
                                  alpha: 0.15,
                                ),
                                // BUG ĐÃ SỬA: ChoiceChip mặc định hiện dấu ✓ khi
                                // được chọn — dấu tích chèn vào đột ngột, cộng
                                // với fontWeight đổi từ 500 lên 700 (chữ đậm
                                // rộng hơn chữ thường) khiến cả chip đổi kích
                                // thước 2 LẦN CÙNG LÚC trong 1 khung hình, tạo
                                // cảm giác "giật/lag" khi chọn khoảng thời gian
                                // nhắc. Tắt checkmark + giữ NGUYÊN 1 độ đậm chữ
                                // cho cả 2 trạng thái (chỉ đổi màu) để chip
                                // không bao giờ đổi kích thước khi chọn nữa.
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: selected ? AppColors.testAccent : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: reminder.isEyeBreakReminderActive
                                  ? AppColors.error
                                  : AppColors.testAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => reminder.isEyeBreakReminderActive
                                ? _stopReminder(reminder)
                                : _startFromButton(reminder),
                            child: Text(
                              reminder.isEyeBreakReminderActive
                                  ? strings.eyeBreakStop
                                  : strings.eyeBreakStart,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: SettingsToggleTile(
                  title: strings.autoDetectEyeBreakTitle,
                  description: strings.autoDetectEyeBreakDescription,
                  value: reminder.autoDetectEyeBreaks,
                  onChanged: (value) => reminder.setAutoDetectEyeBreaks(value),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: SettingsToggleTile(
                  title: strings.waterReminderTitle,
                  description: strings.waterReminderDescription,
                  value: reminder.waterReminderEnabled,
                  onChanged: (value) => reminder.setWaterReminderEnabled(value),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsToggleTile(
                      title: strings.focusModeTitle,
                      description: strings.focusModeDescription,
                      value: reminder.focusModeEnabled,
                      onChanged: (value) => reminder.setFocusModeEnabled(value),
                    ),
                    if (reminder.focusModeEnabled)
                      const _FocusModePermissionBanner(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.testAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const AppIcon(
                        '👁️',
                        size: 22,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.eyeBreakTodayCount,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${context.watch<HabitProvider>().eyeBreaksTakenToday}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.testAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakPromptView extends StatefulWidget {
  const _BreakPromptView({required this.onDone, required this.onSkip});

  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  State<_BreakPromptView> createState() => _BreakPromptViewState();
}

class _BreakPromptViewState extends State<_BreakPromptView> {
  int _secondsLeft = 20;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Container(
      color: AppColors.testAccent.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppIcon('🌿', size: 56, color: AppColors.primaryBlue),
          const SizedBox(height: 16),
          Text(
            strings.eyeBreakTimeUp,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.eyeBreakLookAway,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            '$_secondsLeft',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: AppColors.testAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.testAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: widget.onDone,
              child: Text(strings.eyeBreakDone),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onSkip,
            child: Text(strings.eyeBreakSkip),
          ),
        ],
      ),
    );
  }
}

class _FocusModePermissionBanner extends StatefulWidget {
  const _FocusModePermissionBanner();

  @override
  State<_FocusModePermissionBanner> createState() =>
      _FocusModePermissionBannerState();
}

class _FocusModePermissionBannerState extends State<_FocusModePermissionBanner>
    with WidgetsBindingObserver {
  bool? _hasAccess;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAccess();
  }

  Future<void> _checkAccess() async {
    final granted = await FocusModeService.instance.hasAccess();
    if (mounted) setState(() => _hasAccess = granted);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasAccess != false) return const SizedBox.shrink();
    final strings = context.watch<LanguageProvider>().strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_off_rounded,
              color: AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.focusModePermissionTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.focusModePermissionDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                await FocusModeService.instance.openAccessSettings();
                _checkAccess();
              },
              child: Text(strings.focusModeGrantAccess),
            ),
          ],
        ),
      ),
    );
  }
}