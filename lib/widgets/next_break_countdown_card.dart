import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'shared_widgets.dart';

/// Thẻ nhỏ ở Trang chủ hiện đếm ngược tới lần nhắc nghỉ mắt TIẾP THEO —
/// đọc từ NotificationService.getNextRepeatingFireAt() (mốc giờ THẬT của
/// báo thức native đang chạy, xem eye_break_screen.dart/_syncWithRealNextFireTime
/// để biết vì sao không dùng Timer riêng: báo thức lặp là native thuần,
/// mốc giờ kế tiếp phải TÍNH LẠI từ startedAt + interval, không có gì để
/// "lắng nghe" trực tiếp).
///
/// Chỉ hiện khi ReminderProvider.isEyeBreakReminderActive == true — nếu
/// người dùng chưa bật/đã tắt nhắc nghỉ mắt, ẩn hẳn (không chiếm chỗ vô ích).
class NextBreakCountdownCard extends StatefulWidget {
  const NextBreakCountdownCard({super.key});

  @override
  State<NextBreakCountdownCard> createState() => _NextBreakCountdownCardState();
}

class _NextBreakCountdownCardState extends State<NextBreakCountdownCard> {
  Timer? _timer;
  DateTime? _nextFireAt;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Tick mỗi giây để đếm ngược mượt — chỉ TÍNH LẠI hiển thị từ _nextFireAt
    // (đồng hồ thực), không tự trừ dần, nên không bị "đứng hình" nếu Timer
    // bị hệ điều hành tạm dừng một lúc rồi tiếp tục (cùng nguyên tắc với
    // _EyeBreakScreenState._recomputeFromEndAt).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final next = await NotificationService.instance.getNextRepeatingFireAt();
    if (!mounted) return;
    setState(() {
      _nextFireAt = next;
      _loading = false;
    });
  }

  @override
  void didUpdateWidget(covariant NextBreakCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reminder có thể vừa được bật/tắt/đổi khoảng lặp từ EyeBreakScreen ->
    // nạp lại mốc giờ thật mỗi lần widget cha rebuild (rẻ, chỉ đọc SharedPreferences).
    _load();
  }

  String _format(Duration d) {
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '${h}h $m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final reminder = context.watch<ReminderProvider>();
    if (!reminder.isEyeBreakReminderActive) return const SizedBox.shrink();

    final strings = context.watch<LanguageProvider>().strings;
    final accent = AppColors.testAccent;

    if (_loading) return const SizedBox.shrink();
    if (_nextFireAt == null) return const SizedBox.shrink();

    final remaining = _nextFireAt!.difference(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.timer_outlined, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.eyeBreakNextIn,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _format(remaining),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}