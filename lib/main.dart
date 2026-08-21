import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/accent_color_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/auto_brightness_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/font_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/language_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/rank_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/settings_more_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/setup_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/consent_screen.dart';
import 'screens/eye_break_screen.dart';
import 'screens/habits_survey_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/setup_wizard_screen.dart';
import 'services/analytics_service.dart';
import 'services/dark_room_background_service.dart';
import 'services/device_data_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

// Navigator toàn cục — dùng để điều hướng tới EyeBreakScreen ngay khi người
// dùng nhấn vào thông báo "Đến giờ nghỉ mắt", kể cả khi thông báo được nhấn
// lúc app đang ở nền (không có BuildContext nào sẵn có lúc đó). Đặt ở top
// level (không phải trong 1 State) vì NotificationService (tầng service,
// không có UI) cần gọi được nó thông qua callback onBreakReminderTapped mà
// không phải import ngược lại màn hình.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

void _openEyeBreakScreenFromNotification() {
  final navigator = _rootNavigatorKey.currentState;
  if (navigator == null) return;
  // Tránh chồng nhiều EyeBreakScreen nếu người dùng bấm thông báo nhiều lần
  // liên tiếp (VD báo thức lặp bắn 2 lần trước khi mở thông báo đầu) — quay
  // về route gốc trước rồi mới đẩy EyeBreakScreen lên trên.
  navigator.popUntil((route) => route.isFirst);
  navigator.push(MaterialPageRoute(builder: (_) => const EyeBreakScreen()));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo Firebase/Notification có thể treo vô hạn (config thiếu trên bản
  // cài mới, platform channel chưa sẵn sàng lúc khởi động lạnh) → bọc timeout
  // để app LUÔN thoát khỏi splash, kể cả khi dịch vụ phụ trợ lỗi.
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
  } catch (_) {
    // App vẫn chạy không cần Firebase (analytics/auth tạm vô hiệu).
  }
  NotificationService.instance.onBreakReminderTapped = _openEyeBreakScreenFromNotification;
  try {
    await NotificationService.instance.initialize().timeout(const Duration(seconds: 8));
  } catch (_) {
    // Báo thức nghỉ mắt có thể khởi tạo lại sau khi vào app.
  }
  // Đăng ký kiểm tra "dùng điện thoại trong bóng tối" chạy NỀN ĐỊNH KỲ (mỗi
  // ~15 phút, kể cả khi app đã đóng hẳn) — không await/không có timeout
  // riêng: đây chỉ là ĐĂNG KÝ lịch với hệ thống (rất nhanh), KHÔNG phải bản
  // thân việc kiểm tra (việc đó chạy sau, trong isolate riêng của
  // WorkManager) — lỗi ở đây (ví dụ thiết bị không hỗ trợ) không được làm
  // chậm/kẹt màn hình khởi động app.
  unawaited(DarkRoomBackgroundService.register());

  // Trường hợp app đã bị TẮT HẲN (không chỉ thu nhỏ) và người dùng mở lại
  // bằng cách nhấn vào thông báo "Đến giờ nghỉ mắt": onDidReceiveNotification
  // Response ở trên chỉ bắt được các lần nhấn khi app đã đang chạy — lần khởi
  // động NÀY (do chính cú nhấn thông báo gây ra) phải được phát hiện riêng
  // qua getNotificationAppLaunchDetails().
  final launchDetails = await NotificationService.instance.notifications.getNotificationAppLaunchDetails();
  final launchedFromBreakNotification = launchDetails?.didNotificationLaunchApp == true &&
      launchDetails?.notificationResponse?.payload == NotificationService.breakReminderPayload;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AutoBrightnessProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => AccentColorProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (_) => SettingsMoreProvider()..init(),
        ),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => RankProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SetupProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (_) => ProfileProvider(),
          update: (_, auth, profile) => profile!..syncFromUser(auth.user),
        ),
      ],
      child: EyeCareApp(launchedFromBreakNotification: launchedFromBreakNotification),
    ),
  );
}

class EyeCareApp extends StatefulWidget {
  const EyeCareApp({super.key, this.launchedFromBreakNotification = false});

  final bool launchedFromBreakNotification;

  @override
  State<EyeCareApp> createState() => _EyeCareAppState();
}

