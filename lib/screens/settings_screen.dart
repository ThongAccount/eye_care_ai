import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_icon.dart';
import '../utils/permission_helper.dart';

import '../models/app_strings.dart';
import '../providers/accent_color_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/font_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/smart_brightness_dialog.dart';
import '../widgets/update_dialog.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'settings_more_page.dart';

// SettingsScreen là màn hình cài đặt chính của ứng dụng.
// Mục tiêu của màn hình này là cho phép người dùng thay đổi:
// - màu nền (Dark Mode)
// - đơn vị đo lường (Metric / Imperial)
// - định dạng giờ (12h / 24h)
// - ngôn ngữ (Tiếng Việt / English)
//
// Cách hoạt động:
// - Lấy các provider theo trách nhiệm riêng biệt.
// - Dùng LanguageProvider để lấy text phù hợp với ngôn ngữ hiện tại.
// - Gọi các provider tương ứng để thay đổi cài đặt và update UI.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mỗi provider chỉ cung cấp dữ liệu và thao tác thuộc trách nhiệm riêng.
    final theme = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>();
    final accent = context.watch<AccentColorProvider>();
    final font = context.watch<FontProvider>();
    final strings = language.strings;
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: language.isVietnamese ? 'Quay lại' : 'Back',
        ),
        title: Text(strings.settings),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              SectionCard(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                        child: profile.avatarUrl == null
                            ? Text(
                                profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '👤',
                                style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.name.isEmpty ? '—' : profile.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              profile.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(strings.notifications, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              // Phần thông báo: bật/tắt các loại nhắc nhở khác nhau.
              // Mỗi dòng gọi _ToggleTile với dữ liệu và callback riêng.
              _ToggleTile(
                icon: '☕',
                title: strings.breakReminders,
                subtitle: strings.breakRemindersSubtitle,
                value: settings.notifyBreaks,
                onChanged: (v) => settings.setNotification('breaks', v),
              ),
              _ToggleTile(
                icon: '👁️',
                title: strings.eyeTestReminders,
                subtitle: strings.eyeTestRemindersSubtitle,
                value: settings.notifyTests,
                onChanged: (v) => settings.setNotification('tests', v),
              ),
              _ToggleTile(
                icon: '✅',
                title: strings.habitTracking,
                subtitle: strings.habitTrackingSubtitle,
                value: settings.notifyHabits,
                onChanged: (v) => settings.setNotification('habits', v),
              ),
              _ToggleTile(
                icon: '💡',
                title: strings.aiTips,
                subtitle: strings.aiTipsSubtitle,
                value: settings.notifyTips,
                onChanged: (v) => settings.setNotification('tips', v),
              ),
              const SizedBox(height: 20),
              // Phần tùy chọn chính: chế độ tối, đơn vị đo lường, định dạng giờ, ngôn ngữ.
              // Các lựa chọn này thay đổi bố cục hiển thị của ứng dụng.
              Text(strings.preferences, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cột bên trái: lựa chọn đơn vị đo lường.
                                // Chọn Metric hoặc Imperial để thay đổi cách hiển thị đơn vị.
                                Text(strings.measurementUnits, style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 8),
                                _SelectableOption(
                                  label: strings.metricMeters,
                                  selected: settings.useMetric,
                                  onTap: () => settings.toggleMetric(true),
                                ),
                                const SizedBox(height: 8),
                                _SelectableOption(
                                  label: strings.imperialFeet,
                                  selected: !settings.useMetric,
                                  onTap: () => settings.toggleMetric(false),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cột bên phải: lựa chọn định dạng ngày/giờ.
                                // Phần này thay đổi định dạng hiển thị giờ trong toàn bộ app.
                                Text(strings.dateTime, style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 8),
                                _SelectableOption(
                                  label: strings.hour12,
                                  selected: !settings.is24Hour,
                                  onTap: () => settings.toggleTimeFormat(false),
                                ),
                                const SizedBox(height: 8),
                                _SelectableOption(
                                  label: strings.hour24,
                                  selected: settings.is24Hour,
                                  onTap: () => settings.toggleTimeFormat(true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _ListTileOption(
                      icon: '🌐',
                      title: strings.language,
                      subtitle: strings.languageSubtitle,
                      valueLabel: language.isVietnamese ? strings.vietnamese : strings.english,
                      onTap: () => _showLanguageDialog(context, language, strings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 📱 Màn hình: các cài đặt ảnh hưởng trực tiếp tới ánh sáng màn
              // hình — tách riêng khỏi "Tùy chọn" chung ở trên vì đây đều là
              // cài đặt liên quan tới MẮT (mỏi mắt do sáng/tối không phù hợp).
              Text(strings.screenSection, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ListTileOption(
                      icon: '💡',
                      title: strings.brightnessTips,
                      subtitle: strings.brightnessTipsSubtitle,
                      valueLabel: '',
                      onTap: () => SmartBrightnessDialog.show(context, strings),
                    ),
                    const Divider(height: 1, indent: 56),
                    _ListTileOption(
                      icon: isDark ? '🌙' : '☀️',
                      title: strings.themeLabel,
                      subtitle: strings.themeSubtitle,
                      valueLabel: strings.themePreferenceLabel(theme.preference),
                      onTap: () => _showThemeDialog(context, theme, strings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(strings.eyeCareSettingVisionProfile, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ListTileOption(
                      icon: '👓',
                      title: strings.eyeCareSettingVisionProfile,
                      subtitle: strings.eyeCareSettingVisionProfile,
                      valueLabel: _visionProfileLabel(settings.visionProfile, strings),
                      onTap: () => _showVisionProfileDialog(context, settings, strings),
                    ),
                    const Divider(height: 1, indent: 56),
                    _ListTileOption(
                      icon: '🎯',
                      title: strings.eyeCareSettingReminderStyle,
                      subtitle: strings.eyeCareSettingReminderStyle,
                      valueLabel: _reminderStyleLabel(settings.reminderStyle, strings),
                      onTap: () => _showReminderStyleDialog(context, settings, strings),
                    ),
                    const Divider(height: 1, indent: 56),
                    _ListTileOption(
                      icon: '📍',
                      title: strings.eyeCareSettingViewingDistance,
                      subtitle: strings.eyeCareSettingViewingDistance,
                      valueLabel: _viewingDistanceLabel(settings.viewingDistanceMode, strings),
                      onTap: () => _showViewingDistanceDialog(context, settings, strings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Giao diện & màu sắc: đổi màu nhấn toàn app + chọn phông chữ, để
              // trải nghiệm đa dạng/đầy màu sắc hơn thay vì chỉ có 1 theme cố định.
              Text(strings.appearanceSection, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.accentColorLabel, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      strings.accentColorSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 10,
                      children: AppAccentColor.values.map((c) {
                        final selected = accent.choice == c;
                        return _AccentColorSwatch(
                          color: c.seed,
                          selected: selected,
                          label: c.label(strings.vi),
                          onTap: () => accent.setChoice(c),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 32),
                    _ListTileOption(
                      icon: '🔤',
                      title: strings.fontLabel,
                      subtitle: strings.fontSubtitleOther,
                      valueLabel: font.effectiveChoice(language.isVietnamese).label(strings.vi),
                      onTap: () => _showFontDialog(context, font, strings, isVietnamese: language.isVietnamese),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(strings.more, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ListTileOption(
                      icon: '🛡️',
                      title: strings.guardianEmailTitle,
                      subtitle: strings.guardianEmailHint,
                      valueLabel: settings.guardianEmail.isNotEmpty ? settings.guardianEmail : strings.guardianEmailAdd,
                      valueOnNewLine: true,
                      onTap: () => _showGuardianEmailDialog(context, settings, strings),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuItem(
                      icon: '🔒',
                      title: strings.privacySecurity,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsMorePage(initialSection: SettingsMoreSection.privacy),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuItem(
                      icon: '📋',
                      title: strings.termsOfService,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsMorePage(initialSection: SettingsMoreSection.terms),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuItem(
                      icon: '❓',
                      title: strings.helpSupport,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsMorePage(initialSection: SettingsMoreSection.help),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuItem(
                      icon: '📊',
                      title: strings.dataUsagePermissions,
                      onTap: () => _showPermissionSettings(context),
                    ),
                    const Divider(height: 1, indent: 56),
                    _MenuItem(
                      icon: '🚪',
                      title: strings.signOut,
                      color: AppColors.error,
                      // Chuyển hướng THẲNG sang LoginScreen, không trông chờ
                      // _AppGate tự rebuild theo AuthProvider (đúng cơ chế
                      // mong manh từng gây bug hệt vậy ở màn đăng nhập).
                      onTap: () async {
                        await context.read<AuthProvider>().signOut();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  strings.version,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: _CheckForUpdateButton()),
            ],
          ),
        ),
      ),
    );
  }
}

// Nút "Kiểm tra bản cập nhật" thủ công — dùng CHUNG UpdateService/UpdateDialog
// với luồng tự động kiểm tra lúc mở app (main_shell.dart), chỉ khác là:
// (1) người dùng chủ động bấm thay vì tự động lúc mở app, (2) LUÔN cho phản
// hồi rõ ràng dù có bản mới hay không — tự động thì im lặng nếu không có gì
// mới, nhưng bấm nút thủ công mà không thấy gì xảy ra sẽ giống app bị đứng.
class _CheckForUpdateButton extends StatefulWidget {
  const _CheckForUpdateButton();

  @override
  State<_CheckForUpdateButton> createState() => _CheckForUpdateButtonState();
}

class _CheckForUpdateButtonState extends State<_CheckForUpdateButton> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final update = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);

    final strings = context.read<LanguageProvider>().strings;
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noUpdateAvailable)),
      );
      return;
    }
    if (!mounted) return;
    UpdateDialog.show(context, update, strings);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return TextButton.icon(
      onPressed: _checking ? null : _check,
      icon: _checking
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh_rounded, size: 18),
      label: Text(strings.checkForUpdate),
    );
  }
}

// Widget tái sử dụng cho từng dòng cài đặt bật/tắt.
// Widget này hiển thị icon, tiêu đề, mô tả và công tắc.
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Row(
          children: [
            AppIcon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              activeThumbColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}


// Vòng tròn màu để chọn accent color — có animation nhún nhẹ + viền check
// khi được chọn, giúp giao diện Settings cảm giác sống động/mượt hơn.
class _AccentColorSwatch extends StatelessWidget {
  const _AccentColorSwatch({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: selected ? 44 : 36,
            height: selected ? 44 : 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: selected ? 0.4 : 0),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.color,
    this.onTap,
  });

  final String icon;
  final String title;
  final Color? color;
  final VoidCallback? onTap;
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AppIcon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color ?? AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableOption extends StatelessWidget {
  const _SelectableOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? Theme.of(context).colorScheme.primary : null,
                    ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _ListTileOption extends StatelessWidget {
  const _ListTileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.onTap,
    this.valueOnNewLine = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String valueLabel;
  final VoidCallback onTap;
  // BUG ĐÃ SỬA: chuỗi dài (ví dụ email "anhkhoa1572@gmail.com") nhét vào
  // Text(valueLabel) không giới hạn chiều rộng bên phải Row -> nó "giành"
  // hết chỗ theo độ dài chuỗi, ép cột tiêu đề bên trái (Expanded) co lại
  // còn vài pixel -> chữ tiêu đề bị bẻ xuống dòng theo TỪNG KÝ TỰ một. Bật
  // cờ này để hiện valueLabel trên MỘT DÒNG RIÊNG bên dưới subtitle, không
  // giới hạn độ dài, thay vì nhét chung 1 hàng ngang với tiêu đề.
  final bool valueOnNewLine;

  @override
  Widget build(BuildContext context) {
    if (valueOnNewLine) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(icon, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    if (valueLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        valueLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AppIcon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            // Giới hạn tối đa 120px + cắt "..." nếu dài hơn, không cho phép
            // chiếm chỗ vô hạn của cột tiêu đề bên trái nữa.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                valueLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

String _visionProfileLabel(String value, AppStrings strings) {
  switch (value) {
    case 'glasses':
      return strings.eyeCareSettingVisionGlasses;
    case 'contact_lens':
      return strings.eyeCareSettingVisionContacts;
    case 'no_correction':
      return strings.eyeCareSettingVisionNoCorrection;
    default:
      return strings.eyeCareSettingVisionGlasses;
  }
}

String _reminderStyleLabel(String value, AppStrings strings) {
  switch (value) {
    case 'gentle':
      return strings.eyeCareSettingStyleGentle;
    case 'normal':
      return strings.eyeCareSettingStyleNormal;
    case 'strict':
      return strings.eyeCareSettingStyleStrict;
    default:
      return strings.eyeCareSettingStyleGentle;
  }
}

String _viewingDistanceLabel(String value, AppStrings strings) {
  switch (value) {
    case 'auto':
      return strings.eyeCareSettingDistanceAuto;
    case 'manual':
      return strings.eyeCareSettingDistanceManual;
    default:
      return strings.eyeCareSettingDistanceAuto;
  }
}

Future<void> _showVisionProfileDialog(BuildContext context, SettingsProvider settings, AppStrings strings) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (context) {
      final options = [
        ('glasses', strings.eyeCareSettingVisionGlasses),
        ('contact_lens', strings.eyeCareSettingVisionContacts),
        ('no_correction', strings.eyeCareSettingVisionNoCorrection),
      ];

      return SimpleDialog(
        title: Text(strings.eyeCareSettingVisionProfile),
        children: options.map((option) {
          final isSelected = settings.visionProfile == option.$1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option.$1),
            child: Row(
              children: [
                if (isSelected)
                  Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(option.$2)),
              ],
            ),
          );
        }).toList(),
      );
    },
  );

  if (selected != null) {
    await settings.setVisionProfile(selected);
  }
}

Future<void> _showReminderStyleDialog(BuildContext context, SettingsProvider settings, AppStrings strings) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (context) {
      final options = [
        ('gentle', strings.eyeCareSettingStyleGentle),
        ('normal', strings.eyeCareSettingStyleNormal),
        ('strict', strings.eyeCareSettingStyleStrict),
      ];

      return SimpleDialog(
        title: Text(strings.eyeCareSettingReminderStyle),
        children: options.map((option) {
          final isSelected = settings.reminderStyle == option.$1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option.$1),
            child: Row(
              children: [
                if (isSelected)
                  Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(option.$2)),
              ],
            ),
          );
        }).toList(),
      );
    },
  );

  if (selected != null) {
    await settings.setReminderStyle(selected);
  }
}

Future<void> _showViewingDistanceDialog(BuildContext context, SettingsProvider settings, AppStrings strings) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (context) {
      final options = [
        ('auto', strings.eyeCareSettingDistanceAuto),
        ('manual', strings.eyeCareSettingDistanceManual),
      ];

      return SimpleDialog(
        title: Text(strings.eyeCareSettingViewingDistance),
        children: options.map((option) {
          final isSelected = settings.viewingDistanceMode == option.$1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option.$1),
            child: Row(
              children: [
                if (isSelected)
                  Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(option.$2)),
              ],
            ),
          );
        }).toList(),
      );
    },
  );

  if (selected != null) {
    await settings.setViewingDistanceMode(selected);
  }
}

Future<void> _showGuardianEmailDialog(BuildContext context, SettingsProvider settings, AppStrings strings) async {
  final controller = TextEditingController(text: settings.guardianEmail);
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(strings.guardianEmailTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: strings.guardianEmailAdd,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return strings.guardianEmailAdd;
                  }
                  final email = value.trim();
                  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
                  return valid ? null : 'Email không hợp lệ';
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final email = controller.text.trim();
                    if (email.isEmpty) return;
                    final uri = Uri.parse(
                      'mailto:$email?cc=eyecareai.app@gmail.com&subject=${Uri.encodeComponent(strings.vi ? 'EyeCare AI - Nhắc nhở sử dụng thiết bị' : 'EyeCare AI - Device usage reminder')}&body=${Uri.encodeComponent(strings.vi ? 'Xin chào,\n\nHệ thống EyeCare AI đã phát hiện người dùng đã dùng thiết bị quá giờ khuyến nghị. Vui lòng kiểm tra và nhắc nhở họ nghỉ ngơi.\n\nTrân trọng,\nEyeCare AI' : 'Hello,\n\nEyeCare AI detected that the user exceeded the recommended screen time. Please check in and remind them to take a break.\n\nRegards,\nEyeCare AI')}',
                    );
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: Text(strings.guardianEmailSendTest),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(strings.cancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(strings.save),
          ),
        ],
      );
    },
  );

  if (result == true) {
    await settings.setGuardianEmail(controller.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.guardianEmailSaved)),
      );
    }
  }
}

