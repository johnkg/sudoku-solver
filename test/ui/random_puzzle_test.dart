import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/random_puzzle.dart';
import 'package:sudoku_solver/ui/solve_screen.dart';

import '../support.dart';

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

  /// Lets the background search run until [finder] shows up.
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 400 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  group('random puzzle card', () {
    testWidgets('only unlocked levels can be chosen', (tester) async {
      phone(tester);
      await openPractice(tester, ProgressStore.memory());
      ChoiceChip chip(int level) => tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Level $level'),
      );
      expect(chip(1).onSelected, isNotNull);
      for (final level in [2, 3, 4, 5]) {
        expect(chip(level).onSelected, isNull);
      }
    });

    testWidgets('unlocking everything opens every level', (tester) async {
      phone(tester);
      await openPractice(tester, ProgressStore.memory()..unlockAllLevels());
      for (final level in [1, 2, 3, 4, 5]) {
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Level $level'),
              )
              .onSelected,
          isNotNull,
        );
      }
    });

    testWidgets('playing opens a random puzzle without recording it', (
      tester,
    ) async {
      phone(tester);
      final store = ProgressStore.memory();
      await openPractice(tester, store);

      await tester.tap(find.text('Play random puzzle'));
      await tester.pump();

      await pumpUntilFound(tester, find.text('Random · Level 1'));
      await tester.pumpAndSettle();
      expect(find.text('Random · Level 1'), findsOneWidget);
      expect(find.byType(BoardView), findsOneWidget);
      expect(find.text('Looking for a Level 1 puzzle…'), findsNothing);
      expect(store.solvedCount, 0);
      expect(store.hasSavedGame('random'), isFalse);
    });

    testWidgets('a chosen level is used', (tester) async {
      phone(tester);
      await openPractice(tester, ProgressStore.memory()..unlockAllLevels());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Level 2'));
      await tester.pump();
      await tester.tap(find.text('Play random puzzle'));
      await tester.pump();
      await pumpUntilFound(tester, find.text('Random · Level 2'));
      await tester.pumpAndSettle();
      expect(find.text('Random · Level 2'), findsOneWidget);
    });

    testWidgets('cancel closes the dialog and stays on the list', (
      tester,
    ) async {
      phone(tester);
      // A search that only ends when cancelled, so the dialog stays up.
      final original = randomPuzzleFinder;
      randomPuzzleFinder = (level, random, {isCancelled}) async {
        while (!(isCancelled?.call() ?? false)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        return null;
      };
      addTearDown(() => randomPuzzleFinder = original);
      await openPractice(tester, ProgressStore.memory()..unlockAllLevels());
      await tester.tap(find.widgetWithText(ChoiceChip, 'Level 5'));
      await tester.pump();
      await tester.tap(find.text('Play random puzzle'));
      await tester.pump();
      expect(find.text('Looking for a Level 5 puzzle…'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Looking for a Level 5 puzzle…'), findsNothing);
      expect(find.text('Random puzzle'), findsOneWidget);
      expect(find.byType(BoardView), findsNothing);
    });
  });

  group('SolveScreen without progress', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(500, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
      await tester.tap(find.byKey(Key('digit-$digit')));
      await tester.pump();
    }

    testWidgets('nothing is saved or recorded, and a new puzzle is offered', (
      tester,
    ) async {
      bigScreen(tester);
      final store = ProgressStore.memory();
      var newPuzzleCalls = 0;
      final start = Board.parse(warmUp.text);
      final solution = solveByBacktracking(start)!;

      await tester.pumpWidget(
        testApp(
          SolveScreen(
            puzzle: warmUp,
            recordProgress: false,
            onNewPuzzle: () => newPuzzleCalls++,
          ),
          store: store,
        ),
      );

      final first = start.values.indexOf(0);
      await playMove(tester, first, solution.values[first]);
      expect(store.hasSavedGame(warmUp.id), isFalse);

      for (var cell = 0; cell < 81; cell++) {
        if (start.values[cell] == 0 && cell != first) {
          await playMove(tester, cell, solution.values[cell]);
        }
      }
      await tester.pumpAndSettle();
      expect(find.text('Solved!'), findsOneWidget);
      expect(store.solvedCount, 0);
      expect(find.textContaining('unlocked!'), findsNothing);

      await tester.tap(find.text('New random puzzle'));
      expect(newPuzzleCalls, 1);
    });

    testWidgets('an existing save is ignored', (tester) async {
      bigScreen(tester);
      final store = ProgressStore.memory()..saveGame(warmUp.id, {'broken': 1});
      await tester.pumpWidget(
        testApp(
          SolveScreen(puzzle: warmUp, recordProgress: false),
          store: store,
        ),
      );
      expect(find.text('Ready when you are'), findsOneWidget);
      // The save is left alone, not cleared.
      expect(store.hasSavedGame(warmUp.id), isTrue);
    });
  });
}
