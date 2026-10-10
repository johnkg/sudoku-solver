import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';
import 'package:sudoku_solver/ui/solve_controller.dart';
import 'package:sudoku_solver/ui/solve_screen.dart';
import 'package:sudoku_solver/ui/stars.dart';

import '../support.dart';

void main() {
  final text = warmUp.text;

  group('SolveController save and restore', () {
    late SolveController c;
    setUp(() {
      c = SolveController(text);
      final cell = c.board.values.indexOf(0);
      c.select(cell);
      c.enter(c.solution.values[cell]); // a player move
      c.findNextStep();
      c.showMove();
      c.applyPending(); // a solver step
      c.select(c.board.values.indexOf(0));
      c.enter(c.board.candidates[c.selected!] == 0 ? 1 : 9); // maybe a mistake
    });

    test('round trips board, history, and counters', () {
      final restored = SolveController.restore(text, c.toJson());
      expect(restored.board.toLine(), c.board.toLine());
      expect(restored.board.candidates, c.board.candidates);
      expect(restored.moveCount, c.moveCount);
      expect(restored.applied, c.applied);
      expect(restored.mistakes, c.mistakes);
      expect(restored.hintsUsed, c.hintsUsed);
      expect(restored.movesShown, c.movesShown);
    });

    test('undo works after restoring', () {
      final restored = SolveController.restore(text, c.toJson());
      final moves = restored.moveCount;
      restored.undo();
      expect(restored.moveCount, moves - 1);
      expect(restored.applied.length, c.applied.length - 1);
    });

    test('survives a trip through JSON text', () {
      final json = c.toJson();
      // Encoding to text and back turns lists into List<dynamic>.
      final restored = SolveController.restore(
        text,
        (jsonRoundTrip(json) as Map).cast<String, Object?>(),
      );
      expect(restored.board.toLine(), c.board.toLine());
    });

    test('rejects a saved board with a wrong digit', () {
      final json = c.toJson();
      final board = (json['board']! as Map<String, Object?>);
      final values = List<int>.of(board['values']! as List<int>);
      final empty = values.indexOf(0);
      values[empty] = (c.solution.values[empty] % 9) + 1;
      final candidates = List<int>.of(board['candidates']! as List<int>)
        ..[empty] = 0;
      json['board'] = {'values': values, 'candidates': candidates};
      expect(() => SolveController.restore(text, json), throwsFormatException);
    });

    test('rejects a saved board that changes a given', () {
      final json = c.toJson();
      final board = (json['board']! as Map<String, Object?>);
      final values = List<int>.of(board['values']! as List<int>);
      final given = c.givens.first;
      values[given] = (values[given] % 9) + 1;
      json['board'] = {'values': values, 'candidates': board['candidates']};
      expect(() => SolveController.restore(text, json), throwsFormatException);
    });

    test('rejects a board that lost the right candidate', () {
      final json = c.toJson();
      final board = (json['board']! as Map<String, Object?>);
      final candidates = List<int>.of(board['candidates']! as List<int>);
      final values = board['values']! as List<int>;
      final empty = values.indexOf(0);
      candidates[empty] &= ~digitBit(c.solution.values[empty]);
      json['board'] = {'values': values, 'candidates': candidates};
      expect(() => SolveController.restore(text, json), throwsFormatException);
    });

    test('rejects garbage', () {
      expect(
        () => SolveController.restore(text, {'board': 'nope'}),
        throwsA(anything),
      );
      expect(() => SolveController.restore(text, {}), throwsA(anything));
    });
  });

  group('Board.fromState', () {
    test('rejects wrong sizes and impossible numbers', () {
      expect(() => Board.fromState([1], [0]), throwsFormatException);
      expect(
        () => Board.fromState(List.filled(81, 10), List.filled(81, 0)),
        throwsFormatException,
      );
      expect(
        () => Board.fromState(List.filled(81, 0), List.filled(81, 1000)),
        throwsFormatException,
      );
      expect(
        () => Board.fromState(List.filled(81, 1), List.filled(81, 1)),
        throwsFormatException,
      );
    });
  });

  group('SolveScreen', () {
    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(500, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> tapCell(WidgetTester tester, int target) async {
      final rect = tester.getRect(find.byType(BoardView));
      final size = rect.width / 9;
      await tester.tapAt(
        rect.topLeft +
            Offset(
              (Board.columnOf(target) + 0.5) * size,
              (Board.rowOf(target) + 0.5) * size,
            ),
      );
      await tester.pump();
    }

    Future<void> playMove(WidgetTester tester, int cell, int digit) async {
      await tapCell(tester, cell);
      await tester.tap(find.widgetWithText(FilledButton, '$digit'));
      await tester.pump();
    }

    testWidgets('a game in progress is saved and resumed', (tester) async {
      bigScreen(tester);
      final store = ProgressStore.memory();
      final solution = solveByBacktracking(Board.parse(text))!;
      final cell = Board.parse(text).values.indexOf(0);

      await tester.pumpWidget(
        testApp(SolveScreen(puzzle: warmUp), store: store),
      );
      await playMove(tester, cell, solution.values[cell]);
      expect(store.hasSavedGame(warmUp.id), isTrue);

      // Leave the screen, then come back.
      await tester.pumpWidget(testApp(const SizedBox(), store: store));
      await tester.pumpWidget(
        testApp(SolveScreen(puzzle: warmUp), store: store),
      );
      expect(find.text('1 move so far'), findsOneWidget);
    });

    testWidgets('starting over forgets the saved game', (tester) async {
      bigScreen(tester);
      final store = ProgressStore.memory();
      final solution = solveByBacktracking(Board.parse(text))!;
      final cell = Board.parse(text).values.indexOf(0);

      await tester.pumpWidget(
        testApp(SolveScreen(puzzle: warmUp), store: store),
      );
      await playMove(tester, cell, solution.values[cell]);
      await tester.tap(find.byTooltip('Start over'));
      await tester.pump();
      expect(store.hasSavedGame(warmUp.id), isFalse);
    });

    testWidgets('a bad saved game is dropped and the puzzle starts fresh', (
      tester,
    ) async {
      bigScreen(tester);
      final store = ProgressStore.memory()
        ..saveGame(warmUp.id, {'board': 'broken'});
      await tester.pumpWidget(
        testApp(SolveScreen(puzzle: warmUp), store: store),
      );
      expect(find.text('Ready when you are'), findsOneWidget);
      expect(store.hasSavedGame(warmUp.id), isFalse);
    });

    testWidgets('solving records stars and unlocks the next level', (
      tester,
    ) async {
      bigScreen(tester);
      final store = ProgressStore.memory();
      // The other level-1 techniques are already practised.
      for (final t in [Technique.fullHouse, Technique.hiddenSingle]) {
        store.recordSolve(
          puzzleLibrary.firstWhere((p) => p.technique == t).id,
          mistakes: 0,
          hints: 0,
        );
      }
      final start = Board.parse(text);
      final solution = solveByBacktracking(start)!;

      await tester.pumpWidget(
        testApp(SolveScreen(puzzle: warmUp), store: store),
      );
      for (var cell = 0; cell < 81; cell++) {
        if (start.values[cell] == 0) {
          await playMove(tester, cell, solution.values[cell]);
        }
      }
      await tester.pumpAndSettle();

      expect(find.text('Solved!'), findsOneWidget);
      expect(find.text('Level 2 · Easy unlocked!'), findsOneWidget);
      expect(store.isSolved(warmUp.id), isTrue);
      expect(store.recordFor(warmUp.id)!.stars, 3);
      expect(store.hasSavedGame(warmUp.id), isFalse);
    });
  });

  group('tabs', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(500, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('locked levels say how to unlock them', (tester) async {
      phone(tester);
      await tester.pumpWidget(SudokuApp(store: ProgressStore.memory()));
      expect(
        find.text(
          'Solve a practice puzzle for every Level 1 technique to unlock this level.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    });

    testWidgets('solving level 1 opens level 2 in both tabs', (tester) async {
      phone(tester);
      final store = ProgressStore.memory();
      await tester.pumpWidget(SudokuApp(store: store));
      expect(
        find.text(
          'Solve a practice puzzle for every Level 1 technique to unlock this level.',
        ),
        findsOneWidget,
      );
      for (final t in Technique.values.where((t) => t.level == 1)) {
        store.recordSolve(
          puzzleLibrary.firstWhere((p) => p.technique == t).id,
          mistakes: 0,
          hints: 0,
        );
      }
      await tester.pump();
      expect(
        find.text(
          'Solve a practice puzzle for every Level 1 technique to unlock this level.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Solve a practice puzzle for every Level 2 technique to unlock this level.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('practice tab shows stars, progress and in-progress games', (
      tester,
    ) async {
      phone(tester);
      final store = ProgressStore.memory()
        ..recordSolve('nakedSingle', mistakes: 1, hints: 0)
        ..saveGame('pointingPair', {});
      await tester.pumpWidget(SudokuApp(store: store));
      await tester.tap(find.text('Practice'));
      await tester.pumpAndSettle();
      expect(
        find.text('1 of ${puzzleLibrary.length} puzzles solved'),
        findsOneWidget,
      );
      expect(tester.widget<Stars>(find.byType(Stars)).count, 2);
    });

    testWidgets('the menu can unlock everything and reset progress', (
      tester,
    ) async {
      phone(tester);
      final store = ProgressStore.memory();
      await tester.pumpWidget(SudokuApp(store: store));

      await tester.tap(find.byTooltip('Progress options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlock all levels'));
      await tester.pumpAndSettle();
      expect(store.unlockedAll, isTrue);

      await tester.tap(find.byTooltip('Progress options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(store.unlockedAll, isFalse);
    });
  });
}

Object? jsonRoundTrip(Object? value) => jsonDecode(jsonEncode(value));
