import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/lessons/lessons.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/lesson_screen.dart';

import '../support.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a lesson with a chain explains the lines drawn', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      testApp(LessonScreen(lesson: lessonFor(Technique.xChain))),
    );
    final legend = tester.widget<Text>(find.byKey(const Key('link-legend')));
    expect(legend.data, contains('Solid line'));
    expect(legend.data, contains('Dashed line'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an XY-Chain has only dashed links', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      testApp(LessonScreen(lesson: lessonFor(Technique.xyChain))),
    );
    final legend = tester.widget<Text>(find.byKey(const Key('link-legend')));
    expect(legend.data, isNot(contains('Solid line')));
    expect(legend.data, contains('Dashed line'));
  });

  testWidgets('techniques without links show no legend', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      testApp(LessonScreen(lesson: lessonFor(Technique.nakedPair))),
    );
    expect(find.byKey(const Key('link-legend')), findsNothing);
  });

  testWidgets('every lesson with links paints and lays out', (tester) async {
    phone(tester);
    for (final lesson in lessons) {
      final example = lesson.example();
      if (example.step.links.isEmpty) continue;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: BoardView(
              board: example.board,
              givens: const {},
              showCandidates: true,
              step: example.step,
              candidateFocus: example.step,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: lesson.technique.label);
    }
  });

  test('the lessons that should draw links do', () {
    for (final t in [
      Technique.xWing,
      Technique.skyscraper,
      Technique.yWing,
      Technique.xyzWing,
      Technique.wWing,
      Technique.simpleColoring,
      Technique.xChain,
      Technique.xyChain,
    ]) {
      expect(lessonFor(t).example().step.links, isNotEmpty, reason: t.label);
    }
  });
}
