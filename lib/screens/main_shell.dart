import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auto_break_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/rank_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/settings_more_provider.dart';
import '../providers/theme_provider.dart';

import '../providers/update_provider.dart';
import '../providers/usage_limit_provider.dart';
import '../services/app_usage_monitor.dart';
import '../services/cloud_backup_service.dart';
import '../services/device_data_service.dart';
import '../services/update_service.dart';
import '../dialogs/adjust_break_goal_dialog.dart';
import '../widgets/update_dialog.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // Trước đây Phone Usage/App Usage chỉ tải MỘT LẦN lúc mở app
  // (refreshHabitsFromDevice() gọi đúng 1 lần trong initState) — số liệu sau
  // đó đứng yên dù người dùng vẫn đang dùng máy. Thêm timer định kỳ để số
  // liệu tự cập nhật trong lúc app đang mở, giống Digital Wellbeing.
  Timer? _usagePollTimer;
  // Đẩy dữ liệu (thống kê, cài đặt, tiến độ thành tựu) lên Firestore định kỳ
  // trong lúc app đang mở, để nếu người dùng đổi máy/cài lại app giữa
  // chừng thì vẫn không mất quá nhiều dữ liệu của phiên hiện tại. Tách
  // riêng khỏi _usagePollTimer (60s) vì đây là việc mạng, không cần chạy
  // dày như refresh dữ liệu cảm biến cục bộ.
  Timer? _cloudBackupTimer;
  static const _cloudBackupInterval = Duration(minutes: 5);

  // Mốc thời gian app bị đưa xuống nền — dùng cho chế độ nghỉ mắt THỤ ĐỘNG:
  // nếu người dùng khoá màn hình/rời app đủ lâu rồi quay lại, coi như đã có
  // 1 lần nghỉ mắt (xem didChangeAppLifecycleState bên dưới).
  DateTime? _pausedAt;
  static const _autoBreakMinGap = Duration(seconds: 20);
  // Giới hạn trên để tránh tính bậy: rời máy hàng giờ (đi ngủ, họp dài...)
  // không phải là "nghỉ mắt" theo quy tắc 20-20-20, nên chỉ tính khoảng nghỉ
  // hợp lý trong khung này.
  static const _autoBreakMaxGap = Duration(minutes: 20);

  // Chỉ hiện gợi ý "điều chỉnh mục tiêu nghỉ mắt" TỐI ĐA 1 LẦN mỗi phiên mở
  // app — tránh hiện lặp lại dialog mỗi lần _refreshHabitsAndSyncRank() chạy
  // lại (mỗi 60s) trong cùng 1 lần mở app.
  bool _shortfallDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final habit = context.read<HabitProvider>();
    habit.startHabitTracking();

    // Nối AutoBreakProvider với mục tiêu 'breaks' hiện tại + callback ghi
    // nhận nghỉ mắt THẬT vào HabitProvider khi tự phát hiện được (không cần
    // người dùng bấm xác nhận thủ công).
    final autoBreak = context.read<AutoBreakProvider>();
    final breaksTarget = habit.habits.firstWhere((h) => h.id == 'breaks').target;
    autoBreak.recomputeInterval(breaksTarget);
    autoBreak.onAutoConfirmed = () async {
      await context.read<HabitProvider>().recordEyeBreak();
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshHabitsAndSyncRank();
      _checkForAppUpdate();
      _checkBreakShortfall();
      // Chế độ đọc ban đêm: tính lại ngày/đêm mỗi lần mở app để auto-switch
      // giao diện tối kịp thời (chỉ có tác dụng khi người dùng đã bật công
      // tắc trong Cài đặt > Màn hình).
      unawaited(context.read<ThemeProvider>().refreshNightState());
      // App-lock: kiểm tra giới hạn sau khi refresh habit (cùng nguồn dữ liệu).
      AppUsageMonitor.instance
          .check(context.read<UsageLimitProvider>());
    });
    _usagePollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshHabitsAndSyncRank();
      // App-lock: nếu chạm giới hạn trong lúc đang dùng, khóa ngay (không
      // chờ người dùng rời/mở lại app).
      AppUsageMonitor.instance.check(context.read<UsageLimitProvider>());
    });
    _cloudBackupTimer = Timer.periodic(_cloudBackupInterval, (_) => _pushCloudBackupIfEnabled());
  }

  // Chỉ đẩy lên Firestore khi người dùng đã bật "Sao lưu trên đám mây" ở
  // Cài đặt (mặc định bật) — CloudBackupService.pushBackup() tự bỏ qua âm
  // thầm nếu chưa đăng nhập, nên gọi ở đây luôn an toàn kể cả khi chưa login.
  void _pushCloudBackupIfEnabled() {
    if (!mounted) return;
    if (!context.read<SettingsMoreProvider>().cloudBackup) return;
    unawaited(CloudBackupService.instance.pushBackup());
  }

  // Mở app lên là tự hỏi GitHub Releases xem có bản mới hơn không (xem
  // lib/services/update_service.dart) — chỉ hỏi 1 LẦN mỗi lần mở app (không
  // đặt trong Timer.periodic như refresh habit ở trên), tránh phiền người
  // dùng bằng dialog bật lên lặp lại giữa lúc họ đang dùng app.
  //
  // Trước đây hàm này nhận thêm `manual`/`context` optional (cho 1 nút
  // "kiểm tra cập nhật" thủ công) nhưng nút đó rốt cuộc được implement bằng
  // 1 widget riêng (_CheckForUpdateButton trong settings_screen.dart) tự
  // gọi UpdateService trực tiếp, không đi qua hàm này — 2 tham số kia thành
  // dead code không nơi nào truyền vào. Bỏ hẳn: vừa dọn code chết, vừa hết
  // luôn lỗi "use_build_context_synchronously" (dùng BuildContext của MỘT
  // WIDGET KHÁC được truyền vào, `mounted` của State này không chứng minh
  // được BuildContext đó vẫn còn sống qua await) vì giờ chỉ còn dùng đúng
  // `context` của chính State này, luôn được bảo vệ bởi đúng `mounted` của nó.
  Future<void> _checkForAppUpdate() async {
    final update = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    // Luôn cập nhật UpdateProvider (kể cả khi update == null) để badge trên
    // icon Settings tự ẩn nếu bản mới nhất đã được cài xong ở phiên trước.
    final updateProvider = context.read<UpdateProvider>();
    await updateProvider.setAvailableUpdate(update);
    if (update == null || !mounted) return;
    // Đã dismiss ĐÚNG bản build này ở lần mở app trước -> chỉ để badge tự
    // hiện (đã set ở trên), KHÔNG hiện lại dialog làm phiền.
    if (!updateProvider.shouldShowDialog) return;
    final strings = context.read<LanguageProvider>().strings;
    if (!mounted) return;
    UpdateDialog.show(
      context,
      update,
      strings,
      onDismissed: () => context.read<UpdateProvider>().dismissCurrentUpdate(),
    );
  }

  // Kiểm tra HÔM QUA có bị thiếu số lần nghỉ mắt so với mục tiêu không — nếu
  // có, gợi ý người dùng hạ mục tiêu hoặc rút ngắn countdown giữa các lần
  // nhắc để dễ đạt hơn. Chỉ hiện 1 lần/phiên mở app (xem _shortfallDialogShown),
  // và chỉ khi có dữ liệu thật của hôm qua (không đoán mò).
  Future<void> _checkBreakShortfall() async {
    if (_shortfallDialogShown || !mounted) return;
    final habit = context.read<HabitProvider>();
    final target = habit.habits.firstWhere((h) => h.id == 'breaks').target.round();
    final shortfall = await DeviceDataService.instance.checkYesterdayBreaksShortfall(target);
    if (shortfall == null || !mounted) return;
    _shortfallDialogShown = true;
    showAdjustBreakGoalDialog(context, yesterdayCount: shortfall, target: target);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      // App xuống nền -> đẩy backup ngay (không chờ tick định kỳ tiếp theo,
      // có thể còn tới vài phút nữa) — đây là thời điểm hợp lý nhất vì
      // người dùng vừa dùng xong 1 phiên, dữ liệu vừa đổi khả năng cao nhất.
      _pushCloudBackupIfEnabled();
      return;
    }

    if (state == AppLifecycleState.resumed && mounted) {
      // Mở app trở lại (từ nền) -> làm mới ngay, không chờ tick 60s tiếp
      // theo, vì người dùng vừa dùng các app khác trong lúc app này ở nền.
      _refreshHabitsAndSyncRank();
      AppUsageMonitor.instance.check(context.read<UsageLimitProvider>());

      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final gap = DateTime.now().difference(pausedAt);
      final reminder = context.read<ReminderProvider>();
      if (reminder.autoDetectEyeBreaks && gap >= _autoBreakMinGap && gap <= _autoBreakMaxGap) {
        context.read<HabitProvider>().recordEyeBreak();
      }
    }
  }

  // Làm mới dữ liệu thói quen từ thiết bị RỒI đồng bộ streak mới nhất lên
  // bậc xếp hạng (RankProvider) + Firestore — gộp 2 bước lại một chỗ vì mọi
  // nơi refresh habit đều cần rank cập nhật theo, tránh quên đồng bộ ở một
  // trong các điểm gọi (initState, poll timer, resume từ nền).
  Future<void> _refreshHabitsAndSyncRank() async {
    final habit = context.read<HabitProvider>();
    await habit.refreshHabitsFromDevice();
    if (!mounted) return;
    context.read<RankProvider>().updateStreak(habit.streakDays);
    // Mục tiêu 'breaks' có thể vừa đổi (survey, đổi target thủ công, hoặc
    // vừa áp dụng gợi ý điều chỉnh) -> đồng bộ lại countdown tự động theo
    // đúng mục tiêu mới nhất.
    if (!mounted) return;
    final breaksTarget = habit.habits.firstWhere((h) => h.id == 'breaks').target;
    context.read<AutoBreakProvider>().recomputeInterval(breaksTarget);
  }

  @override
  void dispose() {
    _usagePollTimer?.cancel();
    _cloudBackupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const SafeArea(
        child: HomeScreen(),
      ),
    );
  }
}