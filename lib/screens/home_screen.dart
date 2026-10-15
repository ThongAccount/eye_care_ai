import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auto_break_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_more_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../services/ai_action_handler.dart';
import '../services/device_data_service.dart';
import '../services/eye_chat_service.dart';
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
import '../widgets/next_break_countdown_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final habit = context.watch<HabitProvider>();
    final language = context.watch<LanguageProvider>();
    final strings = language.strings;
    final hasUpdate = context.watch<UpdateProvider>().hasUpdateAvailable;

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
                  // Biểu tượng báo "có bản cập nhật đang chờ" — thay cho
                  // chấm đỏ trước đây gắn trên ô Cài đặt trong lưới tính
                  // năng (dễ bị hiểu nhầm là lỗi UI khi tràn ra ngoài ô).
                  // Đặt hẳn lên góc trên Trang chủ, bấm vào mở luôn Cài đặt
                  // (đã có sẵn mục "Kiểm tra bản cập nhật" trong đó).
                  if (hasUpdate) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.system_update_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
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
                          ? (profile.name.isNotEmpty
                              ? Text(
                                  profile.name[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              // Chưa có tên (chưa đăng nhập/chế độ khách) ->
                              // icon người dùng thay vì emoji 👤, đúng yêu
                              // cầu không dùng emoji làm icon.
                              : AppIcon('👤', size: 20, color: accent))
                          : null,
                    );
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SetupStatusBanner(),
          _ScoreCard(habit: habit),
          const SizedBox(height: 12),
          // Thẻ AI TỰ ĐỘNG rà soát dữ liệu ngay ở Trang chủ — khác với Chat
          // (phải người dùng chủ động hỏi): thẻ này TỰ chạy phân tích (tối đa
          // 1 lần mỗi 6 tiếng) và đề xuất/thực hiện điều chỉnh (tôn trọng
          // đúng cài đặt "Hỏi trước khi AI tự thao tác" ở Settings > Quyền
          // riêng tư & Bảo mật).
          const _AiInsightCard(),
          const NextBreakCountdownCard(),
          const SizedBox(height: 12),
          _TodaySuggestionsCard(habit: habit),
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

// ---------------- AI tự động rà soát ngay Trang chủ ----------------
// Khác với Chat (bạn phải chủ động gõ câu hỏi), thẻ này TỰ CHẠY 1 lượt phân
// tích dữ liệu hiện tại (điểm sức khỏe mắt, từng habit, hồ sơ thị lực, kiểu
// nhắc nhở, tự động nhắc nghỉ mắt...) và để AI đề xuất ĐÚNG 1 điều chỉnh cụ
// thể nếu thấy cần, dùng LẠI đúng cơ chế %%ACTION%%...%%END%% + AiActionHandler
// đã có sẵn cho Chat — không phát minh cơ chế mới, đảm bảo hành vi nhất quán
// (tôn trọng cùng 1 cài đặt "Hỏi trước khi AI tự thao tác").
//
// Tự chạy tối đa 1 lần mỗi 6 tiếng (lưu mốc giờ vào SharedPreferences) để
// không tốn quota/pin mỗi lần mở app — người dùng vẫn có thể bấm nút làm mới
// để phân tích lại ngay bất cứ lúc nào.
class _AiInsightCard extends StatefulWidget {
  const _AiInsightCard();

  @override
  State<_AiInsightCard> createState() => _AiInsightCardState();
}

enum _AiInsightState { idle, loading, result, error }

class _AiInsightCardState extends State<_AiInsightCard> {
  _AiInsightState _state = _AiInsightState.idle;
  String _resultText = '';
  List<AiAction> _pendingActions = [];
  bool _actionsResolved = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRunOnOpen());
  }

  // Theo yêu cầu: VÀO APP LÀ AI BÁO LUÔN, không cần bấm làm mới. Trước đây
  // có giới hạn tối đa 1 lần/6 tiếng nên nhiều lần mở app không thấy gì.
  // Giờ chạy MỖI LẦN thẻ này xuất hiện (mỗi lần vào Trang chủ). Chờ tối đa
  // ~8 giây cho HabitProvider nạp xong dữ liệu thật hôm nay (nếu không AI sẽ
  // phân tích số 0 lúc app vừa khởi động), rồi mới gọi AI. Lỗi (mạng, key...)
  // hiện thẳng trong thẻ để người dùng biết, không còn nuốt im lặng.
  Future<void> _autoRunOnOpen() async {
    final habit = context.read<HabitProvider>();
    for (var i = 0; i < 16 && habit.habitsLastUpdated == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }
    if (!mounted) return;
    await _runAnalysis();
  }

  String _buildContext(BuildContext context) {
    final habits = context.read<HabitProvider>();
    final settings = context.read<SettingsProvider>();
    final autoBreak = context.read<AutoBreakProvider>();
    final buffer = StringBuffer();
    buffer.writeln('- Điểm sức khỏe mắt hiện tại: ${habits.eyeHealthScore}/100');
    buffer.writeln('- Hồ sơ thị lực (vision profile): "${settings.visionProfile}"');
    buffer.writeln('- Kiểu nhắc nhở hiện tại (reminder style): "${settings.reminderStyle}"');
    buffer.writeln('- Tự động nhắc nghỉ mắt (auto break): ${autoBreak.enabled ? "đang BẬT" : "đang TẮT"}');
    for (final habit in habits.habits) {
      if (habit.isComingSoon) continue;
      final unit = switch (habit.id) {
        'phone' || 'sleep' => 'giờ/ngày',
        'outdoor' => 'phút/ngày',
        'breaks' => 'lần/ngày',
        _ => habit.unit,
      };
      buffer.writeln(
        '- ${habit.title} (id: "${habit.id}"): hiện tại = ${habit.current.toStringAsFixed(1)} $unit, '
        'mục tiêu = ${habit.target.toStringAsFixed(1)} $unit${habit.isLive ? '' : ' (chưa có dữ liệu)'}',
      );
    }
    return buffer.toString();
  }

  Future<void> _runAnalysis({bool silentOnError = false}) async {
    if (!mounted) return;
    setState(() {
      _state = _AiInsightState.loading;
      _errorText = null;
    });

    try {
      final contextInfo = _buildContext(context);
      final reply = await EyeChatService.instance.sendMessage(
        history: [
          {
            'role': 'user',
            'content':
                'Dựa trên dữ liệu hiện tại của tôi (xem phần "Dữ liệu hiện tại của người dùng"), hãy chủ động '
                'phân tích và đề xuất ĐÚNG 1 thay đổi cụ thể (nếu thật sự cần thiết) để cải thiện sức khỏe mắt, '
                'kèm đúng 1 khối lệnh %%ACTION%%...%%END%% cho thay đổi đó. Trả lời trong 1-2 câu ngắn gọn bằng '
                'tiếng Việt, giải thích lý do đề xuất. Nếu mọi chỉ số đều đang ổn hoặc chưa đủ dữ liệu để kết '
                'luận, chỉ cần trả lời ngắn gọn 1 câu rằng hiện tại ổn/chưa đủ dữ liệu, KHÔNG chèn khối lệnh nào.',
          },
        ],
        contextInfo: contextInfo,
      );

      if (!mounted) return;
      final result = AiActionHandler.extract(reply);
      setState(() {
        _resultText = result.cleanedText.isEmpty
            ? (context.read<LanguageProvider>().strings.vi ? 'Mọi thứ đang ổn.' : 'Everything looks fine.')
            : result.cleanedText;
        _pendingActions = result.actions;
        _actionsResolved = _pendingActions.isEmpty;
        _state = _AiInsightState.result;
      });

      if (_pendingActions.isNotEmpty && mounted) {
        final requireConfirm = context.read<SettingsMoreProvider>().aiConfirmBeforeActing;
        if (!requireConfirm) {
          await _applyActions();
        }
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final strings = context.read<LanguageProvider>().strings;
      String friendly;
      if (message.contains('missing_api_key')) {
        friendly = strings.chatErrorMissingKey;
      } else if (message.contains('invalid_api_key')) {
        friendly = strings.chatErrorInvalidKey;
      } else if (message.contains('rate_limited')) {
        friendly = strings.chatErrorRateLimited;
      } else if (message.contains('network_error')) {
        friendly = strings.chatErrorNetwork;
      } else {
        friendly = strings.chatErrorGeneric;
      }
      // Lần tự động chạy nền (silentOnError) thất bại thì lặng lẽ lùi về
      // trạng thái ban đầu — không làm phiền người dùng bằng lỗi kỹ thuật
      // ngay khi vừa mở app; chỉ hiện lỗi rõ ràng khi họ chủ động bấm nút
      // làm mới.
      setState(() {
        if (silentOnError) {
          _state = _AiInsightState.idle;
        } else {
          _state = _AiInsightState.error;
          _errorText = friendly;
        }
      });
    }
  }

  Future<void> _applyActions() async {
    final habits = context.read<HabitProvider>();
    final isVi = context.read<LanguageProvider>().isVietnamese;
    final confirmations = await AiActionHandler.execute(
      _pendingActions,
      habits: habits,
      isVietnamese: isVi,
      settings: context.read<SettingsProvider>(),
      autoBreak: context.read<AutoBreakProvider>(),
    );
    if (!mounted) return;
    setState(() {
      _actionsResolved = true;
      if (confirmations.isNotEmpty) {
        _resultText = '$_resultText\n\n${confirmations.join('\n')}';
      }
    });
  }

  void _declineActions() {
    setState(() => _actionsResolved = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradientFor(primary),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.vi ? 'AI tự động rà soát' : 'AI auto check-in',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_state != _AiInsightState.loading)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: strings.vi ? 'Phân tích lại' : 'Re-analyze',
                    onPressed: () => _runAnalysis(),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (_state == _AiInsightState.idle)
              Text(
                strings.vi
                    ? 'Bấm biểu tượng làm mới để AI xem lại thói quen và tự đề xuất điều chỉnh nếu cần.'
                    : 'Tap refresh to let AI review your habits and suggest a change if needed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            if (_state == _AiInsightState.loading)
              Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.vi ? 'AI đang xem xét dữ liệu của bạn...' : 'AI is reviewing your data...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            if (_state == _AiInsightState.error)
              Text(
                _errorText ?? strings.chatErrorGeneric,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            if (_state == _AiInsightState.result) ...[
              Text(_resultText, style: Theme.of(context).textTheme.bodyMedium),
              if (!_actionsResolved) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _declineActions,
                        child: Text(strings.aiPendingActionsDecline),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: primary),
                        onPressed: _applyActions,
                        child: Text(strings.aiPendingActionsAccept),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
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
  const _ScoreCard({required this.habit});

  final HabitProvider habit;

  // Hiện bottom sheet giải thích cách tính chuỗi ngày — dùng CHUNG cho cả
  // trường hợp streak = 0 (người dùng chưa biết bắt đầu từ đâu) lẫn > 0
  // (muốn biết vì sao chuỗi không tăng/bị đứt), nên badge streak LUÔN hiện
  // và LUÔN chạm được, không còn ẩn khi = 0 như trước.
  void _showStreakExplanation(BuildContext context) {
    final strings = context.read<LanguageProvider>().strings;
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
                    const Icon(Icons.local_fire_department_rounded, size: 20, color: Colors.deepOrange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.streakExplainTitle,
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${habit.streakDays}',
                      style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                            color: Theme.of(sheetContext).colorScheme.primary,
                            fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final accent = Theme.of(context).colorScheme.primary;
    final delta = habit.eyeHealthScoreDelta;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.gradientFor(accent),
        borderRadius: BorderRadius.circular(20),
        // Shadow dịu hơn bản trước (blur/alpha thấp hơn) — thẻ điểm vẫn nổi
        // bật nhờ gradient + vị trí đầu trang, không cần bóng đổ đậm.
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                    // Badge chênh lệch điểm THẬT so với hôm qua (xem
                    // HabitProvider.eyeHealthScoreDelta) — không hiện gì nếu
                    // chưa có snapshot hôm qua để so sánh (ví dụ ngày đầu
                    // dùng app), thay vì bịa số cố định như trước.
                    // Đặt cùng hàng với badge chuỗi ngày (streak) — người
                    // dùng trước đây chỉ thấy chuỗi ở trang Xếp hạng, không
                    // biết chuỗi hiện tại của mình ngay ở Trang chủ.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (delta != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  delta >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                Text(
                                  '${delta >= 0 ? '+' : ''}$delta',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showStreakExplanation(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  '${habit.streakDays} ${strings.dayStreak}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Vòng tròn điểm nhỏ lại một chút (120 -> 104) để thẻ điểm
              // không chiếm gần hết màn hình, vẫn là thông tin nổi bật nhất
              // nhờ vị trí + gradient, nhưng nhường chỗ cho breakdown yếu
              // tố bên dưới dễ quét mắt hơn.
              ScoreRing(score: habit.eyeHealthScore, size: 104, strokeWidth: 9),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.18))),
            ),
          ),
          const SizedBox(height: 10),
          _ScoreFactorRow(
            icon: '📱',
            label: strings.scoreFactorScreenTime,
            percent: habit.screenTimeScore,
            noDataLabel: strings.scoreFactorNoData,
            explanation: strings.scoreFactorScreenTimeExplain,
          ),
          _ScoreFactorRow(
            icon: '🌙',
            label: strings.scoreFactorEnvironment,
            percent: habit.environmentScore,
            noDataLabel: strings.scoreFactorNoData,
            explanation: strings.scoreFactorEnvironmentExplain,
          ),
          _ScoreFactorRow(
            icon: '💧',
            label: strings.scoreFactorEyeBreaks,
            percent: habit.eyeBreaksScore,
            noDataLabel: strings.scoreFactorNoData,
            explanation: strings.scoreFactorEyeBreaksExplain,
          ),
          _ScoreFactorRow(
            icon: '😴',
            label: strings.scoreFactorSleep,
            percent: habit.sleepScore,
            noDataLabel: strings.scoreFactorNoData,
            explanation: strings.scoreFactorSleepExplain,
          ),
        ],
      ),
    );
  }
}

