import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';
import '../providers/language_provider.dart';
import 'faq_accordion.dart';
import 'feedback_form.dart';
import 'settings_toggle_tile.dart';

const String _kSupportEmail = 'eyecareai.app@gmail.com';

Future<void> _openMailto(BuildContext context, {required String subject, String body = ''}) async {
  final strings = context.read<LanguageProvider>().strings;
  final uri = Uri.parse(
    'mailto:$_kSupportEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
  bool opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.feedbackNoEmailApp)),
    );
  }
}

class HelpSupportSection extends StatelessWidget {
  const HelpSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionLabel(strings.faqTitle),
        const FaqAccordion(),
        SettingsSectionLabel(strings.contactSupport),
        _ContactButton(
          icon: Icons.email_outlined,
          label: strings.emailSupport,
          onTap: () => _openMailto(
            context,
            subject: strings.vi ? 'Hỗ trợ EyeCare AI' : 'EyeCare AI Support',
          ),
        ),
        const SizedBox(height: 8),
        _ContactButton(
          icon: Icons.bug_report_outlined,
          label: strings.reportBug,
          onTap: () => _openMailto(
            context,
            subject: strings.vi ? 'Báo lỗi EyeCare AI' : 'EyeCare AI Bug Report',
            body: strings.vi
                ? 'Mô tả lỗi:\n\n\nCác bước để gặp lại lỗi:\n\n\nThiết bị/phiên bản Android:\n'
                : 'Describe the bug:\n\n\nSteps to reproduce:\n\n\nDevice/Android version:\n',
          ),
        ),
        const SizedBox(height: 8),
        _ContactButton(
          icon: Icons.lightbulb_outline_rounded,
          label: strings.requestFeature,
          onTap: () => _openMailto(
            context,
            subject: strings.vi ? 'Đề xuất tính năng EyeCare AI' : 'EyeCare AI Feature Request',
          ),
        ),
        SettingsSectionLabel(strings.feedbackTitle),
        const FeedbackForm(),
        SettingsSectionLabel(strings.aboutTitle),
        const _AboutGrid(),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Trước đây nền cứng AppColors.background (màu sáng) + chữ không set màu
    // tường minh -> ở Dark Mode nút hiện nền sáng/chữ tối gần như không đọc
    // được. Đổi sang màu surface + màu chữ mặc định của Theme hiện tại.
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5, color: onSurface),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutGrid extends StatefulWidget {
  const _AboutGrid();

  @override
  State<_AboutGrid> createState() => _AboutGridState();
}

class _AboutGridState extends State<_AboutGrid> {
  Map<String, String> _items = const <String, String>{
    'App Version': '—',
    'Build Number': '—',
    'Developer': 'Eye Care AI Team',
    'Powered by': 'Flutter',
    'AI Model': 'On-device CV + Cloud LLM',
  };

  String? _fullCommit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final commit = Env.commitHash;
      _fullCommit = commit.isEmpty ? null : commit;
      if (!mounted) return;
      setState(() {
        _items = {
          ..._items,
          if (info.version.isNotEmpty) 'App Version': info.version,
          if (info.buildNumber.isNotEmpty) 'Build Number': info.buildNumber,
          if (_fullCommit != null) 'Commit': _fullCommit!.substring(0, 8),
        };
      });
    } catch (_) {
      // keep placeholder values if package info fails
    }
  }

  Future<void> _copyCommit() async {
    final sha = _fullCommit;
    if (sha == null) return;
    await Clipboard.setData(ClipboardData(text: sha));
    if (!mounted) return;
    final strings = context.read<LanguageProvider>().strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.vi ? 'Đã sao chép commit SHA' : 'Commit SHA copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in _items.entries)
          InkWell(
            onTap: entry.key == 'Commit' ? _copyCommit : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(minWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.value,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: onSurface),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}