import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eye_care_ai/providers/language_provider.dart';
import 'package:eye_care_ai/screens/eye_exercise_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<LanguageProvider> pumpExerciseScreen(WidgetTester tester) async {
    final language = LanguageProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: language,
        child: const MaterialApp(home: EyeExerciseScreen()),
      ),
    );
    await tester.pump();
    return language;
  }

  testWidgets('offers individual routines and the guided sequence', (
    tester,
  ) async {
    final language = await pumpExerciseScreen(tester);
    final strings = language.strings;

    expect(find.text(strings.eyeExerciseChoose), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(strings.eyeExerciseBlinkTitle),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.eyeExerciseBlinkTitle), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(strings.eyeExerciseGuidedTitle),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.eyeExerciseGuidedTitle), findsOneWidget);
  });

  testWidgets('guided sequence records one completed 80-second session', (
    tester,
  ) async {
    final language = await pumpExerciseScreen(tester);
    final strings = language.strings;
    final start = find.text(strings.eyeExerciseStart);

    await tester.scrollUntilVisible(
      start,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pump();

    for (var step = 0; step < 4; step++) {
      await tester.pump(const Duration(seconds: 20));
    }
    await tester.pump();

    expect(find.text(strings.eyeExerciseDoneTitle), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final history = jsonDecode(prefs.getString('eye_exercise_history')!) as List;
    expect(history.single['type'], 'guided');
    expect(history.single['seconds'], 80);
    expect(prefs.getInt('pref_eye_exercise_count'), 1);
  });

  testWidgets('individual blinking routine contributes to daily history', (
    tester,
  ) async {
    final language = await pumpExerciseScreen(tester);
    final play = find.byIcon(Icons.play_arrow_rounded).first;

    await tester.scrollUntilVisible(
      play,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(play);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    final history = jsonDecode(prefs.getString('eye_exercise_history')!) as List;
    expect(history.single['type'], 'blink');
    expect(history.single['seconds'], 30);
    expect(prefs.getInt('pref_eye_exercise_count'), 1);
    expect(find.text(language.strings.eyeExerciseChoose), findsOneWidget);
  });
}
