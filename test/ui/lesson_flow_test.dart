import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/progress/progress_store.dart';

import '../support.dart';

import 'package:sudoku_solver/lessons/lessons.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/lesson_screen.dart';
import 'package:sudoku_solver/engine/engine.dart';

void main() {
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('every lesson screen builds without errors', (tester) async {
    phoneSize(tester);
    for (final lesson in lessons) {
      await tester.pumpWidget(testApp(LessonScreen(lesson: lesson)));
      expect(
        find.text('The idea'),
        findsOneWidget,
        reason: lesson.technique.label,
      );
      expect(tester.takeException(), isNull, reason: lesson.technique.label);
    }
  });

  testWidgets('Learn tab opens a lesson and flips before/after', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      SudokuApp(store: ProgressStore.memory()..unlockAllLevels()),
    );
    await tester.tap(find.text('Naked Pair'));
    await tester.pumpAndSettle();

    expect(find.text('The idea'), findsOneWidget);
    expect(
      find.textContaining('can only hold 1, 2 between them'),
      findsOneWidget,
    );

    await tester.tap(find.text('After'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Removed 1, 2 from'), findsOneWidget);
  });

  testWidgets('a lesson links to its practice puzzle', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      testApp(LessonScreen(lesson: lessonFor(Technique.xWing))),
    );
    await tester.scrollUntilVisible(find.text('X-Wing practice'), 200);
    await tester.tap(find.text('X-Wing practice'));
    await tester.pumpAndSettle();
    expect(find.text('Get a hint'), findsOneWidget);
  });

  testWidgets('every lesson offers at least one practice puzzle', (
    tester,
  ) async {
    phoneSize(tester);
    for (final lesson in lessons) {
      await tester.pumpWidget(testApp(LessonScreen(lesson: lesson)));
      await tester.scrollUntilVisible(find.text('Practice'), 200);
      expect(
        find.textContaining('no practice puzzle'),
        findsNothing,
        reason: lesson.technique.label,
      );
    }
  });
}