class _EyeCareAppState extends State<EyeCareApp> {
  @override
  void initState() {
    super.initState();
    if (widget.launchedFromBreakNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openEyeBreakScreenFromNotification());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final font = context.watch<FontProvider>();
    final accent = context.watch<AccentColorProvider>();
    final isVietnamese = context.watch<LanguageProvider>().isVietnamese;
    final fontTextTheme = font.getTextTheme(isVietnamese);

    return MaterialApp(
      navigatorKey: _rootNavigatorKey,
      title: 'EyeCare AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accentSeed: accent.seedColor, fontTextTheme: fontTextTheme),
      darkTheme: AppTheme.dark(accentSeed: accent.seedColor, fontTextTheme: fontTextTheme),
      themeMode: theme.themeMode,
      home: const _AppGate(),
    );
  }
}

class AppLoadingSkeleton extends StatelessWidget {
  const AppLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE9EEF7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _SkeletonBlock(width: 180, height: 18),
              const SizedBox(height: 24),
              _SkeletonCard(),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Expanded(child: _SkeletonCard(height: 120)),
                  SizedBox(width: 12),
                  Expanded(child: _SkeletonCard(height: 120)),
                  SizedBox(width: 12),
                  Expanded(child: _SkeletonCard(height: 120)),
                ],
              ),
              const SizedBox(height: 20),
              _SkeletonBlock(width: 160, height: 18),
              const SizedBox(height: 12),
              const _SkeletonCard(height: 170),
              const SizedBox(height: 14),
              const _SkeletonCard(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({this.height = 90});
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final highlight = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 120, height: 12, decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 12),
            Container(width: 220, height: 10, decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 8),
            Container(width: 180, height: 10, decoration: BoxDecoration(color: highlight, borderRadius: BorderRadius.circular(999))),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  late final Future<bool> _surveyCompletedFuture;
  late final Future<bool> _consentGivenFuture;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _surveyCompletedFuture = DeviceDataService.instance
        .isSurveyCompleted()
        .timeout(const Duration(seconds: 8))
        .catchError((_) => false);
    _consentGivenFuture = AnalyticsService.instance
        .init()
        .then((_) => AnalyticsService.instance.consentGiven)
        .timeout(const Duration(seconds: 8))
        .catchError((_) => false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestDeferredSystemPermissions();
    });
  }

  // BUG ĐÃ SỬA: dùng context.watch<AuthProvider>() bên trong builder của
  // FutureBuilder không đảm bảo rebuild _AppGate mỗi lần AuthProvider đổi
  // trạng thái (đã xác nhận qua debug log: notifyListeners() chạy đúng
  // nhưng widget không build lại) — có thể do context của FutureBuilder
  // không được Provider gắn subscription đúng cách trong 1 số trường hợp.
  // Giải pháp chắc chắn: tự addListener() trực tiếp vào AuthProvider và gọi
  // setState() thủ công, không phụ thuộc vào cơ chế watch/InheritedWidget.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(_authProvider, auth)) {
      _authProvider?.removeListener(_onAuthChanged);
      _authProvider = auth;
      _authProvider!.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _consentGivenFuture,
      builder: (context, consentSnapshot) {
        if (!consentSnapshot.hasData) {
          return const AppLoadingSkeleton();
        }
        // Consent not given → show consent screen
        if (consentSnapshot.data != true) {
          return const ConsentScreen();
        }
        // Consent given → check survey
        return FutureBuilder<bool>(
          future: _surveyCompletedFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AppLoadingSkeleton();
            }
            if (snapshot.data == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<HabitProvider>().setSurveyCompleted(true);
              });
              final authProvider = context.read<AuthProvider>();
              // Đợi Firebase Auth khôi phục xong phiên đăng nhập cũ (xem
              // giải thích ở AuthProvider.authReady) trước khi quyết định
              // hiện LoginScreen — nếu không, người dùng ĐÃ đăng nhập từ
              // trước vẫn có thể bị "chớp" ra màn đăng nhập oan mỗi lần mở
              // app do đọc currentUser quá sớm.
              if (!authProvider.authReady) {
                return const AppLoadingSkeleton();
              }
              if (!authProvider.isLoggedIn) {
                return const LoginScreen();
              }

              final setup = context.watch<SetupProvider>();
              if (setup.loading) {
                return const AppLoadingSkeleton();
              }
              return setup.wizardCompleted ? const MainShell() : const SetupWizardScreen();
            }
            return const HabitsSurveyScreen(mandatory: true);
          },
        );
      },
    );
  }
}