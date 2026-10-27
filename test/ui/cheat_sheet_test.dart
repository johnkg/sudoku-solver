import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/lessons/lessons.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/cheat_sheet_screen.dart';
import 'package:sudoku_solver/ui/lesson_screen.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('a lesson matches words from its name, tagline or tips', () {
    final lesson = lessons.first;
    expect(lessonMatches(lesson, ''), isTrue);
    expect(lessonMatches(lesson, lesson.technique.label.toUpperCase()), isTrue);
    expect(lessonMatches(lesson, 'qqqqzzzz'), isFalse);
  });

  testWidgets('the menu opens the cheat sheet', (tester) async {
    phone(tester);
    await tester.pumpWidget(SudokuApp(store: ProgressStore.memory()));
    await tester.tap(find.byTooltip('Progress options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Technique cheat sheet'));
    await tester.pumpAndSettle();
    expect(find.byType(CheatSheetScreen), findsOneWidget);
    expect(find.byKey(Key('cheat-${lessons.first.technique.name}')), findsOne);
  });

  testWidgets('search narrows the list and says when nothing matches', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: CheatSheetScreen()));
    expect(find.byKey(const Key('cheat-xWing')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cheat-search')), 'x-wing');
    await tester.pump();
    expect(find.byKey(const Key('cheat-xWing')), findsOneWidget);
    expect(find.byKey(const Key('cheat-fullHouse')), findsNothing);

    await tester.enterText(find.byKey(const Key('cheat-search')), 'qqqqzzzz');
    await tester.pump();
    expect(find.byKey(const Key('cheat-empty')), findsOneWidget);
  });

  testWidgets('a card opens to show the idea and links to the lesson', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(const MaterialApp(home: CheatSheetScreen()));
    final lesson = lessons.firstWhere((l) => l.technique == Technique.xWing);

    await tester.tap(find.text(lesson.technique.label));
    await tester.pumpAndSettle();
    expect(find.text(lesson.idea), findsOneWidget);
    expect(find.text(lesson.spot), findsOneWidget);

    await tester.tap(find.text('Open the lesson'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonScreen), findsOneWidget);
  });
}
