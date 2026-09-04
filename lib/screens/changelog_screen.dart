import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// ChangelogScreen liệt kê lịch sử các bản phát hành (GitHub Releases) của
// app, mỗi bản kèm ghi chú "có gì mới" (release notes) — mở từ Cài đặt >
// Khác > "Nhật ký cập nhật". Dùng chung UpdateService.fetchChangelog, vốn
// đọc TRỰC TIẾP từ GitHub Releases nên không cần thêm 1 nguồn dữ liệu mới.
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  // null = đang tải. [] = tải xong nhưng repo chưa có release nào.
  // Giá trị null SAU khi tải xong (đặt lại qua _loadFailed) nghĩa là lỗi.
  List<ChangelogEntry>? _entries;
  bool _loadFailed = false;
  int? _currentBuildNumber;

  @override
  void initState() {
    super.initState();
    _load();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _currentBuildNumber = int.tryParse(info.buildNumber));
    });
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    final entries = await UpdateService.instance.fetchChangelog();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loadFailed = entries == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(strings.changelogTitle),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(context, strings),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppStrings strings) {
    if (_entries == null && !_loadFailed) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadFailed) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              strings.changelogLoadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(onPressed: _load, child: Text(strings.changelogRetry)),
          ),
        ],
      );
    }

    final entries = _entries!;
    if (entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Text(
              strings.changelogEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: entries.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              strings.changelogSubtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          );
        }
        final entry = entries[index - 1];
        final isCurrent = entry.buildNumber == _currentBuildNumber;
        return _ChangelogCard(entry: entry, isCurrent: isCurrent, strings: strings);
      },
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({required this.entry, required this.isCurrent, required this.strings});

  final ChangelogEntry entry;
  final bool isCurrent;
  final AppStrings strings;

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final notes = entry.notes.trim();
    // Ghi chú release trên GitHub thường viết dạng mỗi dòng 1 mục (bullet
    // "- ..." hoặc "* ..."), tách theo dòng để hiện thành danh sách rõ ràng
    // thay vì 1 khối văn bản dính liền khó đọc.
    final lines = notes.isEmpty
        ? <String>[]
        : notes
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .map((l) => l.replaceFirst(RegExp(r'^[-*•]\s*'), ''))
            .toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.versionName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    strings.changelogCurrentVersionTag,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          if (entry.publishedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              _formatDate(entry.publishedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          if (lines.isEmpty)
            Text(
              strings.changelogNoNotes,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            )
          else
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: Theme.of(context).textTheme.bodyMedium),
                    Expanded(
                      child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
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
