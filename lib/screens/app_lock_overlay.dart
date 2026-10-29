import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../navigation/root_navigator.dart';
import '../providers/language_provider.dart';
import '../providers/usage_limit_provider.dart';
import '../services/app_usage_monitor.dart';
import '../theme/app_colors.dart';
import '../utils/platform_capability.dart';

/// Kênh native app-lock (MainActivity: canDrawOverlays / showTestOverlay ...).
const MethodChannel _appLockChannel = MethodChannel('eye_care_ai/app_lock');

/// Màn hình khoá toàn màn hình khi hết giờ dùng app (app-lock Phase 1).
/// Không có nút thoát trực tiếp — chỉ có "+5 phút" (1 lần/khóa) hoặc tắt
/// giới hạn ở Settings; đây là rào cản có chủ đích, đúng tinh thần
/// "digital wellbeing".
///
/// Màn hình này được vẽ ĐÈ lên toàn bộ app bởi [AppLockGate] khi
/// `UsageLimitProvider.isLocked` = true. Nút Back của hệ thống không gỡ được
/// màn hình khoá (nó không phải một route) — lối thoát duy nhất là "+5 phút"
/// hoặc tắt giới hạn trong Cài đặt.
class AppLockOverlay extends StatelessWidget {
  const AppLockOverlay({super.key, this.onOpenSettings});

  /// Gọi khi người dùng bấm nút "mở Cài đặt" — gate sẽ tạm ẩn màn hình khoá
  /// để trang Cài đặt (một route bình thường) nhìn thấy được.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final provider = context.watch<UsageLimitProvider>();
    final canGrant = !provider.limit.hasExtraTimeInCurrentLock;

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_clock_outlined, size: 88, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                strings.appLockTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.appLockBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              FilledButton.tonalIcon(
                onPressed: canGrant
                    ? () async {
                        // Cấp thêm 5 phút -> provider cập nhật isLocked = false
                        // -> AppLockGate tự gỡ màn hình khoá. Hết 5 phút mà
                        // vẫn vượt hạn mức thì gate khoá lại (monitor cập nhật
                        // số phút đã dùng mỗi ~60s).
                        await provider.grantExtraTime(DateTime.now());
                        AppUsageMonitor.instance.notifyOverlayClosed();
                      }
                    : null,
                icon: const Icon(Icons.add_alarm_outlined),
                label: Text(strings.appLockGrantFive),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onOpenSettings,
                child: Text(strings.appLockOpenSettings, style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cổng khoá app (app-lock Phase 1).
///
/// Khi `UsageLimitProvider.isLocked` = true, [AppLockOverlay] được vẽ ĐÈ lên
/// TOÀN BỘ app — kể cả các route đã push (Cài đặt, bài kiểm tra mắt...) —
/// nên người dùng không thể dùng tiếp app khi đã hết hạn mức. Đây là
/// enforcement THẬT của app-lock; trước đây gate native được "armed" với
/// danh sách app bị chặn RỖNG nên không bao giờ hiện được (xem
/// lib/services/app_usage_monitor.dart).
///
/// Gate này được gắn vào `MaterialApp.builder` nên nó nằm NGOÀI navigator:
/// mọi route của app đều nằm bên dưới lớp khoá.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  // Đang mở trang Cài đặt app-lock từ màn hình khoá → tạm ẩn màn hình khoá
  // để trang Cài đặt (một route bình thường của app) nhìn thấy được. Quay
  // lại từ Cài đặt mà chưa tắt giới hạn thì màn hình khoá hiện lại.
  bool _settingsOpen = false;

  @override
  Widget build(BuildContext context) {
    final locked = context.watch<UsageLimitProvider>().isLocked;
    if (!locked || _settingsOpen) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(child: AppLockOverlay(onOpenSettings: _openSettings)),
      ],
    );
  }

  /// Mở trang Cài đặt app-lock (nằm trong navigator gốc) để người dùng có
  /// lối thoát thật sự: tắt giới hạn, đổi hạn mức, hoặc xem trước overlay.
  void _openSettings() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    setState(() => _settingsOpen = true);
    navigator
        .push(
          MaterialPageRoute(builder: (_) => const AppLockSettingsSheetHost()),
        )
        .whenComplete(() {
      if (mounted) setState(() => _settingsOpen = false);
    });
  }
}

/// Tạm thời dựng Settings entry làm “host” đơn giản cho lối thoát từ khóa —
/// sẽ thay bằng điều hướng đúng trang Settings khi feature gắn vào
/// settings_screen.dart.
class AppLockSettingsSheetHost extends StatelessWidget {
  const AppLockSettingsSheetHost({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final provider = context.watch<UsageLimitProvider>();

    // iOS không đọc được thời gian dùng mỗi app (không có Usage Access), nên
    // giới hạn ngày không bao giờ chạm hạn mức. Hiện rõ trạng thái thay vì để
    // công tắc/preset/các nút thử overlay nhìn như đang hoạt động.
    if (!hasAndroidNativeFeatures()) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.appLockSettingsTitle)),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                strings.appLockUnavailableOnIOS,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.appLockSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(strings.appLockEnable),
            value: provider.limit.enabled,
            onChanged: (v) => provider.setEnabled(v),
          ),
          if (provider.limit.enabled) ...[
            const Divider(height: 1),
            for (final minutes in const [15, 30, 45, 60, 90, 120])
              RadioListTile<int>(
                title: Text(strings.appLockMinutes(minutes)),
                value: minutes,
                groupValue: provider.limit.dailyLimitMinutes,
                onChanged: (v) {
                  if (v != null) provider.setDailyLimitMinutes(v);
                },
              ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.preview_outlined),
            title: Text(strings.appLockTestTitle),
            subtitle: Text(strings.appLockTestBody),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final vi = context
                  .read<LanguageProvider>()
                  .isVietnamese;
              await _appLockChannel
                  .invokeMethod<void>('setLanguage', {'vi': vi});
              final ok = await _appLockChannel
                  .invokeMethod<bool>('showTestOverlay') ?? false;
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? strings.appLockTestShown
                      : strings.appLockTestDenied),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
