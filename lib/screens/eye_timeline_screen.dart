import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../services/eye_timeline_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

/// "Dòng thời gian mắt": biến dữ liệu cảm biến thành các sự kiện người dùng
/// đọc được (môi trường sáng/tối, phiên dùng màn hình, nghỉ mắt, chỉnh độ
/// sáng...). Dữ liệu do EyeTimelineService ghi lại trong lúc app chạy.
class EyeTimelineScreen extends StatefulWidget {
  const EyeTimelineScreen({super.key});

  @override
  State<EyeTimelineScreen> createState() => _EyeTimelineScreenState();
}

class _EyeTimelineScreenState extends State<EyeTimelineScreen> {
  // Đổi thành false nếu muốn sự kiện cũ nhất nằm trên cùng (đọc theo giờ tăng dần).
  static const bool _newestFirst = true;
  static const int _daysBack = 6; // hôm nay + 6 ngày trước

  int _dayOffset = 0; // 0 = hôm nay
  List<TimelineEvent>? _events;

  DateTime get _day {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: _dayOffset));
  }

  @override
  void initState() {
    super.initState();
    _load();
    EyeTimelineService.revision.addListener(_onNewEvent);
  }

  @override
  void dispose() {
    EyeTimelineService.revision.removeListener(_onNewEvent);
    super.dispose();
  }

  // Có sự kiện mới trong lúc đang xem hôm nay -> tải lại.
  void _onNewEvent() {
    if (_dayOffset == 0) _load();
  }

  Future<void> _load() async {
    final events = await EyeTimelineService.instance.loadDay(_day);
    if (!mounted) return;
    setState(() => _events = events);
  }

  void _changeDay(int offset) {
    if (offset < 0 || offset > _daysBack) return;
    setState(() {
      _dayOffset = offset;
      _events = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    final events = _events;
    final shown = events == null
        ? const <TimelineEvent>[]
        : (_newestFirst ? events.reversed.toList() : events);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: vi ? 'Quay lại' : 'Back',
        ),
        title: Text(vi ? 'Dòng thời gian mắt' : 'Eye Timeline'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _DayPicker(
                label: _dayLabel(vi),
                canGoOlder: _dayOffset < _daysBack,
                canGoNewer: _dayOffset > 0,
                onOlder: () => _changeDay(_dayOffset + 1),
                onNewer: () => _changeDay(_dayOffset - 1),
              ),
              const SizedBox(height: 14),
              if (events == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                _SummaryRow(events: events, vi: vi),
                const SizedBox(height: 16),
                if (events.isEmpty)
                  _EmptyState(vi: vi)
                else
                  SectionCard(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 2),
                    child: Column(
                      children: [
                        for (var i = 0; i < shown.length; i++)
                          _TimelineRow(
                            event: shown[i],
                            vi: vi,
                            isLast: i == shown.length - 1,
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(bool vi) {
    if (_dayOffset == 0) return vi ? 'Hôm nay' : 'Today';
    if (_dayOffset == 1) return vi ? 'Hôm qua' : 'Yesterday';
    final d = _day;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.label,
    required this.canGoOlder,
    required this.canGoNewer,
    required this.onOlder,
    required this.onNewer,
  });

  final String label;
  final bool canGoOlder;
  final bool canGoNewer;
  final VoidCallback onOlder;
  final VoidCallback onNewer;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: canGoOlder ? onOlder : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          onPressed: canGoNewer ? onNewer : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.events, required this.vi});

  final List<TimelineEvent> events;
  final bool vi;

  @override
  Widget build(BuildContext context) {
    final breaks = events.where((e) => e.type == TimelineEventType.eyeBreak).length;
    final screenMinutes = events
        .where((e) => e.type == TimelineEventType.screenSession)
        .fold<int>(0, (sum, e) => sum + (e.value ?? 0));
    final warnings = events
        .where((e) =>
            e.type == TimelineEventType.darkRoom || e.type == TimelineEventType.dimEnvironment)
        .length;

    return Row(
      children: [
        Expanded(child: _SummaryTile(value: '$breaks', label: vi ? 'Nghỉ mắt' : 'Breaks')),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            value: screenMinutes >= 60
                ? '${(screenMinutes / 60).toStringAsFixed(1)}h'
                : '${screenMinutes}m',
            label: vi ? 'Phiên màn hình' : 'Screen sessions',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            value: '$warnings',
            label: vi ? 'Thiếu sáng' : 'Low light',
            highlight: warnings > 0,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.value, required this.label, this.highlight = false});

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: highlight ? AppColors.warning : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.vi});

  final bool vi;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Icon(Icons.timeline_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              vi ? 'Chưa có sự kiện nào' : 'No events yet',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              vi
                  ? 'Sự kiện sẽ xuất hiện khi bạn dùng app: nghỉ mắt, ánh sáng xung quanh, phiên dùng màn hình...'
                  : 'Events appear as you use the app: eye breaks, ambient light, screen sessions...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.vi, required this.isLast});

  final TimelineEvent event;
  final bool vi;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(event.type);
    final hint = _hintFor(event);
    final time =
        '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                time,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, size: 17, color: style.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Theme.of(context).dividerColor),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleFor(event),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(hint, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(TimelineEvent e) {
    switch (e.type) {
      case TimelineEventType.brightEnvironment:
        return vi ? 'Môi trường sáng tốt' : 'Good lighting';
      case TimelineEventType.dimEnvironment:
        return vi ? 'Ánh sáng hơi yếu' : 'Lighting is dim';
      case TimelineEventType.screenSession:
        final m = e.value ?? 0;
        final text = m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '$m ${vi ? 'phút' : 'min'}';
        return vi ? 'Dùng màn hình liên tục $text' : 'Screen session $text';
      case TimelineEventType.eyeBreak:
        return vi ? 'Đã nghỉ mắt' : 'Eye break completed';
      case TimelineEventType.darkRoom:
        return vi ? 'Phòng quá tối' : 'Room too dark';
      case TimelineEventType.brightnessAdjusted:
        return vi ? 'Đã chỉnh độ sáng màn hình' : 'Brightness adjusted';
    }
  }

  // Gợi ý ngắn giúp người dùng biết nên làm gì — chỉ hiện với sự kiện cần chú ý.
  String? _hintFor(TimelineEvent e) {
    switch (e.type) {
      case TimelineEventType.dimEnvironment:
        return vi ? 'Nên bật thêm đèn' : 'Consider turning on a light';
      case TimelineEventType.darkRoom:
        return vi ? 'Bật đèn hoặc giảm độ sáng màn hình' : 'Turn on a light or lower screen brightness';
      case TimelineEventType.screenSession:
        return (e.value ?? 0) >= 45
            ? (vi ? 'Phiên khá dài, nhớ nghỉ mắt 20-20-20' : 'Long session, remember the 20-20-20 rule')
            : null;
      default:
        return null;
    }
  }

  _EventStyle _styleFor(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.brightEnvironment:
        return const _EventStyle(Icons.wb_sunny_outlined, AppColors.success);
      case TimelineEventType.dimEnvironment:
        return const _EventStyle(Icons.wb_twilight_rounded, AppColors.warning);
      case TimelineEventType.screenSession:
        return const _EventStyle(Icons.smartphone_outlined, AppColors.primaryBlue);
      case TimelineEventType.eyeBreak:
        return const _EventStyle(Icons.remove_red_eye_outlined, AppColors.primaryTeal);
      case TimelineEventType.darkRoom:
        return const _EventStyle(Icons.bedtime_outlined, AppColors.error);
      case TimelineEventType.brightnessAdjusted:
        return const _EventStyle(Icons.brightness_6_outlined, AppColors.testAccent);
    }
  }
}

class _EventStyle {
  const _EventStyle(this.icon, this.color);
  final IconData icon;
  final Color color;
}