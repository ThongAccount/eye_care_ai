import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/usage_limit_provider.dart';
import '../services/app_usage_monitor.dart';
import '../theme/app_colors.dart';

/// Kênh native app-lock (MainActivity: canDrawOverlays / showTestOverlay ...).
const MethodChannel _appLockChannel = MethodChannel('eye_care_ai/app_lock');

/// Overlay khóa toàn màn hình khi hết giờ dùng app (app-lock Phase 1).
/// Không có nút thoát trực tiếp — chỉ có "+5 phút" (1 lần/khóa) hoặc tắt
/// giới hạn ở Settings; đây là rào cản có chủ đích, đúng tinh thần
/// "digital wellbeing".
class AppLockOverlay extends StatelessWidget {
  const AppLockOverlay({super.key, required this.onDismissed});

  final VoidCallback onDismissed;

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
                    ? () {
                        provider.grantExtraTime(DateTime.now());
                        AppUsageMonitor.instance.notifyOverlayClosed();
                        Navigator.of(context).pop();
                        onDismissed();
                      }
                    : null,
                icon: const Icon(Icons.add_alarm_outlined),
                label: Text(strings.appLockGrantFive),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  onDismissed();
                  // Mở thẳng trang Cài đặt để người dùng có lối thoát thật sự.
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const AppLockSettingsSheetHost()),
                  );
                },
                child: Text(strings.appLockOpenSettings, style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
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