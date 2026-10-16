import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import '../utils/app_icon.dart';

// Bài tập mắt có hướng dẫn (Notion: Tính năng sắp tới) — nhìn theo chấm di
// chuyển + chớp mắt chủ động, ~80 giây, không cần camera/cảm biến.
// v1: hướng dẫn tại chỗ + đếm số buổi đã tập (lưu prefs, làm nền cho tính
// năng "chuỗi bài tập mắt" sau này). Không ghi vào Habit để giữ scope gọn.
enum _ExerciseKind { horizontal, vertical, circles, blinking }

class EyeExerciseScreen extends StatefulWidget {
  const EyeExerciseScreen({super.key});

  @override
  State<EyeExerciseScreen> createState() => _EyeExerciseScreenState();
}

class _EyeExerciseScreenState extends State<EyeExerciseScreen>
    with SingleTickerProviderStateMixin {
  static const _stepSeconds = 20;
  static const _kinds = [
    _ExerciseKind.horizontal,
    _ExerciseKind.vertical,
    _ExerciseKind.circles,
    _ExerciseKind.blinking,
  ];
  static const _kCountKey = 'pref_eye_exercise_count';
  static const _kLastDateKey = 'pref_eye_exercise_last_date';

  int _stepIndex = 0;
  int _remaining = _stepSeconds;
  bool _running = false;
  bool _done = false;
  int _totalCompleted = 0;
  Timer? _timer;
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _loadTotal();
  }

  Future<void> _loadTotal() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _totalCompleted = prefs.getInt(_kCountKey) ?? 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dotController.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _stepIndex = 0;
      _remaining = _stepSeconds;
      _running = true;
      _done = false;
    });
    _dotController.repeat();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _togglePause() {
    if (_done) return;
    setState(() => _running = !_running);
    if (_running) {
      _dotController.repeat();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _dotController.stop();
      _timer?.cancel();
    }
  }

  void _tick() {
    if (!_running || _done) return;
    if (_remaining > 1) {
      setState(() => _remaining--);
    } else {
      _nextStep();
    }
  }

  void _nextStep() {
    if (_stepIndex >= _kinds.length - 1) {
      _finish();
    } else {
      setState(() {
        _stepIndex++;
        _remaining = _stepSeconds;
      });
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    _dotController.stop();
    final prefs = await SharedPreferences.getInstance();
    final total = (prefs.getInt(_kCountKey) ?? 0) + 1;
    await prefs.setInt(_kCountKey, total);
    final now = DateTime.now();
    await prefs.setString(
      _kLastDateKey,
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    if (!mounted) return;
    setState(() {
      _done = true;
      _running = false;
      _totalCompleted = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.eyeExerciseTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _done
              ? _buildDone(strings)
              : (_running || _remaining != _stepSeconds || _stepIndex != 0)
              ? _buildRunning(strings)
              : _buildIdle(strings),
        ),
      ),
    );
  }

  Widget _buildIdle(dynamic strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppIcon('👁️', size: 56),
        const SizedBox(height: 16),
        Text(
          strings.eyeExerciseTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          strings.eyeExerciseSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ...List.generate(
          _kinds.length,
          (i) => ListTile(
            dense: true,
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(strings.eyeExerciseStepName(i)),
            subtitle: Text(strings.eyeExerciseStepInstruction(i)),
          ),
        ),
        const Spacer(),
        Text(
          strings.eyeExerciseTotalDone(_totalCompleted),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _start,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(strings.eyeExerciseStart),
          ),
        ),
      ],
    );
  }

  Widget _buildRunning(dynamic strings) {
    final kind = _kinds[_stepIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.eyeExerciseStepCounter(_stepIndex + 1, _kinds.length),
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
          '$_remaining s',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: 1 - (_remaining / _stepSeconds)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _togglePause,
                child: Text(
                  _running
                      ? strings.eyeExercisePause
                      : strings.eyeExerciseResume,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _nextStep,
                child: Text(strings.eyeExerciseSkip),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDone(dynamic strings) {
    return Column(
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
          onPressed: _start,
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
