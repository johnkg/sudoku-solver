import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/lessons/lessons.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/quiz.dart';
import 'package:sudoku_solver/ui/quiz_screen.dart';
import 'package:sudoku_solver/ui/lesson_screen.dart';

import '../support.dart';

void main() {
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> tapCell(WidgetTester tester, int cell) async {
    final box = find.byType(BoardView);
    final size = tester.getSize(box).width / 9;
    await tester.tapAt(
      tester.getTopLeft(box) +
          Offset(
            (Board.columnOf(cell) + 0.5) * size,
            (Board.rowOf(cell) + 0.5) * size,
          ),
    );
    await tester.pump();
  }

  test('every technique has questions that really use it', () {
    for (final lesson in lessons) {
      final qs = quizQuestions(lesson.technique);
      expect(qs, isNotEmpty, reason: lesson.technique.label);
      for (final q in qs) {
        expect(q.step.technique, lesson.technique);
        expect(q.targets, isNotEmpty);
      }
    }
  });

  testWidgets('tapping the cell a single fills scores a point', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      testApp(const QuizScreen(technique: Technique.nakedSingle)),
    );
    final first = quizQuestions(Technique.nakedSingle).first;

    expect(find.byKey(const Key('quiz-prompt')), findsOneWidget);
    await tapCell(tester, first.targets.first);
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.textContaining('1 right'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quiz-next')));
    await tester.pump();
    expect(find.textContaining('Question 2 of'), findsOneWidget);
    expect(find.textContaining('1 right'), findsOneWidget);
  });

  testWidgets('a wrong tap is marked wrong and explained', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      testApp(const QuizScreen(technique: Technique.nakedSingle)),
    );
    final q = quizQuestions(Technique.nakedSingle).first;
    final wrong = List.generate(
      81,
      (i) => i,
    ).firstWhere((c) => !q.targets.contains(c));
    await tapCell(tester, wrong);
    expect(find.text('Not quite.'), findsOneWidget);
    expect(find.text(q.step.explanation), findsOneWidget);
  });

  testWidgets('a pattern needs every cell, then Check, and ends in a score', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      testApp(const QuizScreen(technique: Technique.nakedPair)),
    );
    final qs = quizQuestions(Technique.nakedPair);

    for (var i = 0; i < qs.length; i++) {
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('quiz-check')))
            .onPressed,
        isNull,
      );
      for (final c in qs[i].targets) {
        await tapCell(tester, c);
      }
      await tester.tap(find.byKey(const Key('quiz-check')));
      await tester.pump();
      expect(find.text('Correct!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quiz-next')));
      await tester.pump();
    }
    expect(
      find.text('You spotted ${qs.length} of ${qs.length}.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('quiz-retry')));
    await tester.pump();
    expect(find.textContaining('Question 1 of'), findsOneWidget);
  });

  testWidgets('the lesson page offers the quiz', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      testApp(LessonScreen(lesson: lessonFor(Technique.xWing))),
    );
    await tester.tap(find.byKey(const Key('quiz-me')));
    await tester.pumpAndSettle();
    expect(find.text('Quiz: X-Wing'), findsOneWidget);
  });
}
