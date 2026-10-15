import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dialogs/delete_account_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/settings_more_provider.dart';
import '../screens/change_password_screen.dart';
import '../theme/app_colors.dart';
import 'settings_toggle_tile.dart';

class PrivacySecuritySection extends StatelessWidget {
  const PrivacySecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsMoreProvider>();
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final strings = context.watch<LanguageProvider>().strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionLabel(strings.sectionPrivacy),
        SettingsToggleTile(
          title: strings.dataCollectionTitle,
          description: strings.dataCollectionDesc,
          value: settings.dataCollection,
          onChanged: settings.setDataCollection,
        ),
        const Divider(height: 1),
        SettingsToggleTile(
          title: strings.cloudBackupTitle,
          description: strings.cloudBackupDesc,
          value: settings.cloudBackup,
          onChanged: isLoggedIn ? settings.setCloudBackup : null,
        ),
        const Divider(height: 1),
        SettingsToggleTile(
          title: strings.personalizedAiTitle,
          description: strings.personalizedAiDesc,
          value: settings.personalizedAI,
          onChanged: isLoggedIn ? settings.setPersonalizedAI : null,
        ),
        const Divider(height: 1),
        // "Hỏi trước khi AI tự thao tác" — không phụ thuộc đăng nhập, vì đây
        // là quyền kiểm soát hành vi AI trong app, khác với các toggle trên
        // (cloud backup, personalized AI) vốn cần tài khoản để có ý nghĩa.
        SettingsToggleTile(
          title: strings.aiConfirmBeforeActingTitle,
          description: strings.aiConfirmBeforeActingDesc,
          value: settings.aiConfirmBeforeActing,
          onChanged: settings.setAiConfirmBeforeActing,
        ),
        SettingsSectionLabel(strings.sectionSecurity),
        SettingsNavTile(
          title: strings.changePasswordTitle,
          icon: Icons.lock_outline_rounded,
          onTap: isLoggedIn
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  )
              : null,
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.fingerprint_rounded, size: 20),
          title: Text(strings.biometricLoginTitle, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          subtitle: Text(
            isLoggedIn
                ? (settings.biometricSupported ? strings.biometricSupportedDesc : strings.biometricUnsupportedDesc)
                : strings.loginRequired,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          value: settings.biometricLogin,
          onChanged: isLoggedIn && settings.biometricSupported ? settings.setBiometricLogin : null,
        ),
        const Divider(height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.verified_user_outlined, size: 20),
          title: Text(strings.twoFactorAuthTitle, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          subtitle: Text(
            isLoggedIn
                ? (settings.twoFactorAuth ? strings.twoFactorAuthOnDesc : strings.twoFactorAuthOffDesc)
                : strings.loginRequired,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          value: settings.twoFactorAuth,
          onChanged: isLoggedIn ? settings.setTwoFactorAuth : null,
        ),
        SettingsSectionLabel(strings.sectionDataManagement),
        const _DataManagementButtons(),
      ],
    );
  }
}

class _DataManagementButtons extends StatelessWidget {
  const _DataManagementButtons();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsMoreProvider>();
    final strings = context.watch<LanguageProvider>().strings;

    return Column(
      children: [
        _ActionButton(
          label: strings.exportMyData,
          icon: Icons.download_rounded,
          loading: settings.isExporting,
          onPressed: () async {
            await context.read<SettingsMoreProvider>().exportMyData();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.exportMyDataDone)),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: strings.downloadEyeHealthReport,
          icon: Icons.picture_as_pdf_outlined,
          onPressed: () => context.read<SettingsMoreProvider>().downloadEyeHealthReport(),
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: strings.deleteAllLocalData,
          icon: Icons.delete_sweep_outlined,
          loading: settings.isDeletingLocal,
          isDestructiveOutline: true,
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(strings.deleteAllLocalDataTitle),
                content: Text(strings.deleteAllLocalDataDesc),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.cancel)),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: Text(strings.delete)),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await context.read<SettingsMoreProvider>().deleteAllLocalData();
          },
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: strings.deleteAccountAction,
          icon: Icons.person_remove_outlined,
          loading: settings.isDeletingAccount,
          isFilledDestructive: true,
          onPressed: () async {
            final confirmed = await showDeleteAccountDialog(context, strings);
            if (confirmed != true || !context.mounted) return;
            await context.read<SettingsMoreProvider>().deleteAccount();
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.isDestructiveOutline = false,
    this.isFilledDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool loading;
  final bool isDestructiveOutline;
  final bool isFilledDestructive;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const padding = EdgeInsets.symmetric(vertical: 13);

    if (isFilledDestructive) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(backgroundColor: AppColors.error, shape: shape, padding: padding),
          child: child,
        ),
      );
    }
    if (isDestructiveOutline) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
            shape: shape,
            padding: padding,
          ),
          child: child,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(shape: shape, padding: padding),
        child: child,
      ),
    );
  }
}