// Thẻ "Lưu ý & gợi ý cho hôm nay" — so sánh % từng yếu tố hôm nay với chính
// nó hôm qua (HabitProvider.factorDeltas) để đưa ra vài dòng gợi ý CỤ THỂ,
// thay vì chỉ hiện điểm số trần trụi. Ưu tiên hiện yếu tố đang XẤU nhất
// (percent thấp nhất) hoặc TỤT nhiều nhất trước, tối đa 3 dòng để không rối
// mắt.
class _TodaySuggestionsCard extends StatelessWidget {
  const _TodaySuggestionsCard({required this.habit});

  final HabitProvider habit;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    final factors = <String, double?>{
      'screenTime': habit.screenTimeScore,
      'environment': habit.environmentScore,
      'eyeBreaks': habit.eyeBreaksScore,
      'sleep': habit.sleepScore,
    };
    final labels = <String, String>{
      'screenTime': strings.scoreFactorScreenTime,
      'environment': strings.scoreFactorEnvironment,
      'eyeBreaks': strings.scoreFactorEyeBreaks,
      'sleep': strings.scoreFactorSleep,
    };

    // Chỉ xét các yếu tố ĐANG CÓ dữ liệu hôm nay, sắp % thấp nhất lên đầu —
    // đây thường là điều đáng chú ý nhất.
    final candidates = factors.entries.where((e) => e.value != null).toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));

    final bullets = <String>[];
    for (final entry in candidates) {
      if (bullets.length >= 3) break;
      final id = entry.key;
      final percent = entry.value!;
      final delta = habit.factorDeltas[id];
      final label = labels[id]!;
      if (delta != null && delta <= -10) {
        bullets.add(strings.suggestionDeclined(label, -delta));
      } else if (percent < 50) {
        bullets.add(strings.suggestionLow(label));
      } else if (delta != null && delta >= 10) {
        bullets.add(strings.suggestionImproved(label, delta));
      }
    }

    final hasAnyYesterdayData = habit.factorDeltas.values.any((d) => d != null);
    final fallbackText =
        hasAnyYesterdayData ? strings.suggestionsAllGood : strings.suggestionsNoData;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(strings.todaySuggestionsTitle, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          if (bullets.isEmpty)
            Text(
              fallbackText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            )
          else
            ...bullets.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: Theme.of(context).textTheme.bodySmall),
                    Expanded(
                      child: Text(line, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 1 dòng breakdown trong _ScoreCard: icon + tên yếu tố + thanh % + số %.
// `percent == null` -> yếu tố CHƯA có dữ liệu hôm nay (khác 0%, xem
// HabitProvider) -> hiện label "Chưa có dữ liệu" + thanh rỗng thay vì 0%
// gây hiểu lầm là "đang tệ".
class _ScoreFactorRow extends StatelessWidget {
  const _ScoreFactorRow({
    required this.icon,
    required this.label,
    required this.percent,
    required this.noDataLabel,
    required this.explanation,
    this.isExperimental = false,
  });

  final String icon;
  final String label;
  final double? percent;
  final String noDataLabel;
  // Giải thích cách tính % của yếu tố này — hiện trong bottom sheet khi
  // người dùng chạm vào dòng này.
  final String explanation;
  // Giữ lại tham số này để tương thích ngược — không còn yếu tố nào dùng
  // isExperimental = true nữa (Khoảng cách đã bị gỡ bỏ), nhưng để đây phòng
  // khi thêm yếu tố thử nghiệm khác trong tương lai.
  final bool isExperimental;

  void _showExplanation(BuildContext context) {
    final strings = context.read<LanguageProvider>().strings;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final hasData = percent != null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIcon(icon, size: 22, color: Theme.of(sheetContext).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      hasData ? '${percent!.round()}%' : strings.scoreFactorNoData,
                      style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                            color: Theme.of(sheetContext).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                if (isExperimental) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      strings.experimentalTag,
                      style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  explanation,
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

  @override
  Widget build(BuildContext context) {
    final hasData = percent != null;
    final displayPercent = (percent ?? 0).round();

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showExplanation(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AppIcon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isExperimental) ...[
              Icon(Icons.science_outlined, size: 12, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.info_outline_rounded,
              size: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: hasData ? (percent! / 100).clamp(0.0, 1.0) : 0,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withValues(alpha: hasData ? 1.0 : 0.35),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text(
                hasData ? '$displayPercent%' : '—',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
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
                      AppIcon(b.$1, size: 18, color: Theme.of(sheetContext).colorScheme.primary),
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

  // Nội suy màu theo ĐIỂM SỐ (không phải theo có/không có dữ liệu như
  // trước): đỏ (kém/chưa có dữ liệu) -> cam -> vàng -> xanh lá (tốt) — nhìn
  // cột là biết ngay hôm đó tốt/xấu, không cần chạm vào xem số. Ngày CHƯA
  // CÓ dữ liệu được coi như điểm 0 cho MỤC ĐÍCH MÀU SẮC (ra màu đỏ, đúng yêu
  // cầu "cột thấp thì đỏ"), tách biệt với chiều cao hiển thị (xem _bar bên
  // dưới — chiều cao có sàn tối thiểu riêng để LUÔN NHÌN THẤY được cột, kể
  // cả điểm 0 thật).
  Color _colorForScore(double score) {
    final clamped = score.clamp(0, 100).toDouble();
    const stops = [
      Colors.redAccent,
      Colors.deepOrange,
      Colors.amber,
      Colors.lightGreen,
      Colors.green,
    ];
    final t = clamped / 100 * (stops.length - 1);
    final index = t.floor().clamp(0, stops.length - 2);
    final localT = t - index;
    return Color.lerp(stops[index], stops[index + 1], localT)!;
  }

  BarChartGroupData _bar(int x, double? y, {bool isToday = false}) {
    // BUG ĐÃ SỬA: bản cũ dùng chiều cao 4.0 CỐ ĐỊNH cho ngày chưa có dữ
    // liệu, cộng màu xám nhạt (AppColors.border) — trên thang maxY=100 cao
    // 132px, 4 đơn vị gần như không nhìn thấy gì, trông như "không có cột".
    // Giờ có SÀN TỐI THIỂU riêng (8 đơn vị, gấp đôi trước) + màu đỏ (điểm 0
    // cho mục đích màu) để LUÔN thấy rõ 1 cột đỏ ngắn thay vì biến mất.
    final rawValue = y ?? 0.0;
    final displayHeight = rawValue < 8.0 ? 8.0 : rawValue;
    final baseColor = _colorForScore(rawValue);
    final topColor = isToday ? baseColor : baseColor.withValues(alpha: 0.75);
    final bottomColor = isToday
        ? Color.lerp(baseColor, Colors.black, 0.15)!
        : Color.lerp(baseColor, Colors.black, 0.15)!.withValues(alpha: 0.75);
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: displayHeight,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [bottomColor, topColor],
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