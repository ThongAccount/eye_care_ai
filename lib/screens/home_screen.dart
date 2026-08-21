import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/device_data_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_icon.dart';
import '../theme/app_theme.dart';
import '../widgets/setup_status_banner.dart';
import '../widgets/shared_widgets.dart';
import 'chat_screen.dart';
import 'eye_break_screen.dart';
import 'eye_test_screen.dart';
import 'habits_screen.dart';
import 'habits_survey_screen.dart';
import 'rank_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final habit = context.watch<HabitProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.greeting,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    strings.welcomeTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              Row(
                children: [
                  // Badge chuỗi (streak) — trước đây chỉ hiện ở trang Thống
                  // kê, giờ thêm ở Trang chủ luôn để thấy ngay không cần vào
                  // sâu. Chỉ hiện khi có streak > 0 (streak = 0 hiện ra
                  // "🔥 0 ngày" trông kỳ, không cần thiết ngay từ đầu).
                  if (habit.streakDays > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon('🔥', size: 16, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            '${habit.streakDays}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Builder(builder: (context) {
                    final profile = context.watch<ProfileProvider>();
                    final accent = Theme.of(context).colorScheme.primary;
                    return CircleAvatar(
                      radius: 22,
                      backgroundColor: accent.withValues(alpha: 0.1),
                      backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                      child: profile.avatarUrl == null
                          ? Text(
                              profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '👤',
                              style: TextStyle(fontSize: 18, color: accent),
                            )
                          : null,
                    );
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SetupStatusBanner(),
          _ScoreCard(score: habit.eyeHealthScore),
          const SizedBox(height: 18),
          _FeatureHubCard(),
          const SizedBox(height: 20),
          SectionCard(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HabitsSurveyScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.gradientFor(Theme.of(context).colorScheme.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const AppIcon('📋', size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.surveyEntryTitle, style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          strings.surveyEntrySubtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: '📱',
                  label: strings.screenTime,
                  value: '${habit.screenTimeHours.toStringAsFixed(1)}h',
                  color: AppColors.homeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: '🌳',
                  label: strings.outdoor,
                  value: '${habit.outdoorHours.toStringAsFixed(1)}h',
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: '☕',
                  label: strings.breaks,
                  value: '${habit.breakCount}',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(strings.weeklyOverview, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          // Làm rõ đơn vị của biểu đồ cột: đây là ĐIỂM SỨC KHỎE MẮT hàng
          // ngày (thang 0-100), không phải giờ/phút — trước đây không ghi
          // gì nên chạm vào cột chỉ thấy số trần trụi kiểu "10.0" không
          // biết là gì.
          Text(
            strings.weeklyOverviewUnit,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          const _WeeklyOverviewChart(),
          const SizedBox(height: 20),
          Text(strings.aiSuggestions, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _SuggestionCard(
            icon: '🌿',
            title: strings.takeBreak,
            subtitle: strings.takeBreakSubtitle,
            color: AppColors.primaryTeal,
            bullets: strings.vi
                ? const [
                    ('✨', 'AI: hôm qua bạn nhìn màn hình liên tục ~47 phút, gần gấp đôi mức thường thấy.'),
                    ('👁️', '20 phút nhìn màn hình → 20 giây nhìn xa 6 mét.'),
                    ('🔥', 'Duy trì 3 ngày liên tiếp để mở khoá huy hiệu.'),
                  ]
                : const [
                    ('✨', 'AI: yesterday you had ~47 min of continuous screen time, almost double your usual.'),
                    ('👁️', '20 min on screen → 20 sec looking 6m away.'),
                    ('🔥', 'Keep a 3-day streak to unlock a badge.'),
                  ],
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            icon: '☀️',
            title: strings.moreOutdoor,
            subtitle: strings.moreOutdoorSubtitle,
            color: AppColors.warning,
            bullets: strings.vi
                ? const [
                    ('✨', 'AI: ước tính thời gian ngoài trời từ hoạt động hằng ngày của bạn.'),
                    ('🌤️', 'Ánh sáng tự nhiên giúp làm chậm tiến triển cận thị.'),
                    ('💡', 'Kết hợp đi bộ ngoài trời với cuộc gọi hoặc giờ ăn trưa.'),
                  ]
                : const [
                    ('✨', "AI estimates outdoor exposure from your daily activity."),
                    ('🌤️', 'Natural light helps slow myopia progression.'),
                    ('💡', 'Pair outdoor time with a call or lunch break.'),
                  ],
          ),
          const SizedBox(height: 10),
          _SuggestionCard(
            icon: '😴',
            title: strings.improveSleep,
            subtitle: strings.improveSleepSubtitle,
            color: AppColors.testAccent,
            bullets: strings.vi
                ? const [
                    ('✨', 'AI: tuần này màn hình chỉ tắt trước giờ ngủ trung bình 11 phút.'),
                    ('🌙', 'Nên để màn hình nghỉ ít nhất 30 phút trước khi ngủ.'),
                    ('⏰', 'Mục tiêu: 7-8 giờ ngủ mỗi đêm.'),
                  ]
                : const [
                    ('✨', 'AI: your screens were on until 11 min before bed on average this week.'),
                    ('🌙', 'Aim for at least 30 screen-free minutes before bed.'),
                    ('⏰', 'Target: 7-8 hours of sleep per night.'),
                  ],
          ),
        ],
      ),
    );
  }
}

class _FeatureHubCard extends StatelessWidget {
  const _FeatureHubCard();

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    final features = [
      _FeatureItem(icon: '🏆', title: strings.achievementBadges, route: const _AchievementPage()),
      _FeatureItem(icon: '📊', title: strings.statistics, route: const StatisticsScreen()),
      _FeatureItem(icon: '🏅', title: strings.ranking, route: const RankScreen()),
      _FeatureItem(icon: '🧪', title: strings.eyeTest, route: const EyeTestScreen()),
      _FeatureItem(icon: '✅', title: strings.habits, route: const HabitsScreen()),
      _FeatureItem(icon: '☕', title: strings.eyeBreakTitle, route: const EyeBreakScreen()),
      _FeatureItem(icon: '💬', title: strings.chat, route: const ChatScreen()),
      _FeatureItem(icon: '⚙️', title: strings.settings, route: const SettingsScreen()),
    ];

    final accent = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [accent, secondary, accent.withValues(alpha: 0.8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(23),
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 90,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final feature = features[index];
            return InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => feature.route),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
                      Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(feature.icon, size: 22, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 6),
                    Text(
                      feature.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({required this.icon, required this.title, required this.route});

  final String icon;
  final String title;
  final Widget route;
}

class _AchievementPage extends StatefulWidget {
  const _AchievementPage();

  @override
  State<_AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<_AchievementPage> {
  // Trước đây danh sách này là dữ liệu CỨNG (hardcode `unlocked: true` cho
  // 5/6 thẻ ngay từ đầu, không liên quan gì tới việc người dùng đã thực sự
  // làm gì) — giờ tính lại THẬT dựa trên số liệu có sẵn trong HabitProvider
  // (totalEyeBreaksAllTime cộng dồn từ lúc cài app, streakDays tính từ lịch
  // sử ngày thật). Người cài app mới sẽ thấy tất cả đều ở trạng thái CHƯA MỞ
  // KHOÁ (0/target) cho tới khi họ thật sự đạt được.
  List<_AchievementItem> _buildItems(HabitProvider habit) {
    final totalBreaks = habit.totalEyeBreaksAllTime;
    final streak = habit.streakDays;

    return [
      _AchievementItem(
        icon: '✅',
        title: 'Nghỉ ngơi cho mắt',
        titleEn: 'Rest for the eyes',
        description: 'Hoàn thành quy tắc 20-20-20 lần đầu.',
        descriptionEn: 'Complete the 20-20-20 rule for the first time.',
        progress: totalBreaks.clamp(0, 1),
        target: 1,
        accent: const Color(0xFF22C55E),
      ),
      _AchievementItem(
        icon: '📊',
        title: '20-20-20 Rookie',
        titleEn: '20-20-20 Rookie',
        description: 'Hoàn thành quy tắc 20-20-20 lần đầu.',
        descriptionEn: 'Complete the 20-20-20 rule for the first time.',
        progress: totalBreaks.clamp(0, 1),
        target: 1,
        accent: const Color(0xFFCD7C2F),
      ),
      _AchievementItem(
        icon: '📊',
        title: 'Eye Break Master',
        titleEn: 'Eye Break Master',
        description: 'Hoàn thành 5 lần nghỉ mắt.',
        descriptionEn: 'Complete 5 eye breaks.',
        progress: totalBreaks.clamp(0, 5),
        target: 5,
        accent: const Color(0xFFC0C0C0),
      ),
      _AchievementItem(
        icon: '🔥',
        title: 'Blink Legend',
        titleEn: 'Blink Legend',
        description: 'Hoàn thành 15 lần nghỉ mắt.',
        descriptionEn: 'Complete 15 eye breaks.',
        progress: totalBreaks.clamp(0, 15),
        target: 15,
        accent: const Color(0xFFF7C948),
      ),
      _AchievementItem(
        icon: '🏆',
        title: 'Guardian of Vision',
        titleEn: 'Guardian of Vision',
        description: 'Không bỏ lỡ bất kỳ nhắc nhở nghỉ mắt nào trong 30 ngày.',
        descriptionEn: 'Never miss any eye-break reminder for 30 days.',
        progress: streak.clamp(0, 30),
        target: 30,
        accent: const Color(0xFF8B5CF6),
      ),
      _AchievementItem(
        icon: '🔒',
        title: 'Digital Balance',
        titleEn: 'Digital Balance',
        description: 'Duy trì 7 ngày liên tiếp sử dụng lành mạnh.',
        descriptionEn: 'Maintain 7 days of healthy usage in a row.',
        progress: streak.clamp(0, 7),
        target: 7,
        accent: const Color(0xFF60A5FA),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final habit = context.watch<HabitProvider>();
    final items = _buildItems(habit);

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
        title: Text(strings.achievementTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.achievementBadges,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                strings.achievementMood,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              ...items.map((item) {
                final isVi = strings.vi;
                final title = isVi ? item.title : item.titleEn;
                final description = isVi ? item.description : item.descriptionEn;
                final progress = item.unlocked ? item.target : item.progress;
                final percent = item.unlocked ? 1.0 : (progress / item.target).clamp(0.0, 1.0);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: item.unlocked
                        ? LinearGradient(
                            colors: [
                              item.accent.withValues(alpha: 0.20),
                              Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.70),
                              Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    border: Border.all(
                      color: item.unlocked
                          ? item.accent.withValues(alpha: 0.8)
                          : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                      width: item.unlocked ? 1.6 : 1,
                    ),
                    boxShadow: item.unlocked
                        ? [
                            BoxShadow(
                              color: item.accent.withValues(alpha: 0.16),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 260),
                        scale: item.unlocked ? 1.08 : 0.95,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: item.unlocked
                                ? LinearGradient(
                                    colors: [
                                      item.accent,
                                      item.accent.withValues(alpha: 0.7),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.grey.shade500,
                                      Colors.grey.shade700,
                                    ],
                                  ),
                            boxShadow: item.unlocked
                                ? [
                                    BoxShadow(
                                      color: item.accent.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: AppIcon(item.icon, size: 24, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item.unlocked
                                        ? item.accent.withValues(alpha: 0.18)
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item.unlocked ? strings.achievementUnlocked : strings.achievementLocked,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: item.unlocked ? item.accent : AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: item.unlocked ? null : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 8,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(item.accent),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.unlocked
                                  ? '${item.target}/${item.target}'
                                  : '${item.progress}/${item.target}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: item.unlocked ? item.accent : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementItem {
  const _AchievementItem({
    required this.icon,
    required this.title,
    required this.titleEn,
    required this.description,
    required this.descriptionEn,
    required this.progress,
    required this.target,
    required this.accent,
  });

  final String icon;
  final String title;
  final String titleEn;
  final String description;
  final String descriptionEn;
  final int progress;
  final int target;
  final Color accent;

  // Tính thẳng từ progress/target thay vì 1 field `unlocked` cứng riêng —
  // không thể nào bị lệch dữ liệu (trước đây `unlocked: true` và
  // `progress: 1/target: 1` là 2 giá trị tách rời, dễ set sai lệch nhau).
  bool get unlocked => progress >= target;
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.gradientFor(accent),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.eyeHealthScore,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.goodProgress,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    strings.fromLastWeek,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
              ],
            ),
          ),
          ScoreRing(score: score),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bullets,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  // Các gợi ý rút gọn (icon + vài chữ) hiện khi mở chi tiết — thay cho đoạn
  // văn dài, đúng tinh thần "tóm gọn bằng phương tiện phi ngôn ngữ".
  final List<(String, String)> bullets;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: AppIcon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final b in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(b.$2, style: Theme.of(sheetContext).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Trước đây biểu đồ "Tổng quan tuần" ở Trang chủ dùng 7 số cứng
// (72,78,84,80,88,76,84) — không phản ánh dữ liệu thật của người dùng.
// Widget này tự tải snapshot điểm sức khỏe mắt của 7 ngày gần nhất từ
// DeviceDataService (cùng nguồn dữ liệu với biểu đồ Tuần ở màn Statistics),
// ngày nào chưa có dữ liệu thì vẽ cột rất thấp/mờ thay vì bịa số.
class _WeeklyOverviewChart extends StatefulWidget {
  const _WeeklyOverviewChart();

  @override
  State<_WeeklyOverviewChart> createState() => _WeeklyOverviewChartState();
}

class _WeeklyOverviewChartState extends State<_WeeklyOverviewChart> {
  List<({int score, double screenHours, double sleepHours})?>? _snapshots;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snapshots = await DeviceDataService.instance.loadCurrentWeekSnapshots();
    if (!mounted) return;
    setState(() => _snapshots = snapshots);
  }

  BarChartGroupData _bar(int x, double? y, {bool isToday = false}) {
    final value = y ?? 4.0; // chưa có dữ liệu -> cột rất thấp thay vì bịa số
    final accent = Theme.of(context).colorScheme.primary;
    final accentEnd = AppTheme.gradientFor(accent).colors.last;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: y == null
                ? [AppColors.border, AppColors.border]
                : isToday
                    ? [accent, accentEnd]
                    : [
                        accent.withValues(alpha: 0.4),
                        accentEnd.withValues(alpha: 0.4),
                      ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshots = _snapshots;
    final today = DateTime.now().weekday - 1; // 0 = thứ 2 ... 6 = chủ nhật
    final strings = context.watch<LanguageProvider>().strings;

    return SectionCard(
      child: SizedBox(
        height: 132,
        child: snapshots == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  // BUG ĐÃ SỬA: trước đây không cấu hình barTouchData nên
                  // fl_chart tự dùng tooltip MẶC ĐỊNH — chỉ in số thô kiểu
                  // "10.0" khi chạm vào cột, không ai biết đó là gì. Giờ
                  // hiện rõ "XX/100 điểm" (hoặc "Chưa có dữ liệu" nếu ngày
                  // đó chưa có snapshot).
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final hasData = groupIndex < snapshots.length && snapshots[groupIndex] != null;
                        final text = hasData
                            ? (strings.vi
                                ? '${rod.toY.round()}/100 điểm'
                                : '${rod.toY.round()}/100 points')
                            : strings.vi
                                ? 'Chưa có dữ liệu'
                                : 'No data yet';
                        return BarTooltipItem(
                          text,
                          Theme.of(context).textTheme.bodySmall!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 50,
                        getTitlesWidget: (value, meta) {
                          // Chỉ hiện 0/50/100 để làm rõ trục là thang điểm
                          // sức khỏe mắt, không cần dày đặc mọi mốc.
                          if (value != 0 && value != 50 && value != 100) return const SizedBox.shrink();
                          return Text(
                            '${value.toInt()}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                          return Text(days[idx], style: Theme.of(context).textTheme.bodySmall);
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    final score = (i < snapshots.length ? snapshots[i]?.score.toDouble() : null);
                    return _bar(i, score, isToday: i == today);
                  }),
                ),
              ),
      ),
    );
  }
}