Future<void> _showThemeDialog(BuildContext context, ThemeProvider theme, AppStrings strings) async {
  final selected = await showDialog<AppThemePreference>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text(strings.themeLabel),
        children: AppThemePreference.values.map((pref) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, pref),
            child: Row(
              children: [
                if (theme.preference == pref)
                  Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(strings.themePreferenceLabel(pref)),
              ],
            ),
          );
        }).toList(),
      );
    },
  );

  if (selected != null) {
    theme.setPreference(selected);
  }
}

Future<void> _showLanguageDialog(BuildContext context, LanguageProvider language, AppStrings strings) async {
  final selected = await showDialog<bool>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text(strings.selectOption),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.english),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.vietnamese),
          ),
        ],
      );
    },
  );

  if (selected != null) {
    language.toggleVietnamese(selected);
  }
}

// Hộp thoại chọn font — hiện chữ mẫu thật của từng font (dùng đúng
// GoogleFonts.xxx() cho preview) để người dùng thấy hình dạng trước khi
// chọn, thay vì chỉ đọc tên font suông. Khi ngôn ngữ là Tiếng Việt, danh
// sách CHỈ hiện các font đã kiểm chứng hỗ trợ tiếng Việt — tránh lỗi hiển
// thị dấu thay vì hiển thị đủ 8 font rồi để người dùng tự chọn nhầm.
Future<void> _showFontDialog(
  BuildContext context,
  FontProvider font,
  AppStrings strings, {
  required bool isVietnamese,
}) async {
  final options = font.availableFor(isVietnamese);
  final selected = await showDialog<AppFontChoice>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text(strings.fontLabel),
        children: [
          if (isVietnamese)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                strings.fontLockedToVietnameseNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ...options.map((f) {
            final isSelected = font.effectiveChoice(isVietnamese) == f;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f),
              child: Row(
                children: [
                  if (isSelected)
                    Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f.label(false))),
                  Text(
                    f.previewText,
                    style: font.getAppBarTitleStyle(isVietnamese, color: AppColors.textMuted).copyWith(fontSize: 14),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    },
  );

  if (selected != null) {
    font.setChoice(selected);
  }
}

// THÊM HÀM NÀY VÀO CUỐI FILE
void _showPermissionSettings(BuildContext context) {
  final strings = context.read<LanguageProvider>().strings;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (context) {
      return FutureBuilder<Map<String, bool>>(
        future: PermissionHelper.checkAllPermissions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 300,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          Map<String, bool> permissions = snapshot.data!;

          return StatefulBuilder(
            builder: (context, setState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          strings.dataUsagePermissions,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),

                        const SizedBox(height: 24),

                        _PermissionTile(
                          icon: '📱',
                          title: strings.permUsageTitle,
                          description: strings.permUsageDesc,
                          isGranted: permissions["usage"] ?? false,
                          grantedLabel: strings.permGranted,
                          notGrantedLabel: strings.permNotGranted,
                          helpLabel: strings.permGuideButton,
                          onHelp: () => _showUsagePermissionGuide(context, strings),
                          onTap: () async {
                            await PermissionHelper.requestUsagePermission();

                            permissions =
                                await PermissionHelper.checkAllPermissions();

                            setState(() {});
                          },
                        ),

                        const Divider(),

                        _PermissionTile(
                          icon: '📍',
                          title: strings.permLocationTitle,
                          description: strings.permLocationDesc,
                          isGranted: permissions["location"] ?? false,
                          grantedLabel: strings.permGranted,
                          notGrantedLabel: strings.permNotGranted,
                          onTap: () async {
                            await PermissionHelper.requestLocationPermission();

                            permissions =
                                await PermissionHelper.checkAllPermissions();

                            setState(() {});
                          },
                        ),

                        const Divider(),

                        _PermissionTile(
                          icon: '🏃',
                          title: strings.permActivityTitle,
                          description: strings.permActivityDesc,
                          isGranted: permissions["activity"] ?? false,
                          grantedLabel: strings.permGranted,
                          notGrantedLabel: strings.permNotGranted,
                          onTap: () async {
                            await PermissionHelper.requestActivityPermission();

                            permissions =
                                await PermissionHelper.checkAllPermissions();

                            setState(() {});
                          },
                        ),

                        const Divider(),

                        // Android 14+ có công tắc riêng "Hiển thị toàn màn
                        // hình" cho từng app — nếu tắt, thông báo hết-giờ-
                        // nghỉ-mắt chỉ hiện như thông báo thường thay vì bật
                        // pop-up toàn màn hình giống báo thức. Luôn hiển thị
                        // tile này (không kiểm tra trạng thái) vì không có
                        // API công khai đọc được trạng thái công tắc đó.
                        _PermissionTile(
                          icon: '⏰',
                          title: strings.permFullScreenAlertTitle,
                          description: strings.permFullScreenAlertDesc,
                          isGranted: true,
                          grantedLabel: strings.permManage,
                          notGrantedLabel: strings.permManage,
                          onTap: () async {
                            await NotificationService.instance.openFullScreenIntentSettings();
                          },
                        ),

                        const Divider(),

                        // Nhiều hãng máy (Xiaomi/OPPO/Vivo/Samsung...) tự
                        // đóng băng app đứng yên trong nền để tiết kiệm pin,
                        // khiến báo thức nghỉ mắt bị trễ hoặc im lặng dù đã
                        // cấp đủ các quyền ở trên. Đây là công tắc quan
                        // trọng nhất để "chạy nền" đáng tin cậy.
                        _PermissionTile(
                          icon: '🔋',
                          title: strings.permBatteryTitle,
                          description: strings.permBatteryDesc,
                          isGranted: true,
                          grantedLabel: strings.permManage,
                          notGrantedLabel: strings.permManage,
                          onTap: () async {
                            await NotificationService.instance.requestIgnoreBatteryOptimizations();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

// Hướng dẫn cấp quyền "Truy cập dữ liệu sử dụng" theo từng hãng máy
void _showUsagePermissionGuide(BuildContext context, AppStrings strings) {
  final brands = <_GuideBrand>[
    _GuideBrand(strings.permGuideXiaomiTitle, strings.permGuideXiaomiSteps),
    _GuideBrand(strings.permGuideSamsungTitle, strings.permGuideSamsungSteps),
    _GuideBrand(strings.permGuideOppoTitle, strings.permGuideOppoSteps),
    _GuideBrand(strings.permGuideStockTitle, strings.permGuideStockSteps),
    _GuideBrand(strings.permGuideIosTitle, strings.permGuideIosSteps),
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DefaultTabController(
        length: brands.length,
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    strings.permGuideTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    strings.permGuideIntro,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: brands
                      .map((b) => Tab(text: b.title))
                      .toList(),
                ),
                Expanded(
                  child: TabBarView(
                    children: brands.map((b) {
                      return SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          b.steps,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _GuideBrand {
  const _GuideBrand(this.title, this.steps);
  final String title;
  final String steps;
}

// THÊM WIDGET _PermissionTile
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
    required this.grantedLabel,
    required this.notGrantedLabel,
    this.onHelp,
    this.helpLabel,
  });

  final String icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;
  final String grantedLabel;
  final String notGrantedLabel;
  final VoidCallback? onHelp;
  final String? helpLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isGranted ? grantedLabel : notGrantedLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isGranted ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!isGranted && onHelp != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onHelp,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline,
                            size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          helpLabel ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.arrow_forward,
            color: isGranted ? Colors.green : Colors.grey[400],
            size: 20,
          ),
        ],
      ),
    );
  }
}