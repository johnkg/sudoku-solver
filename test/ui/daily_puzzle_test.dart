import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/daily_puzzle.dart';
import 'package:sudoku_solver/ui/stars.dart';

// 2026-10-12 is a Monday, so the daily puzzle is Level 1.
final monday = DateTime(2026, 10, 12);
const mondayPuzzle =
    '819647035006500987072389061950026813031094070287135600460951708098263150005478006';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openPractice(WidgetTester tester, ProgressStore store) async {
    await tester.pumpWidget(SudokuApp(store: store));
    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 400 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> playMove(WidgetTester tester, int cell, int digit) async {
    final rect = tester.getRect(find.byType(BoardView));
    final size = rect.width / 9;
    await tester.tapAt(
      rect.topLeft +
          Offset(
            (Board.columnOf(cell) + 0.5) * size,
            (Board.rowOf(cell) + 0.5) * size,
          ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '$digit'));
    await tester.pump();
  }

  test('date labels', () {
    expect(dailyDateLabel(DateTime(2026, 10, 12)), 'Mon, Oct 12');
    expect(dailyDateLabel(DateTime(2027, 1, 3)), 'Sun, Jan 3');
  });

  testWidgets('the card names today, its level, and offers to play', (
    tester,
  ) async {
    phone(tester);
    await openPractice(tester, ProgressStore.memory(now: () => monday));
    expect(find.text('Daily puzzle · Mon, Oct 12'), findsOneWidget);
    expect(
      find.textContaining('Level 1 · Beginner. The same puzzle'),
      findsOneWidget,
    );
    expect(find.text('Play today\'s puzzle'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });

  testWidgets('the level changes with the weekday', (tester) async {
    phone(tester);
    final saturday = DateTime(2026, 10, 10);
    await openPractice(tester, ProgressStore.memory(now: () => saturday));
    expect(
      find.textContaining('Level 5 · Expert. The same puzzle'),
      findsOneWidget,
    );
  });

  testWidgets('the card shows the streak', (tester) async {
    phone(tester);
    final store = ProgressStore.memory(now: () => monday)
      ..recordDaily('2026-10-10', mistakes: 0, hints: 0)
      ..recordDaily('2026-10-11', mistakes: 0, hints: 0);
    await openPractice(tester, store);
    expect(find.text('2 days'), findsOneWidget);
  });

  testWidgets('playing finds the puzzle, opens it, and remembers it', (
    tester,
  ) async {
    phone(tester);
    final store = ProgressStore.memory(now: () => monday);
    await openPractice(tester, store);

    await tester.tap(find.text('Play today\'s puzzle'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Daily · Mon, Oct 12'));
    await tester.pumpAndSettle();

    expect(find.text('Daily · Mon, Oct 12'), findsOneWidget);
    expect(store.dailyPuzzleText('2026-10-12')!, mondayPuzzle);
    expect(find.byType(BoardView), findsOneWidget);
  });

  testWidgets('a remembered puzzle opens without searching', (tester) async {
    phone(tester);
    final store = ProgressStore.memory(now: () => monday)
      ..saveDailyPuzzle('2026-10-12', mondayPuzzle);
    await openPractice(tester, store);
    await tester.tap(find.text('Play today\'s puzzle'));
    await tester.pumpAndSettle();
    expect(find.text('Daily · Mon, Oct 12'), findsOneWidget);
    expect(find.textContaining('Preparing'), findsNothing);
  });

  testWidgets('solving it records the day, the streak, and not the library', (
    tester,
  ) async {
    phone(tester);
    final store = ProgressStore.memory(now: () => monday)
      ..saveDailyPuzzle('2026-10-12', mondayPuzzle)
      ..recordDaily('2026-10-11', mistakes: 0, hints: 0);
    await openPractice(tester, store);
    await tester.tap(find.text('Play today\'s puzzle'));
    await tester.pumpAndSettle();

    final start = Board.parse(mondayPuzzle);
    final solution = solveByBacktracking(start)!;
    for (var cell = 0; cell < 81; cell++) {
      if (start.values[cell] == 0) {
        await playMove(tester, cell, solution.values[cell]);
      }
    }
    await tester.pumpAndSettle();

    expect(find.text('Solved!'), findsOneWidget);
    expect(find.text('2 days in a row'), findsOneWidget);
    expect(store.dailyRecord('2026-10-12')!.stars, 3);
    expect(store.dailyStreak, 2);
    expect(store.solvedCount, 0);
    expect(find.textContaining('unlocked!'), findsNothing);
    expect(
      store.hasSavedGame(ProgressStore.dailyGameId('2026-10-12')),
      isFalse,
    );

    // Back on the list the card shows the result.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Play again'), findsOneWidget);
    expect(find.byType(Stars), findsWidgets);
  });

  testWidgets('a game in progress says Continue and resumes', (tester) async {
    phone(tester);
    final store = ProgressStore.memory(now: () => monday)
      ..saveDailyPuzzle('2026-10-12', mondayPuzzle);
    await openPractice(tester, store);
    await tester.tap(find.text('Play today\'s puzzle'));
    await tester.pumpAndSettle();

    final start = Board.parse(mondayPuzzle);
    final solution = solveByBacktracking(start)!;
    final cell = start.values.indexOf(0);
    await playMove(tester, cell, solution.values[cell]);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('1 move so far'), findsOneWidget);
  });

  testWidgets('cancelling the search leaves nothing saved', (tester) async {
    phone(tester);
    final store = ProgressStore.memory(now: () => DateTime(2026, 10, 10));
    await openPractice(tester, store);
    await tester.tap(find.text('Play today\'s puzzle'));
    await tester.pump();
    expect(find.text('Preparing today\'s puzzle…'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.dailyPuzzleText('2026-10-10'), isNull);
    expect(find.byType(BoardView), findsNothing);
  });
}
