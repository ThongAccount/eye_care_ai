import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
class EyeBreakScreen extends StatefulWidget {
  const EyeBreakScreen({super.key});

  @override
  State<EyeBreakScreen> createState() => _EyeBreakScreenState();
}

class _EyeBreakScreenState extends State<EyeBreakScreen> with WidgetsBindingObserver {
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  bool _breakPromptShowing = false;
  // Mốc thời gian tuyệt đối lúc hết giờ — đây là NGUỒN SỰ THẬT DUY NHẤT cho
  // thời gian còn lại. _secondsRemaining chỉ là giá trị hiển thị được TÍNH
  // LẠI từ mốc này mỗi tick, không phải đếm lùi độc lập — vì Timer.periodic
  // có thể bị hệ điều hành tạm dừng khi app chạy nền một lúc rồi mở lại, nếu
  // chỉ đếm lùi theo số tick thực sự chạy được thì sẽ bị "đứng hình" giống
  // lỗi trước đây (thoát app lúc còn 24:39, quay lại vẫn thấy 24:39).
  DateTime? _endAt;
  // Khoảng lặp hiện tại (phút) — cần lưu lại để khi hết giờ có thể tính NGAY
  // mốc giờ nhắc kế tiếp (endAt cũ + interval) mà không phải chờ người dùng
  // xác nhận đã nghỉ mắt mới cập nhật thông báo ghim.
  int _intervalMinutes = 20;

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
    // Khi app quay lại foreground, tính lại ngay lập tức từ đồng hồ thực thay
    // vì chờ tick tiếp theo của Timer (Timer có thể đã bị hệ điều hành tạm
    // dừng trong lúc app ở nền).
    if (state == AppLifecycleState.resumed && _endAt != null) {
      _syncWithRealNextFireTime();
    } else if (state == AppLifecycleState.paused && _endAt != null) {
      // Timer.periodic sẽ ngừng tick khi app xuống nền -> đổi thông báo ghim
      // sang giờ hẹn CỐ ĐỊNH thay vì để lại con số mm:ss "đứng hình" gây hiểu
      // lầm app bị treo. Báo thức hệ thống (đã lên lịch từ trước) không phụ
      // thuộc vào việc này, vẫn tự bắn đúng giờ.
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
      // Đã hết giờ trong lúc app chạy nền (chỉ giờ mở app lại mới biết) ->
      // tắt DND ngay, đừng để bị kẹt "chặn thông báo" quá thời gian dự định.
      FocusModeService.instance.disable();
      setState(() {
        _secondsRemaining = 0;
        _breakPromptShowing = true;
      });
    } else {
      setState(() => _secondsRemaining = remaining);
    }
  }

  // Báo thức lặp thật (chạy hoàn toàn native, xem notification_service.dart)
  // có thể đã bắn thêm 1 hoặc nhiều chu kỳ trong lúc app ở nền/đóng — nếu
  // chỉ tính từ `_endAt` cũ (chốt lúc Start lần đầu) thì UI trong app sẽ
  // hiển thị SAI, lệch hẳn với báo thức thật đang chạy. Tính lại mốc giờ kế
  // tiếp THẬT (dựa trên mốc bắt đầu + interval) để đồng bộ đúng.
  Future<void> _syncWithRealNextFireTime() async {
    final realNext = await NotificationService.instance.getNextRepeatingFireAt();
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
    final interval = await DeviceDataService.instance.loadBreakReminderIntervalMinutes();
    if (endAt != null && interval != null) {
      final now = DateTime.now();
      final secondsLeft = endAt.difference(now).inSeconds;
      _endAt = endAt;
      _intervalMinutes = interval;
      if (secondsLeft > 0) {
        reminder.toggleEyeBreakReminder(true);
        _secondsRemaining = secondsLeft;
        _scheduleRepeatingAlarm(interval);
        _startCountdown(reminder);
        _updateOngoingNotification();
      } else {
        _secondsRemaining = 0;
        _breakPromptShowing = true;
      }
      setState(() {});
    }
  }

  // ---------------- Chế độ Focus (chặn thông báo app khác lúc làm việc) ----------------
  // GIỚI HẠN THỰC TẾ CẦN BIẾT: báo thức hết-giờ-nghỉ-mắt bắn HOÀN TOÀN
  // NATIVE (qua flutter_local_notifications.periodicallyShowWithDuration,
  // xem notification_service.dart) — KHÔNG có đoạn code Dart nào chạy đúng
  // lúc báo thức đó bắn. Vì vậy nếu hệ điều hành đã ĐÓNG HẲN tiến trình app
  // (không chỉ đưa xuống nền), DND sẽ không tự tắt đúng lúc báo thức bắn,
  // mà chỉ tắt lại khi người dùng MỞ APP LẦN KẾ TIẾP (đã xử lý ở
  // _recomputeFromEndAt/_syncWithRealNextFireTime bên trên) — chấp nhận
  // được vì đa số trường hợp app vẫn còn tiến trình chạy nền.

  // Chỉ dùng cho nút "Bắt đầu" người dùng BẤM TAY (không dùng cho các lần tự
  // động chuyển vòng kế tiếp trong _confirmBreakTaken/_dismissPrompt) — nếu
  // lúc bấm mà đã đạt/vượt mục tiêu ngày, coi như người dùng CHỦ Ý muốn tiếp
  // tục dù đã đủ, kích hoạt "không giới hạn" cho hết ngày hôm nay luôn.
  Future<void> _startFromButton(ReminderProvider reminder) async {
    final habitProvider = context.read<HabitProvider>();
    final target = habitProvider.habits.firstWhere((h) => h.id == 'breaks').target;
    if (habitProvider.eyeBreaksTakenToday >= target && !reminder.unlimitedOverrideToday) {
      await reminder.activateUnlimitedForToday();
    }
    _startReminder(reminder);
  }

  void _startReminder(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    final endAt = DateTime.now().add(Duration(minutes: reminder.reminderMinutes));
    _endAt = endAt;
    _intervalMinutes = reminder.reminderMinutes;
    _secondsRemaining = reminder.reminderMinutes * 60;
    reminder.toggleEyeBreakReminder(true);
    _saveReminderEnd(reminder.reminderMinutes, endAt);
    _scheduleRepeatingAlarm(reminder.reminderMinutes);
    _startCountdown(reminder);
    _updateOngoingNotification();
    // Chế độ Focus: bắt đầu 1 chu kỳ "đang làm việc" -> bật DND nếu người
    // dùng đã bật tính năng này (và đã cấp quyền notification policy access
    // — nếu chưa, FocusModeService.enable() tự trả về false, không làm gì).
    if (reminder.focusModeEnabled) {
      FocusModeService.instance.enable();
    }
    setState(() {});
  }

  // Cập nhật nội dung thông báo ghim với số giây còn lại hiện tại.
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

  // Lên lịch báo thức LẶP LẠI mỗi `intervalMinutes` phút — hệ điều hành tự
  // bắn (và tự lặp lại) kể cả khi app đang ở nền hoặc đã bị đóng hẳn, không
  // phụ thuộc vào Timer trong bộ nhớ. Đây là NGUỒN DUY NHẤT bắn thông báo
  // hết-giờ-nghỉ-mắt thật sự — cứ thế lặp lại cho tới khi người dùng vào app
  // và bấm "Tắt" (xem _stopReminder), không cần app phải luôn mở.
  void _scheduleRepeatingAlarm(int intervalMinutes) {
    final strings = context.read<LanguageProvider>().strings;
    NotificationService.instance.scheduleRepeatingBreakAlarm(
      intervalMinutes: intervalMinutes,
      title: strings.eyeBreakTimeUp,
      // Kèm câu gợi ý chạm vào thông báo để mở thẳng Break Reminder — xem
      // NotificationService.onBreakReminderTapped (gán trong main.dart) xử
      // lý điều hướng thật khi người dùng nhấn.
      body: '${strings.eyeBreakLookAway}. ${strings.eyeBreakTapToOpen}.',
      ongoingTitle: strings.breakNotificationTitle,
      ongoingRemainingSuffix: strings.breakNotificationUntil,
    );
  }

  void _startCountdown(ReminderProvider reminder) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // QUAN TRỌNG: tính lại từ _endAt (đồng hồ thực) mỗi tick, KHÔNG đơn
      // thuần trừ 1 mỗi lần tick — nếu Timer bị hệ điều hành tạm dừng một lúc
      // (app chạy nền) rồi mở lại, tick tiếp theo sẽ tự nhảy về đúng giá trị
      // thực tế thay vì tiếp tục đếm từ chỗ "đóng băng" trước đó.
      if (_endAt == null) return;
      final remaining = _endAt!.difference(DateTime.now()).inSeconds;
      setState(() {
        _secondsRemaining = remaining;
        if (remaining <= 0) {
          _breakPromptShowing = true;
          _countdownTimer?.cancel();
          // Chế độ Focus: hết giờ "làm việc", tới lúc nghỉ mắt -> tắt DND
          // ngay, không lý do gì tiếp tục chặn thông báo trong lúc nghỉ.
          FocusModeService.instance.disable();
          // KHÔNG tự bắn thêm thông báo tay ở đây nữa: báo thức LẶP LẠI
          // (scheduleRepeatingBreakAlarm) đã là nguồn duy nhất bắn thông
          // báo hết-giờ-nghỉ-mắt, chạy độc lập trong isolate nền của hệ
          // điều hành — kể cả khi Timer này đang chạy vì app đang mở. Tự
          // bắn thêm ở đây từng gây trùng thông báo/rung 2 lần liền nhau.
          // Màn hình "confirm break" ở đây chỉ để GHI NHẬN lần nghỉ vào
          // Habits khi người dùng đang mở app đúng lúc hết giờ.

          // BUG ĐÃ SỬA: thông báo ghim trên thanh trạng thái trước đây đứng
          // yên ở giờ cũ (VD "Sẽ nhắc lúc 10:10") cho tới khi người dùng tự
          // bấm xác nhận đã nghỉ mắt — gây cảm giác thông báo "bị treo".
          // Báo thức lặp thật của hệ điều hành vẫn chạy đúng chu kỳ cố định
          // bất kể người dùng có xác nhận hay không, nên ngay khi tới mốc
          // hết giờ này, cập nhật NGAY thông báo ghim sang mốc kế tiếp
          // (endAt cũ + interval) để luôn khớp với báo thức thật.
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
    // Đây là cách DUY NHẤT vòng lặp nhắc nghỉ mắt dừng lại — huỷ báo thức
    // LẶP LẠI đã đăng ký với hệ điều hành, nếu không nó sẽ tiếp tục tự bắn
    // mỗi `intervalMinutes` phút vô thời hạn kể cả khi app đã đóng.
    NotificationService.instance.cancelRepeatingBreakAlarm();
    // Chế độ Focus: dừng nhắc hẳn -> tắt DND, không để bị kẹt "chặn thông
    // báo" mãi mãi sau khi người dùng đã tắt tính năng nhắc nghỉ mắt.
    FocusModeService.instance.disable();
    setState(() {
      _secondsRemaining = 0;
      _breakPromptShowing = false;
    });
  }

  Future<void> _confirmBreakTaken(ReminderProvider reminder) async {
    final habitProvider = context.read<HabitProvider>();
    await habitProvider.recordEyeBreak();
    if (!mounted) return;
    setState(() => _breakPromptShowing = false);

    // Đã đạt/vượt mục tiêu số lần nghỉ mắt hôm nay (lấy từ target habit
    // 'breaks' trong Habits) VÀ chưa bật chế độ "không giới hạn" cho hôm
    // nay -> tự dừng nhắc, không tiếp tục vòng đếm ngược tiếp theo nữa.
    final target = habitProvider.habits.firstWhere((h) => h.id == 'breaks').target;
    final reachedTarget = habitProvider.eyeBreaksTakenToday >= target;
    if (reachedTarget && !reminder.unlimitedOverrideToday) {
      final strings = context.read<LanguageProvider>().strings;
      _stopReminder(reminder);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.eyeBreakTargetReached(target as int))),
        );
      }
      return;
    }

    // Tự động bắt đầu chu kỳ đếm ngược tiếp theo.
    _startReminder(reminder);
  }

  Future<void> _saveReminderEnd(int intervalMinutes, DateTime endAt) async {
    await DeviceDataService.instance.saveBreakReminderEnd(endAt, intervalMinutes);
  }

  void _dismissPrompt(ReminderProvider reminder) {
    setState(() => _breakPromptShowing = false);
    _startReminder(reminder);
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<ReminderProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

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
        body: SafeArea(child: _BreakPromptView(
          onDone: () => _confirmBreakTaken(reminder),
          onSkip: () => _dismissPrompt(reminder),
        )),
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
              Text(strings.eyeBreakTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(strings.eyeBreakSubtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              SectionCard(
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
                              value: reminder.isEyeBreakReminderActive && reminder.reminderMinutes > 0
                                  ? _secondsRemaining / (reminder.reminderMinutes * 60)
                                  : 1,
                              strokeWidth: 10,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(AppColors.testAccent),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                reminder.isEyeBreakReminderActive
                                    ? _formatCountdown(_secondsRemaining)
                                    : '--:--',
                                style: Theme.of(context).textTheme.headlineMedium,
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
                      Text(strings.eyeBreakIntervalLabel, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _intervalOptions.map((minutes) {
                          final selected = reminder.reminderMinutes == minutes;
                          return ChoiceChip(
                            label: Text('$minutes ${strings.vi ? "phút" : "min"}'),
                            selected: selected,
                            onSelected: (_) => reminder.setReminderMinutes(minutes),
                            selectedColor: AppColors.testAccent.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: selected ? AppColors.testAccent : null,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => reminder.isEyeBreakReminderActive
                            ? _stopReminder(reminder)
                            : _startFromButton(reminder),
                        child: Text(
                          reminder.isEyeBreakReminderActive ? strings.eyeBreakStop : strings.eyeBreakStart,
                        ),
                      ),
                    ),
                  ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsToggleTile(
                      title: strings.focusModeTitle,
                      description: strings.focusModeDescription,
                      value: reminder.focusModeEnabled,
                      onChanged: (value) => reminder.setFocusModeEnabled(value),
                    ),
                    if (reminder.focusModeEnabled) const _FocusModePermissionBanner(),
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
                      child: const AppIcon('👁️', size: 22, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.eyeBreakTodayCount, style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            '${context.watch<HabitProvider>().eyeBreaksTakenToday}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// Chỉ hiện khi Chế độ Focus đang BẬT nhưng app CHƯA được cấp quyền
// "Notification policy access" — quyền đặc biệt của Android, app không tự
// xin được qua hộp thoại thường, phải dẫn người dùng vào đúng màn hình Cài
// đặt hệ thống. Tự kiểm tra lại mỗi khi widget được build lại (ví dụ sau khi
// người dùng quay lại từ màn Cài đặt) để tự ẩn banner ngay khi đã cấp xong,
// không cần khởi động lại app.
class _FocusModePermissionBanner extends StatefulWidget {
  const _FocusModePermissionBanner();

  @override
  State<_FocusModePermissionBanner> createState() => _FocusModePermissionBannerState();
}

class _FocusModePermissionBannerState extends State<_FocusModePermissionBanner> with WidgetsBindingObserver {
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
    // Người dùng có thể vừa quay lại từ màn Cài đặt hệ thống sau khi cấp
    // quyền -> kiểm tra lại ngay khi app foreground trở lại.
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
            const Icon(Icons.notifications_off_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.focusModePermissionTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(strings.focusModePermissionDescription, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                await FocusModeService.instance.openAccessSettings();
                // Người dùng thường bấm rồi quay lại app ngay lập tức trước
                // khi didChangeAppLifecycleState kịp bắn -> kiểm tra thêm 1
                // lần nữa sau khi Future openAccessSettings() trả về, phòng
                // trường hợp OS trả quyền điều khiển về app nhanh hơn dự kiến.
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