import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';
import 'package:sudoku_solver/ui/solve_controller.dart';
import 'package:sudoku_solver/ui/solve_screen.dart';

void main() {
  late SolveController c;
  late int cell; // an empty cell
  late int right; // its correct digit
  late int wrongButLegal; // a candidate there that is not the answer

  setUp(() {
    c = SolveController(warmUp.text);
    cell = c.board.values.indexOf(0);
    right = c.solution.values[cell];
    wrongButLegal = digitsOf(c.board.candidates[cell])
        .firstWhere((d) => d != right);
    c.select(cell);
  });

  group('placing digits', () {
    test('a correct digit is placed and peers lose the candidate', () {
      final peer = Board.peers[cell].firstWhere(
        (p) => c.board.values[p] == 0 && hasDigit(c.board.candidates[p], right),
      );
      c.enter(right);
      expect(c.board.values[cell], right);
      expect(hasDigit(c.board.candidates[peer], right), isFalse);
      expect(c.mistakes, 0);
      expect(c.moveCount, 1);
    });

    test('a legal but wrong digit is rejected and counted', () {
      c.enter(wrongButLegal);
      expect(c.board.values[cell], 0);
      expect(c.mistakes, 1);
      expect(c.messageIsError, isTrue);
      expect(c.moveCount, 0);
    });

    test('a wrong digit is shown in the cell until erased', () {
      c.enter(wrongButLegal);
      expect(c.wrong[cell], wrongButLegal);
      expect(c.board.values[cell], 0);
      c.erase();
      expect(c.wrong, isEmpty);
      c.enter(wrongButLegal);
      c.enter(right);
      expect(c.wrong, isEmpty);
      expect(c.board.values[cell], right);
      expect(c.mistakes, 2);
    });

    test('a digit already in the row, column or box says where', () {
      final used = [
        for (final p in Board.peers[cell])
          if (c.board.values[p] != 0) c.board.values[p],
      ].first;
      c.enter(used);
      expect(c.board.values[cell], 0);
      expect(c.message, startsWith('There is already a $used in'));
      expect(c.mistakes, 1);
    });

    test('givens and filled cells cannot be changed', () {
      final given = c.givens.first;
      c.select(given);
      c.enter(1);
      expect(c.message, 'That cell is a given.');
      expect(c.mistakes, 0);

      c.select(cell);
      c.enter(right);
      c.enter(right);
      expect(c.message, 'That cell is already filled.');
    });

    test('entering with nothing selected asks for a cell', () {
      final fresh = SolveController(warmUp.text);
      fresh.enter(5);
      expect(fresh.message, 'Tap a cell first.');
    });
  });

  group('editing notes', () {
    test('notes start empty and the board still has its candidates', () {
      expect(c.marks.every((m) => m == 0), isTrue);
      expect(c.board.candidates[cell], isNot(0));
    });

    test('a digit is added as a note and toggled off again', () {
      c.setMode(EntryMode.notes);
      c.enter(wrongButLegal);
      expect(hasDigit(c.marks[cell], wrongButLegal), isTrue);
      expect(c.mistakes, 0);
      expect(c.moveCount, 0);
      expect(c.canUndo, isTrue);
      c.enter(wrongButLegal);
      expect(c.marks[cell], 0);
    });

    test('undo takes a note back', () {
      c.setMode(EntryMode.notes);
      c.enter(right);
      c.undo();
      expect(c.marks[cell], 0);
    });

    test('erase clears the notes of a cell', () {
      c.setMode(EntryMode.notes);
      c.enter(right);
      c.enter(wrongButLegal);
      c.erase();
      expect(c.marks[cell], 0);
    });

    test('auto notes fill in every empty cell, then clear again', () {
      expect(c.notesFilled, isFalse);
      c.toggleAutoNotes();
      expect(c.notesFilled, isTrue);
      for (var i = 0; i < 81; i++) {
        expect(c.marks[i], c.board.values[i] == 0 ? c.board.candidates[i] : 0);
      }
      c.toggleAutoNotes();
      expect(c.notesFilled, isFalse);
      expect(c.marks.every((m) => m == 0), isTrue);
      c.undo();
      expect(c.notesFilled, isTrue);
    });

    test('auto notes complete a partly filled set instead of clearing it', () {
      c.setMode(EntryMode.notes);
      c.enter(right);
      c.toggleAutoNotes();
      expect(c.notesFilled, isTrue);
    });

    test('applying a hint removes its eliminations from the notes', () {
      final pointing = puzzleLibrary.firstWhere(
        (p) => p.technique == Technique.pointingPair,
      );
      c = SolveController(pointing.text);
      c.toggleAutoNotes();
      Step? step;
      while (true) {
        c.findNextStep();
        step = c.pending;
        if (step == null || step.eliminations.isNotEmpty) break;
        c.applyPending();
      }
      expect(step, isNotNull);
      c.applyPending();
      for (final e in step!.eliminations) {
        for (final d in e.digits) {
          expect(hasDigit(c.marks[e.cell], d), isFalse);
        }
      }
    });

    test('placing a digit clears it from the notes around it', () {
      c.toggleAutoNotes();
      final peer = Board.peers[cell].firstWhere(
        (p) => hasDigit(c.marks[p], right),
      );
      c.enter(right);
      expect(c.marks[cell], 0);
      expect(hasDigit(c.marks[peer], right), isFalse);
      c.undo();
      expect(hasDigit(c.marks[peer], right), isTrue);
    });
  });

  group('clock', () {
    test('ticks, pauses, restarts and is saved', () {
      c.tick();
      c.tick();
      expect(c.seconds.value, 2);
      c.togglePause();
      c.tick();
      expect(c.seconds.value, 2);
      c.togglePause();

      final again = SolveController.restore(warmUp.text, c.toJson());
      expect(again.seconds.value, 2);

      c.restart();
      expect(c.seconds.value, 0);
    });

    test('games saved before the clock existed start at zero', () {
      final json = c.toJson()..remove('seconds');
      expect(SolveController.restore(warmUp.text, json).seconds.value, 0);
    });
  });

  group('history and hints', () {
    test('undo reverses a player move but keeps the mistake count', () {
      c.enter(wrongButLegal);
      c.enter(right);
      expect(c.board.values[cell], right);
      c.undo();
      expect(c.board.values[cell], 0);
      expect(c.mistakes, 1);
    });

    test('hints work after the player has moved', () {
      c.enter(right);
      c.findNextStep();
      expect(c.pending, isNotNull);
      expect(c.hintsUsed, 1);
      c.applyPending();
      expect(c.applied, hasLength(1));
      c.undo();
      expect(c.applied, isEmpty);
      expect(c.moveCount, 1);
    });

    test('a player move clears a pending hint', () {
      c.findNextStep();
      expect(c.pending, isNotNull);
      c.select(cell);
      c.enter(right);
      expect(c.pending, isNull);
    });

    test('restart clears counters and selection', () {
      c.enter(wrongButLegal);
      c.findNextStep();
      c.restart();
      expect(c.mistakes, 0);
      expect(c.hintsUsed, 0);
      expect(c.selected, isNull);
    });

    test('the player can finish the puzzle alone', () {
      for (var i = 0; i < 81; i++) {
        if (c.board.values[i] != 0) continue;
        c.select(i);
        c.enter(c.solution.values[i]);
      }
      expect(c.solved, isTrue);
      expect(c.mistakes, 0);
    });
  });

  group('selection', () {
    test('moveSelection stays on the board', () {
      c.select(0);
      c.moveSelection(-1, -1);
      expect(c.selected, 0);
      c.select(80);
      c.moveSelection(1, 1);
      expect(c.selected, 80);
      c.moveSelection(-1, 0);
      expect(c.selected, 71);
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

    testWidgets('tap a cell and a digit button to place it', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));
      expect(find.text('Tap a cell, then pick a digit.'), findsOneWidget);

      await tapCell(tester, cell);
      expect(
        find.text('Pick the digit that goes in ${Board.cellName(cell)}.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(Key('digit-$right')));
      await tester.pump();
      expect(find.text('1 move so far'), findsOneWidget);
    });

    testWidgets('a wrong digit shows an error and a mistake', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));
      await tapCell(tester, cell);
      await tester.tap(find.byKey(Key('digit-$wrongButLegal')));
      await tester.pump();
      expect(find.textContaining('Not $wrongButLegal.'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('mistakes-value'))).data,
        '1/3',
      );
    });

    testWidgets('three mistakes offer to start over', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));
      await tapCell(tester, cell);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(Key('digit-$wrongButLegal')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Out of mistakes'), findsOneWidget);

      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();
      expect(find.text('Out of mistakes'), findsNothing);
      await tester.tap(find.byKey(Key('digit-$wrongButLegal')));
      await tester.pumpAndSettle();
      expect(find.text('Out of mistakes'), findsNothing);
    });

    testWidgets('start over from the limit dialog resets the game', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));
      await tapCell(tester, cell);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(Key('digit-$wrongButLegal')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start over'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('mistakes-value'))).data,
        '0/3',
      );
    });

    testWidgets('the clock runs, and stops while paused', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));
      String time() =>
          tester.widget<Text>(find.byKey(const Key('time-value'))).data!;
      expect(time(), '0:00');
      await tester.pump(const Duration(seconds: 3));
      expect(time(), '0:03');

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.byType(BoardView), findsNothing);
      expect(find.text('Paused'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(time(), '0:03');

      await tester.tap(find.text('Paused'));
      await tester.pump();
      expect(find.byType(BoardView), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(time(), '0:05');
    });

    testWidgets('keyboard digits and arrows work', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));
      await tapCell(tester, cell);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.textContaining(Board.cellName(cell + 1)), findsOneWidget);
    });

    testWidgets('board without a tap handler ignores taps', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BoardView(
            board: Board.parse('.' * 81),
            givens: const {},
            showCandidates: false,
          ),
        ),
      );
      await tester.tap(find.byType(BoardView));
      expect(tester.takeException(), isNull);
    });
  });
}
