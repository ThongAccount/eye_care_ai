import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_strings.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_icon.dart';
import '../widgets/shared_widgets.dart';

// Bài tập mắt có hướng dẫn (Notion: Tính năng sắp tới) — nhìn theo chấm di
// chuyển + chớp mắt chủ động, ~80 giây, không cần camera/cảm biến.
// v1: hướng dẫn tại chỗ + đếm số buổi đã tập (lưu prefs, làm nền cho tính
// năng "chuỗi bài tập mắt" sau này). Không ghi vào Habit để giữ scope gọn.
enum _ExerciseKind { horizontal, vertical, circles, blinking }
enum _IndividualExerciseType { blink, focus, movement, relax }

class EyeExerciseScreen extends StatefulWidget {
  const EyeExerciseScreen({super.key});

  @override
  State<EyeExerciseScreen> createState() => _EyeExerciseScreenState();
}

class _EyeExerciseScreenState extends State<EyeExerciseScreen>
    with SingleTickerProviderStateMixin {
  static const _stepSeconds = 20;
  static const _guidedKinds = [
    _ExerciseKind.horizontal,
    _ExerciseKind.vertical,
    _ExerciseKind.circles,
    _ExerciseKind.blinking,
  ];
  static const _historyKey = 'eye_exercise_history';
  static const _kCountKey = 'pref_eye_exercise_count';
  static const _kLastDateKey = 'pref_eye_exercise_last_date';

  Timer? _timer;
  late final AnimationController _dotController;
  _IndividualExerciseType? _activeType;
  int _remainingSeconds = 0;
  int _stepIndex = 0;
  int _guidedElapsedSeconds = 0;
  bool _guidedActive = false;
  bool _guidedRunning = false;
  bool _guidedDone = false;
  int _completedSecondsToday = 0;
  int _totalCompleted = 0;

  int get _completedMinutesToday => (_completedSecondsToday / 60).ceil();

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _loadTodayProgress();
  }

  Future<void> _loadTodayProgress() async {
    final prefs = await SharedPreferences.getInstance();
    var completedSeconds = 0;
    final raw = prefs.getString(_historyKey);
    if (raw != null) {
      try {
        final today = DateTime.now();
        final entries = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        completedSeconds = entries.fold<int>(0, (sum, entry) {
          final date = DateTime.tryParse(entry['date'] as String? ?? '');
          if (date == null ||
              date.year != today.year ||
              date.month != today.month ||
              date.day != today.day) {
            return sum;
          }
          return sum + ((entry['seconds'] as num?)?.toInt() ?? 0);
        });
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _completedSecondsToday = completedSeconds;
      _totalCompleted = prefs.getInt(_kCountKey) ?? 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dotController.dispose();
    super.dispose();
  }

  int _durationFor(_IndividualExerciseType type) => switch (type) {
    _IndividualExerciseType.blink => 30,
    _IndividualExerciseType.focus => 60,
    _IndividualExerciseType.movement => 60,
    _IndividualExerciseType.relax => 30,
  };

  String _titleFor(AppStrings strings, _IndividualExerciseType type) =>
      switch (type) {
        _IndividualExerciseType.blink => strings.eyeExerciseBlinkTitle,
        _IndividualExerciseType.focus => strings.eyeExerciseFocusTitle,
        _IndividualExerciseType.movement => strings.eyeExerciseMovementTitle,
        _IndividualExerciseType.relax => strings.eyeExerciseRelaxTitle,
      };

  String _bodyFor(AppStrings strings, _IndividualExerciseType type) =>
      switch (type) {
        _IndividualExerciseType.blink => strings.eyeExerciseBlinkBody,
        _IndividualExerciseType.focus => strings.eyeExerciseFocusBody,
        _IndividualExerciseType.movement => strings.eyeExerciseMovementBody,
        _IndividualExerciseType.relax => strings.eyeExerciseRelaxBody,
      };

  String _instructionFor(AppStrings strings, _IndividualExerciseType type) =>
      switch (type) {
        _IndividualExerciseType.blink => strings.eyeExerciseBlinkInstruction,
        _IndividualExerciseType.focus => strings.eyeExerciseFocusInstruction,
        _IndividualExerciseType.movement =>
          strings.eyeExerciseMovementInstruction,
        _IndividualExerciseType.relax => strings.eyeExerciseRelaxInstruction,
      };

  IconData _iconFor(_IndividualExerciseType type) => switch (type) {
    _IndividualExerciseType.blink => Icons.visibility_outlined,
    _IndividualExerciseType.focus => Icons.zoom_out_map_rounded,
    _IndividualExerciseType.movement => Icons.control_camera_rounded,
    _IndividualExerciseType.relax => Icons.self_improvement_rounded,
  };

  void _startIndividual(_IndividualExerciseType type) {
    _timer?.cancel();
    _dotController.stop();
    setState(() {
      _activeType = type;
      _remainingSeconds = _durationFor(type);
      _guidedActive = false;
      _guidedRunning = false;
      _guidedDone = false;
    });
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickIndividual(),
    );
  }

  void _tickIndividual() {
    final type = _activeType;
    if (type == null) return;
    if (_remainingSeconds > 1) {
      setState(() => _remainingSeconds--);
    } else {
      _finishIndividual(type);
    }
  }

  Future<void> _finishIndividual(_IndividualExerciseType type) async {
    _timer?.cancel();
    final duration = _durationFor(type);
    setState(() {
      _activeType = null;
      _remainingSeconds = 0;
    });
    await _recordCompletion(type: type.name, seconds: duration);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.read<LanguageProvider>().strings.eyeExerciseCompleted)),
    );
  }

  void _stopIndividual() {
    _timer?.cancel();
    setState(() {
      _activeType = null;
      _remainingSeconds = 0;
    });
  }

  void _startGuided() {
    _timer?.cancel();
    setState(() {
      _activeType = null;
      _stepIndex = 0;
      _remainingSeconds = _stepSeconds;
      _guidedElapsedSeconds = 0;
      _guidedActive = true;
      _guidedRunning = true;
      _guidedDone = false;
    });
    _dotController.repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickGuided());
  }

  void _toggleGuidedPause() {
    if (!_guidedActive) return;
    final resume = !_guidedRunning;
    setState(() => _guidedRunning = resume);
    if (resume) {
      _dotController.repeat();
      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tickGuided(),
      );
    } else {
      _dotController.stop();
      _timer?.cancel();
    }
  }

  void _tickGuided() {
    if (!_guidedActive || !_guidedRunning) return;
    if (_remainingSeconds > 1) {
      setState(() {
        _remainingSeconds--;
        _guidedElapsedSeconds++;
      });
      return;
    }

    _guidedElapsedSeconds++;
    if (_stepIndex >= _guidedKinds.length - 1) {
      _finishGuided();
    } else {
      setState(() {
        _stepIndex++;
        _remainingSeconds = _stepSeconds;
      });
    }
  }

  void _skipGuidedStep() {
    if (_stepIndex >= _guidedKinds.length - 1) {
      _finishGuided();
    } else {
      setState(() {
        _stepIndex++;
        _remainingSeconds = _stepSeconds;
      });
    }
  }

  Future<void> _finishGuided() async {
    _timer?.cancel();
    _dotController.stop();
    setState(() {
      _guidedActive = false;
      _guidedRunning = false;
      _guidedDone = true;
    });
    await _recordCompletion(
      type: 'guided',
      seconds: _guidedElapsedSeconds,
    );
  }

  Future<void> _recordCompletion({
    required String type,
    required int seconds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    List<Map<String, dynamic>> history = [];
    if (raw != null) {
      try {
        history = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }

    final now = DateTime.now();
    history.add({
      'date': now.toIso8601String(),
      'type': type,
      'seconds': seconds,
    });
    if (history.length > 100) {
      history = history.sublist(history.length - 100);
    }
    await prefs.setString(_historyKey, jsonEncode(history));

    final total = (prefs.getInt(_kCountKey) ?? 0) + 1;
    await prefs.setInt(_kCountKey, total);
    await prefs.setString(
      _kLastDateKey,
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );

    if (!mounted) return;
    setState(() {
      _completedSecondsToday += seconds;
      _totalCompleted = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final body = _activeType != null
        ? _buildIndividual(strings)
        : _guidedDone
        ? _buildGuidedDone(strings)
        : _guidedActive
        ? _buildGuided(strings)
        : _buildIdle(strings);

    return Scaffold(
      appBar: AppBar(title: Text(strings.eyeExerciseTitle)),
      body: SafeArea(child: body),
    );
  }

  Widget _buildIdle(AppStrings strings) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppIcon('👁️', size: 56),
        const SizedBox(height: 16),
        Text(
          strings.eyeExerciseTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Row(
            children: [
              Icon(Icons.spa_rounded, color: accent, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.eyeExerciseToday,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_completedMinutesToday ${strings.minuteUnit}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.eyeExerciseTotalDone(_totalCompleted),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          strings.eyeExerciseChoose,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _ExerciseCard(
          icon: _iconFor(_IndividualExerciseType.blink),
          title: strings.eyeExerciseBlinkTitle,
          subtitle: strings.eyeExerciseBlinkBody,
          duration: '30 ${strings.secondUnit}',
          startLabel: strings.eyeExerciseStart,
          onStart: () => _startIndividual(_IndividualExerciseType.blink),
        ),
        _ExerciseCard(
          icon: _iconFor(_IndividualExerciseType.focus),
          title: strings.eyeExerciseFocusTitle,
          subtitle: strings.eyeExerciseFocusBody,
          duration: '60 ${strings.secondUnit}',
          startLabel: strings.eyeExerciseStart,
          onStart: () => _startIndividual(_IndividualExerciseType.focus),
        ),
        _ExerciseCard(
          icon: _iconFor(_IndividualExerciseType.movement),
          title: strings.eyeExerciseMovementTitle,
          subtitle: strings.eyeExerciseMovementBody,
          duration: '60 ${strings.secondUnit}',
          startLabel: strings.eyeExerciseStart,
          onStart: () => _startIndividual(_IndividualExerciseType.movement),
        ),
        _ExerciseCard(
          icon: _iconFor(_IndividualExerciseType.relax),
          title: strings.eyeExerciseRelaxTitle,
          subtitle: strings.eyeExerciseRelaxBody,
          duration: '30 ${strings.secondUnit}',
          startLabel: strings.eyeExerciseStart,
          onStart: () => _startIndividual(_IndividualExerciseType.relax),
        ),
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.eyeExerciseGuidedTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                strings.eyeExerciseSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _startGuided,
                child: Text(strings.eyeExerciseStart),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.eyeExerciseSafety,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ],
    );
  }

  Widget _buildIndividual(AppStrings strings) {
    final type = _activeType!;
    final duration = _durationFor(type);
    final progress = (duration - _remainingSeconds) / duration;
    final accent = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(_iconFor(type), size: 48, color: accent),
            const SizedBox(height: 10),
            Text(
              _titleFor(strings, type),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _bodyFor(strings, type),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _instructionFor(strings, type),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                    Text(
                      '$_remainingSeconds',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _stopIndividual,
              icon: const Icon(Icons.stop_rounded),
              label: Text(strings.eyeExerciseStop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuided(AppStrings strings) {
    final kind = _guidedKinds[_stepIndex];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.eyeExerciseStepCounter(_stepIndex + 1, _guidedKinds.length),
            style: Theme.of(context).textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            strings.eyeExerciseStepName(_stepIndex),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            strings.eyeExerciseStepInstruction(_stepIndex),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (_, _) => CustomPaint(
                painter: _ExerciseDotPainter(
                  kind: kind,
                  progress: _dotController.value,
                  dotColor: Theme.of(context).colorScheme.primary,
                  trackColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_remainingSeconds ${strings.secondUnit}',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: 1 - (_remainingSeconds / _stepSeconds)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _toggleGuidedPause,
                  child: Text(
                    _guidedRunning
                        ? strings.eyeExercisePause
                        : strings.eyeExerciseResume,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _skipGuidedStep,
                  child: Text(strings.eyeExerciseSkip),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidedDone(AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            strings.eyeExerciseDoneTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.eyeExerciseDoneMessage(_totalCompleted),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _startGuided,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(strings.eyeExerciseRestart),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.eyeExerciseClose),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.startLabel,
    required this.onStart,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String duration;
  final String startLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    duration,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: startLabel,
              child: FilledButton(
                onPressed: onStart,
                child: const Icon(Icons.play_arrow_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDotPainter extends CustomPainter {
  _ExerciseDotPainter({
    required this.kind,
    required this.progress,
    required this.dotColor,
    required this.trackColor,
  });

  final _ExerciseKind kind;
  final double progress; // 0..1
  final Color dotColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final amp = math.min(size.width, size.height) * 0.32;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    Offset dot = center;
    double radius = 14;
    switch (kind) {
      case _ExerciseKind.horizontal:
        final y = center.dy;
        canvas.drawLine(
          Offset(center.dx - amp, y),
          Offset(center.dx + amp, y),
          trackPaint,
        );
        dot = Offset(center.dx + math.sin(progress * 2 * math.pi) * amp, y);
      case _ExerciseKind.vertical:
        final x = center.dx;
        canvas.drawLine(
          Offset(x, center.dy - amp),
          Offset(x, center.dy + amp),
          trackPaint,
        );
        dot = Offset(x, center.dy + math.sin(progress * 2 * math.pi) * amp);
      case _ExerciseKind.circles:
        canvas.drawCircle(center, amp, trackPaint);
        final a = progress * 2 * math.pi;
        dot = center + Offset(math.cos(a) * amp, math.sin(a) * amp);
      case _ExerciseKind.blinking:
        canvas.drawCircle(center, amp * 0.45, trackPaint);
        radius = 12 + 8 * (0.5 - 0.5 * math.cos(progress * 2 * math.pi * 2));
    }

    final glowPaint = Paint()..color = dotColor.withValues(alpha: 0.25);
    canvas.drawCircle(dot, radius + 10, glowPaint);
    canvas.drawCircle(dot, radius, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _ExerciseDotPainter old) =>
      old.progress != progress || old.kind != kind;
}
