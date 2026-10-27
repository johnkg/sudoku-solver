import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/lessons/lessons.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/board_legend.dart';
import 'package:sudoku_solver/ui/daily_puzzle.dart';
import 'package:sudoku_solver/ui/learn_progress.dart';
import 'package:sudoku_solver/ui/lesson_screen.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';

import '../support.dart';

// 2026-10-14 is a Wednesday.
final wednesday = DateTime(2026, 10, 14);

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void solveFor(ProgressStore store, Technique t) {
    final puzzle = puzzleLibrary.firstWhere((p) => p.technique == t);
    store.recordSolve(puzzle.id, mistakes: 0, hints: 0);
  }

  group('learn progress', () {
    test('the next lesson is the first one not yet practised', () {
      final store = ProgressStore.memory();
      expect(nextLesson(store), lessons.first);
      solveFor(store, lessons.first.technique);
      expect(nextLesson(store), isNot(lessons.first));
    });

    test('counts practised lessons per level and overall', () {
      final store = ProgressStore.memory();
      expect(overallProgress(store).done, 0);
      solveFor(store, lessons.first.technique);
      expect(levelProgress(store, lessons.first.level).done, 1);
      expect(overallProgress(store).done, 1);
      expect(overallProgress(store).total, lessons.length);
    });
  });

  testWidgets('Learn shows the ring and a card for the next lesson', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(SudokuApp(store: ProgressStore.memory()));
    expect(find.byKey(const Key('learn-ring')), findsOneWidget);
    expect(find.byKey(const Key('continue-lesson')), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    await tester.tap(find.text('Start lesson'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonScreen), findsOneWidget);
  });

  testWidgets('Learn shows how far each level is', (tester) async {
    phone(tester);
    final store = ProgressStore.memory();
    solveFor(store, lessons.first.technique);
    await tester.pumpWidget(SudokuApp(store: store));
    final total = levelProgress(store, 1).total;
    expect(find.text('1 / $total'), findsOneWidget);
  });

  testWidgets('the daily card marks the days solved this week', (tester) async {
    phone(tester);
    final semantics = tester.ensureSemantics();
    final store = ProgressStore.memory(now: () => wednesday)
      ..recordDaily('2026-10-12', mistakes: 0, hints: 0);
    await tester.pumpWidget(SudokuApp(store: store));
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('week-dots')), findsOneWidget);
    final label = tester.getSemantics(find.byKey(const Key('week-dots'))).label;
    expect(label, contains('Mon: solved'));
    expect(label, contains('Tue: not solved'));
    semantics.dispose();
  });

  test('a week runs Monday to Sunday', () {
    final days = weekOf(wednesday);
    expect(days.first, DateTime(2026, 10, 12));
    expect(days.last, DateTime(2026, 10, 18));
  });

  testWidgets('Practice lists weak spots with their accuracy', (tester) async {
    phone(tester);
    final store = ProgressStore.memory();
    await tester.pumpWidget(SudokuApp(store: store));
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weak-spots')), findsNothing);

    for (var i = 0; i < 4; i++) {
      store.recordTechnique(Technique.xWing.name, right: false);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weak-spots')), findsOneWidget);
    expect(find.text('0% right'), findsOneWidget);
    expect(find.byTooltip('Drill ${Technique.xWing.label}'), findsOneWidget);
  });

  testWidgets('the legend names the board colours', (tester) async {
    await tester.pumpWidget(testApp(const BoardLegend()));
    expect(find.text('Look here'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Ruled out'), findsOneWidget);
  });
}
