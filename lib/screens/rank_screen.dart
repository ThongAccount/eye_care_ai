import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../models/rank_tier.dart';
import '../providers/accent_color_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/rank_provider.dart';
import '../services/leaderboard_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_gradient_border.dart';

/// Bottom sheet giải thích cách tính chuỗi ngày — dùng chung cho banner ở
/// đầu màn Xếp hạng (icon ❓ cạnh dòng "CÒN X NGÀY LÊN HẠNG") và badge 🔥 ở
/// Trang chủ (xem _ScoreCard trong home_screen.dart), để người dùng KHÔNG
/// còn thắc mắc "vì sao chuỗi không lên"/"làm sao để lên chuỗi" — trước đây
/// không có nơi nào giải thích điều kiện thật (điểm sức khỏe mắt phải đạt
/// từ 80/100 trong ngày).
void _showStreakExplanation(BuildContext context, bool vi) {
  final strings = AppStrings(vi);
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.streakExplainTitle,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                strings.streakExplainBody,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Màn hình Xếp hạng, phong cách "League" giống Duolingo: banner giải đấu ở
/// trên (dải huy hiệu các bậc, bậc hiện tại được phóng to + viền gradient
/// động), bên dưới là bảng xếp hạng toàn bộ người dùng sắp xếp giảm dần theo
/// streak thật (HabitProvider.streakDays), đồng bộ realtime qua Firestore
/// (LeaderboardService).
///
/// Viền gradient của các thẻ nổi bật KHÔNG dùng dải cầu vồng cố định — nó
/// dao động quanh màu accent người dùng chọn trong Cài đặt
/// (AccentColorProvider.seedColor), xem AnimatedGradientBorder.
class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  final _tierScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final habit = context.read<HabitProvider>();
      final rank = context.read<RankProvider>();
      rank.updateStreak(habit.streakDays);
      rank.startWatchingLeaderboard();

      final promoted = rank.justPromotedTo;
      if (promoted != null) {
        _showPromotionBanner(promoted);
      }
      _scrollTierLadderToCurrent();
    });
  }

  @override
  void dispose() {
    context.read<RankProvider>().stopWatchingLeaderboard();
    _tierScrollController.dispose();
    super.dispose();
  }

  void _scrollTierLadderToCurrent() {
    if (!mounted || !_tierScrollController.hasClients) return;
    final currentIndex = RankTiers.all.indexOf(context.read<RankProvider>().tier);
    const itemExtent = 92.0;
    final target = (currentIndex * itemExtent - 100).clamp(
      0.0,
      _tierScrollController.position.maxScrollExtent,
    );
    _tierScrollController.animateTo(target, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  void _showPromotionBanner(RankTier tier) {
    final vi = context.read<LanguageProvider>().isVietnamese;
    final accent = context.read<AccentColorProvider>().seedColor;
    final rank = context.read<RankProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedGradientBorder(
          baseColor: accent,
          borderRadius: 28,
          borderWidth: 3,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tier.emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 14),
                Text(
                  vi ? 'Lên hạng!' : 'Rank up!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: tier.color),
                ),
                const SizedBox(height: 6),
                Text(
                  tier.congrats(vi),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: tier.color),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(vi ? 'Tuyệt vời!' : 'Awesome!'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => rank.clearPromotionBanner());
  }

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    final habit = context.watch<HabitProvider>();
    final rank = context.watch<RankProvider>();

    // Streak có thể đã đổi kể từ lần refresh gần nhất — đồng bộ lại mỗi lần
    // build để bậc luôn khớp dữ liệu thật, không cần người dùng tự vào lại
    // màn hình để thấy cập nhật.
    if (habit.streakDays != rank.streakDays) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<RankProvider>().updateStreak(habit.streakDays);
        final promoted = context.read<RankProvider>().justPromotedTo;
        if (promoted != null) _showPromotionBanner(promoted);
      });
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
          tooltip: vi ? 'Quay lại' : 'Back',
        ),
        title: Text(vi ? 'Xếp hạng' : 'Ranking'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<RankProvider>().startWatchingLeaderboard();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          children: [
            _LeagueBanner(vi: vi, tierScrollController: _tierScrollController),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                vi ? 'Bảng xếp hạng' : 'Leaderboard',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                vi
                    ? 'Ai duy trì chuỗi ngày chăm mắt lâu nhất sẽ đứng đầu.'
                    : 'Whoever keeps the longest eye-care streak tops the board.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Leaderboard(vi: vi),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner giải đấu ở đầu màn hình: tên bậc hiện tại, chặng đường còn lại tới
/// bậc kế, và dải huy hiệu các bậc (huy hiệu hiện tại phóng to + viền
/// gradient động).
class _LeagueBanner extends StatelessWidget {
  const _LeagueBanner({required this.vi, required this.tierScrollController});
  final bool vi;
  final ScrollController tierScrollController;

  @override
  Widget build(BuildContext context) {
    final rank = context.watch<RankProvider>();
    final accent = context.watch<AccentColorProvider>().seedColor;
    final tier = rank.tier;
    final next = rank.nextTier;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Banner dùng tông màu tối hơn 1 chút so với nền để nổi bật (giống banner
    // "League" luôn nổi bật trong Duolingo) nhưng vẫn LẤY TỪ colorScheme,
    // không hardcode 1 màu cố định — nhờ vậy vẫn đổi đúng theo sáng/tối.
    final bannerColor = isDark
        ? Color.alphaBlend(accent.withValues(alpha: 0.10), Theme.of(context).colorScheme.surface)
        : Color.alphaBlend(accent.withValues(alpha: 0.06), Theme.of(context).colorScheme.surfaceContainerHighest);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vi ? 'Giải Đấu ${tier.name(vi)}' : '${tier.name(vi)} League',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                next == null
                    ? (vi ? 'ĐÃ ĐẠT BẬC CAO NHẤT' : 'TOP TIER REACHED')
                    : (vi
                        ? 'CÒN ${rank.daysToNextTier} NGÀY LÊN HẠNG'
                        : '${rank.daysToNextTier} DAYS TO RANK UP'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showStreakExplanation(context, vi),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 108,
            child: ListView.builder(
              controller: tierScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: RankTiers.all.length,
              itemBuilder: (context, index) {
                final t = RankTiers.all[index];
                final isCurrent = t.id == tier.id;
                final reached = tier.minStreakDays >= t.minStreakDays;
                return _TierBadge(tier: t, isCurrent: isCurrent, reached: reached, accent: accent);
              },
            ),
          ),
          if (rank.myRank != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, size: 16, color: tier.color),
                const SizedBox(width: 6),
                Text(
                  vi ? 'Hạng #${rank.myRank} trên bảng xếp hạng' : 'Ranking #${rank.myRank} on the leaderboard',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({
    required this.tier,
    required this.isCurrent,
    required this.reached,
    required this.accent,
  });

  final RankTier tier;
  final bool isCurrent;
  final bool reached;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 74.0 : 56.0;
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached
            ? tier.color.withValues(alpha: isCurrent ? 0.22 : 0.14)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        tier.emoji,
        style: TextStyle(fontSize: isCurrent ? 34 : 24, color: reached ? null : Colors.grey.withValues(alpha: 0.6)),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isCurrent
              ? AnimatedGradientBorder(
                  baseColor: accent,
                  borderRadius: size / 2 + 4,
                  borderWidth: 2.5,
                  innerColor: Colors.transparent,
                  child: circle,
                )
              : circle,
          const SizedBox(height: 6),
          SizedBox(
            width: 78,
            child: Text(
              tier.name(true),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                color: reached ? null : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.vi});
  final bool vi;

  @override
  Widget build(BuildContext context) {
    final rank = context.watch<RankProvider>();
    final accent = context.watch<AccentColorProvider>().seedColor;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    if (rank.isLoadingLeaderboard && rank.leaderboard.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (rank.leaderboard.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          vi
              ? 'Chưa có ai trên bảng xếp hạng. Hãy là người đầu tiên duy trì streak!'
              : 'No one on the leaderboard yet. Be the first to keep a streak!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rank.leaderboard.length; i++)
          _LeaderboardTile(
            position: i + 1,
            entry: rank.leaderboard[i],
            vi: vi,
            isMe: rank.leaderboard[i].uid == myUid,
            accent: accent,
          ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.position,
    required this.entry,
    required this.vi,
    required this.isMe,
    required this.accent,
  });

  final int position;
  final LeaderboardEntry entry;
  final bool vi;
  final bool isMe;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: isMe
          ? null
          : BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
      child: Row(
        children: [
          SizedBox(width: 34, child: _PositionMark(position: position)),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: entry.tier.color.withValues(alpha: 0.2),
            backgroundImage: entry.avatarUrl != null ? NetworkImage(entry.avatarUrl!) : null,
            child: entry.avatarUrl == null ? Text(entry.tier.emoji, style: const TextStyle(fontSize: 16)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? (vi ? '${entry.displayName} (Bạn)' : '${entry.displayName} (You)') : entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  entry.tier.title(vi),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.deepOrange),
              const SizedBox(width: 3),
              Text('${entry.streakDays}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Chỉ dòng CỦA CHÍNH BẠN mới có viền gradient động — vừa dễ nhận ra vị
      // trí bản thân giữa danh sách dài, vừa tránh cả bảng xếp hạng nhấp
      // nháy loạn mắt nếu áp hiệu ứng cho mọi dòng.
      child: isMe
          ? AnimatedGradientBorder(baseColor: accent, borderRadius: 16, borderWidth: 2, child: content)
          : content,
    );
  }
}

class _PositionMark extends StatelessWidget {
  const _PositionMark({required this.position});
  final int position;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    String label = '$position';
    switch (position) {
      case 1:
        bg = const Color(0xFFFFD54A);
        break;
      case 2:
        bg = const Color(0xFFC7CDD6);
        break;
      case 3:
        bg = const Color(0xFFD98A4B);
        break;
    }

    if (bg == null) {
      return Center(
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg.withValues(alpha: 0.25)),
      child: Icon(
        Icons.emoji_events_rounded,
        size: 15,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}