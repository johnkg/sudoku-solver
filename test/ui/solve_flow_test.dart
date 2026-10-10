import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';
import 'package:sudoku_solver/ui/solve_controller.dart';

void main() {
  group('puzzleLibrary', () {
    test('every puzzle is unique and needs exactly its labelled technique', () {
      for (final entry in puzzleLibrary) {
        final rating = ratePuzzle(Board.parse(entry.text));
        expect(rating.unique, isTrue, reason: entry.title);
        expect(rating.required, entry.technique, reason: entry.title);
      }
    });

    test('ids and puzzles are unique', () {
      expect(
        puzzleLibrary.map((p) => p.id).toSet().length,
        puzzleLibrary.length,
      );
      expect(
        puzzleLibrary.map((p) => p.text).toSet().length,
        puzzleLibrary.length,
      );
    });

    test('every technique has at least one practice puzzle', () {
      for (final technique in Technique.values) {
        expect(
          puzzleLibrary.any((p) => p.technique == technique),
          isTrue,
          reason: technique.label,
        );
      }
    });

    test('covers every level', () {
      expect({for (final p in puzzleLibrary) p.level}, {1, 2, 3, 4, 5});
    });

    test('every puzzle is solved step by step without a wrong move', () {
      for (final entry in puzzleLibrary) {
        final board = Board.parse(entry.text);
        final solution = solveByBacktracking(board)!;
        final result = const Solver().solve(board);
        expect(result.solved, isTrue, reason: entry.title);
        expect(result.board.toLine(), solution.toLine(), reason: entry.title);
      }
    });
  });

  group('SolveController', () {
    late SolveController controller;
    setUp(() => controller = SolveController(warmUp.text));

    test('previews a step without changing the board', () {
      final before = controller.board.toLine();
      controller.findNextStep();
      expect(controller.pending, isNotNull);
      expect(controller.board.toLine(), before);
    });

    test('apply then undo restores the board', () {
      final before = controller.board.toLine();
      controller.findNextStep();
      controller.applyPending();
      expect(controller.applied, hasLength(1));
      controller.undo();
      expect(controller.board.toLine(), before);
      expect(controller.applied, isEmpty);
    });

    test('can be walked to a solved board', () {
      var guard = 0;
      while (!controller.solved && guard++ < 500) {
        controller.findNextStep();
        controller.applyPending();
      }
      expect(controller.solved, isTrue);
    });

    test('reports stuck when no technique applies', () {
      final stuck = SolveController(
        '070004001000300090941060050006008000800210000030400000700100000200000800003900200',
      );
      var guard = 0;
      while (!stuck.stuck && guard++ < 500) {
        stuck.findNextStep();
        stuck.applyPending();
      }
      expect(stuck.stuck, isTrue);
      expect(stuck.solved, isFalse);
    });

    test('restart clears progress', () {
      controller.findNextStep();
      controller.applyPending();
      controller.restart();
      expect(controller.canUndo, isFalse);
      expect(controller.applied, isEmpty);
    });
  });

  group('SolveScreen', () {
    testWidgets('shows a step, applies it, and counts it', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(SudokuApp(store: ProgressStore.memory()));
      await tester.tap(find.text('Practice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Warm-up'));
      await tester.pumpAndSettle();
      expect(find.text('Ready when you are'), findsOneWidget);

      await tester.tap(find.byTooltip('Get a hint'));
      await tester.pumpAndSettle();
      expect(find.text('Hint 1 of 3'), findsOneWidget);
      expect(find.text('Apply'), findsNothing);

      await tester.tap(find.text('Another hint'));
      await tester.pumpAndSettle();
      expect(find.text('Hint 2 of 3'), findsOneWidget);

      await tester.tap(find.text('Show the move'));
      await tester.pumpAndSettle();
      expect(find.text('Apply'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('1 move so far'), findsOneWidget);
    });
  });
}
