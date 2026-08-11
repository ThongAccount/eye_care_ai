import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../providers/setup_provider.dart';
import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../services/usage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/app_icon.dart';
import '../utils/permission_helper.dart';
import 'main_shell.dart';

/// First-Time Setup Wizard — chuỗi màn hình xin quyền TUẦN TỰ (usage access
/// -> notifications -> vị trí -> hoạt động -> popup toàn màn hình -> chạy
/// nền -> focus mode), hiện đúng 1 lần sau khi đăng nhập lần đầu (xem
/// main.dart _AppGate). Mỗi bước quyền đều có thể "Bỏ qua" — không có bước
/// nào là điều kiện bắt buộc để vào app, khác với
/// HabitsSurveyScreen(mandatory: true). Quyền bỏ qua ở đây vẫn có thể cấp
/// lại sau qua banner ở Home (xem widgets/setup_status_banner.dart).
///
/// BỎ bước "Giấc ngủ" (Health Connect) — Sleep giờ suy ra từ chính Usage
/// Access ở bước đầu, không cần quyền riêng nữa (xem device_data_service.dart).
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _requesting = false;

  // Usage Access, Popup toàn màn hình, Chạy nền, và Focus Mode là quyền
  // "đặc biệt" của Android — không có popup xin quyền tại chỗ, phải đưa
  // người dùng SANG màn hình Cài đặt hệ thống rồi họ tự bật, sau đó quay
  // lại app. Lúc quay lại (didChangeAppLifecycleState resumed) là thời
  // điểm duy nhất biết được họ vừa bật hay chưa -> phải refresh lại trạng
  // thái ngay lúc đó.
  late final List<_StepConfig> _steps = [
    _StepConfig(
      id: SetupStepId.usageAccess,
      emoji: '📊',
      title: (s) => s.setupStepUsageTitle,
      body: (s) => s.setupStepUsageBody,
      onGrant: () async => UsageService.openPermissionSettings(),
      opensExternalSettings: true,
    ),
    _StepConfig(
      id: SetupStepId.notifications,
      emoji: '🔔',
      title: (s) => s.setupStepNotificationsTitle,
      body: (s) => s.setupStepNotificationsBody,
      onGrant: () => NotificationService.instance.requestNotificationPermission(),
    ),
    _StepConfig(
      id: SetupStepId.location,
      emoji: '📍',
      title: (s) => s.setupStepLocationTitle,
      body: (s) => s.setupStepLocationBody,
      onGrant: () => PermissionHelper.requestLocationPermission(),
    ),
    _StepConfig(
      id: SetupStepId.activityRecognition,
      emoji: '🏃',
      title: (s) => s.setupStepActivityTitle,
      body: (s) => s.setupStepActivityBody,
      onGrant: () => PermissionHelper.requestActivityPermission(),
    ),
    _StepConfig(
      id: SetupStepId.fullScreenIntent,
      emoji: '⏰',
      title: (s) => s.setupStepFullScreenTitle,
      body: (s) => s.setupStepFullScreenBody,
      onGrant: () => NotificationService.instance.openFullScreenIntentSettings(),
      opensExternalSettings: true,
    ),
    _StepConfig(
      id: SetupStepId.batteryOptimization,
      emoji: '🔋',
      title: (s) => s.setupStepBatteryTitle,
      body: (s) => s.setupStepBatteryBody,
      onGrant: () => NotificationService.instance.requestIgnoreBatteryOptimizations(),
      opensExternalSettings: true,
    ),
    _StepConfig(
      id: SetupStepId.focusMode,
      emoji: '🌙',
      title: (s) => s.setupStepFocusModeTitle,
      body: (s) => s.setupStepFocusModeBody,
      onGrant: () => FocusModeService.instance.openAccessSettings(),
      opensExternalSettings: true,
    ),
    _StepConfig(
      id: SetupStepId.overlay,
      emoji: '🪟',
      title: (s) => s.setupStepOverlayTitle,
      body: (s) => s.setupStepOverlayBody,
      onGrant: () => PermissionHelper.openOverlaySettings(),
      opensExternalSettings: true,
    ),
  ];

  // +2: trang Welcome ở đầu, trang Done ở cuối.
  int get _totalPages => _steps.length + 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SetupProvider>().refreshStatus();
    }
  }

  void _goTo(int index) {
    setState(() => _pageIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    final setup = context.read<SetupProvider>();
    await setup.markWizardCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const _WizardExitBridge()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final setup = context.watch<SetupProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _ProgressDots(current: _pageIndex, total: _totalPages),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _pageIndex = i),
                children: [
                  _WelcomePage(strings: strings, onStart: () => _goTo(1)),
                  for (final step in _steps)
                    _PermissionStepPage(
                      strings: strings,
                      step: step,
                      granted: setup.isGranted(step.id),
                      requesting: _requesting,
                      onGrant: () async {
                        // BUG ĐÃ SỬA (use_build_context_synchronously): lấy sẵn
                        // reference SetupProvider TRƯỚC khi await, thay vì gọi
                        // context.read<SetupProvider>() SAU await step.onGrant()
                        // — gọi context sau 1 gap bất đồng bộ như vậy có thể
                        // dùng phải BuildContext của widget đã bị dispose (ví dụ
                        // người dùng thoát màn hình đúng lúc đang chờ). Capture
                        // trước thì không còn đụng tới BuildContext sau await
                        // nữa, không cần cả "mounted" check cho dòng này.
                        final setupProvider = context.read<SetupProvider>();
                        setState(() => _requesting = true);
                        try {
                          await step.onGrant();
                          if (!step.opensExternalSettings) {
                            await setupProvider.refreshStatus();
                          }
                        } finally {
                          if (mounted) setState(() => _requesting = false);
                        }
                      },
                      onNext: () => _goTo(_pageIndex + 1),
                    ),
                  _DonePage(
                    strings: strings,
                    granted: setup.grantedCount,
                    total: setup.totalCount,
                    onFinish: _finish,
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

// Sau khi đánh dấu wizardCompleted, thay thẳng toàn bộ stack điều hướng bằng
// MainShell thay vì pop về root. Hai lý do:
//  1. pushReplacement ở _skipLoginForNow/_finish đã làm wizard và bridge trở
//     thành route root — popUntil(route.isFirst) chỉ tự pop === KHÔNG LÀM GÌ,
//     để lại bridge (CircularProgressIndicator) mắc kẹt vĩnh viễn (bug spinner
//     sau wizard, xác nhận bằng ECAI log build 48).
//  2. Người dùng đã đi qua cổng đăng nhập TRƯỚC wizard rồi (đăng nhập thật
//     hoặc "Bỏ qua, dùng thử trước") — quay lại LoginScreen sau wizard là
//     màn đăng nhập THỨ HAI (bug user báo: "2 signins"). Đích đúng sau
//     wizard LUÔN là MainShell: khách chạy local (cloud backup tự bỏ qua khi
//     chưa đăng nhập), người đăng nhập rồi thì đã có session Firebase.
class _WizardExitBridge extends StatelessWidget {
  const _WizardExitBridge();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _StepConfig {
  const _StepConfig({
    required this.id,
    required this.emoji,
    required this.title,
    required this.body,
    required this.onGrant,
    this.opensExternalSettings = false,
  });

  final SetupStepId id;
  final String emoji;
  final String Function(AppStrings) title;
  final String Function(AppStrings) body;
  final Future<void> Function() onGrant;
  // true = bấm "Cấp quyền" sẽ rời app sang màn Cài đặt hệ thống (usage
  // access, focus mode) -> không refresh ngay lập tức được, phải đợi
  // didChangeAppLifecycleState(resumed) ở màn cha bắt được lúc quay lại.
  final bool opensExternalSettings;
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? primary : primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.strings, required this.onStart});

  final AppStrings strings;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: AppTheme.gradientFor(primary),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('👋', style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 28),
          Text(
            strings.setupWelcomeTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          Text(
            strings.setupWelcomeBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onStart, child: Text(strings.setupGetStarted)),
          ),
        ],
      ),
    );
  }
}

class _PermissionStepPage extends StatelessWidget {
  const _PermissionStepPage({
    required this.strings,
    required this.step,
    required this.granted,
    required this.requesting,
    required this.onGrant,
    required this.onNext,
  });

  final AppStrings strings;
  final _StepConfig step;
  final bool granted;
  final bool requesting;
  final VoidCallback onGrant;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon(step.emoji, size: 40, color: primary),
          ),
          const SizedBox(height: 24),
          Text(
            step.title(strings),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            step.body(strings),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: granted
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, color: AppColors.success),
                    label: Text(strings.setupGranted),
                  )
                : FilledButton(
                    onPressed: requesting ? null : onGrant,
                    child: requesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(strings.setupGrantButton),
                  ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onNext,
            child: Text(granted ? strings.setupNextStep : strings.setupSkipStep),
          ),
        ],
      ),
    );
  }
}

class _DonePage extends StatelessWidget {
  const _DonePage({
    required this.strings,
    required this.granted,
    required this.total,
    required this.onFinish,
  });

  final AppStrings strings;
  final int granted;
  final int total;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          Text(
            strings.setupDoneTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            strings.setupDoneBody(granted, total),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onFinish, child: Text(strings.setupFinish)),
          ),
        ],
      ),
    );
  }
}
