import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auto_break_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';

/// Hiện khi mở app mà HÔM QUA số lần nghỉ mắt chưa đạt mục tiêu — cho chọn
/// giữa 2 hướng: (1) hạ mục tiêu số lần nghỉ/ngày, hoặc (2) rút ngắn
/// countdown giữa 2 lần nhắc (nhắc thường xuyên hơn, dễ đạt mục tiêu cũ hơn).
Future<void> showAdjustBreakGoalDialog(
  BuildContext context, {
  required int yesterdayCount,
  required int target,
}) {
  final strings = context.read<LanguageProvider>().strings;
  final vi = strings.vi;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(vi ? 'Điều chỉnh mục tiêu nghỉ mắt?' : 'Adjust eye-break goal?'),
      content: Text(
        vi
            ? 'Hôm qua bạn chỉ nghỉ mắt được $yesterdayCount/$target lần. Bạn muốn:'
            : 'Yesterday you only took $yesterdayCount of $target eye breaks. Would you like to:',
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final newTarget = yesterdayCount < 1 ? 1 : yesterdayCount;
                  context.read<HabitProvider>().setHabitTarget('breaks', newTarget.toDouble());
                  context.read<AutoBreakProvider>().recomputeInterval(newTarget.toDouble());
                  Navigator.pop(context);
                },
                child: Text(
                  vi ? 'Hạ mục tiêu xuống $yesterdayCount lần/ngày' : 'Lower goal to $yesterdayCount/day',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.testAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final auto = context.read<AutoBreakProvider>();
                  final shorter = (auto.intervalSeconds * 0.8).round();
                  auto.setEnabled(true);
                  // Ghi đè trực tiếp bằng cách gọi recompute với target ẢO
                  // cao hơn để ra countdown ngắn hơn — đơn giản hơn là thêm
                  // API mới, vẫn giữ đúng mục tiêu số lần nghỉ hiện tại.
                  final habits = context.read<HabitProvider>();
                  final currentTarget = habits.habits.firstWhere((h) => h.id == 'breaks').target;
                  auto.recomputeInterval(currentTarget * (auto.intervalSeconds / shorter));
                  Navigator.pop(context);
                },
                child: Text(vi ? 'Giữ mục tiêu, nhắc thường xuyên hơn' : 'Keep goal, remind more often'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
          ],
        ),
      ],
    ),
  );
}