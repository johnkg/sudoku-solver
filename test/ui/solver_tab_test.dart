import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/scan/scan_result.dart';
import 'package:sudoku_solver/ui/solver/puzzle_text.dart';
import 'package:sudoku_solver/ui/solver_tab.dart';

import '../support.dart';

void main() {
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openSolver(WidgetTester tester) async {
    phoneSize(tester);
    await tester.pumpWidget(SudokuApp(store: ProgressStore.memory()));
    await tester.tap(find.text('Solver'));
    await tester.pumpAndSettle();
  }

  Future<void> paste(WidgetTester tester, String text) async {
    await tester.tap(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import-field')), text);
    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();
  }

  test('parsePuzzleText accepts digits and blank markers only', () {
    expect(parsePuzzleText('.' * 81), List.filled(81, 0));
    expect(parsePuzzleText('1-_*0${'.' * 76}')!.take(5), [1, 0, 0, 0, 0]);
    expect(parsePuzzleText('1' * 80), isNull);
    expect(parsePuzzleText('x${'.' * 80}'), isNull);
  });

  testWidgets('starts blank and takes typed digits', (tester) async {
    await openSolver(tester);
    expect(
      find.text('Tap a cell, then a digit, to type in your puzzle.'),
      findsOneWidget,
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(BoardView)) + const Offset(20, 20),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('entry-5')));
    await tester.pump();
    expect(find.text('1 digit entered.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('erase-entry')));
    await tester.pump();
    expect(
      find.text('Tap a cell, then a digit, to type in your puzzle.'),
      findsOneWidget,
    );
  });

  testWidgets('flags a repeated digit and refuses to teach it', (tester) async {
    await openSolver(tester);
    await paste(tester, '11${'.' * 79}');
    expect(find.textContaining('Red digits break a rule'), findsOneWidget);

    await tester.tap(find.byKey(const Key('teach-me')));
    await tester.pump();
    expect(find.text('Fix the red digits first.'), findsOneWidget);
  });

  testWidgets('rejects a bad paste and a puzzle with no solution', (
    tester,
  ) async {
    await openSolver(tester);
    await tester.tap(find.byKey(const Key('import')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import-field')), '123');
    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pump();
    expect(find.text('That is not 81 digits and blanks.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Row 1 holds 1-8 with a 9 forced into r1c9 by the column, but r2c9..
    // already holds 9, so r1c9 has nothing left.
    await paste(tester, '12345678.${'.' * 8}9${'.' * 63}');
    await tester.tap(find.byKey(const Key('teach-me')));
    await tester.pump();
    expect(find.textContaining('no solution'), findsOneWidget);
  });

  testWidgets('warns when a puzzle has several solutions', (tester) async {
    await openSolver(tester);
    await paste(tester, '1${'.' * 80}');
    await tester.tap(find.byKey(const Key('teach-me')));
    await tester.pumpAndSettle();
    expect(find.text('More than one solution'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('How to solve it'), findsNothing);
  });

  testWidgets('walks through a puzzle and links to the lesson', (tester) async {
    await openSolver(tester);
    await paste(tester, warmUp.text);
    await tester.tap(find.byKey(const Key('teach-me')));
    await tester.pumpAndSettle();

    expect(find.text('How to solve it'), findsOneWidget);
    expect(find.textContaining('Step 1 of'), findsOneWidget);
    expect(find.byKey(const Key('prev-step')).evaluate().isNotEmpty, isTrue);

    await tester.tap(find.byKey(const Key('next-step')));
    await tester.pump();
    expect(find.textContaining('Step 2 of'), findsOneWidget);
    await tester.tap(find.byKey(const Key('prev-step')));
    await tester.pump();
    expect(find.textContaining('Step 1 of'), findsOneWidget);

    // The technique chip opens its lesson.
    final link = find.byWidgetPredicate(
      (w) => w is ActionChip && (w.key.toString()).contains('technique-'),
    );
    await tester.tap(link.first);
    await tester.pumpAndSettle();
    expect(find.text('The idea'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Jump to the end with the slider.
    final total = int.parse(
      RegExp(r'Step 1 of (\d+)')
          .firstMatch(
            tester.widget<Text>(find.textContaining('Step 1 of')).data!,
          )!
          .group(1)!,
    );
    for (var i = 0; i < total; i++) {
      await tester.tap(find.byKey(const Key('next-step')));
      await tester.pump();
    }
    expect(find.text('Solved in $total steps.'), findsOneWidget);
    expect(find.text('Techniques used'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('next-step'))).onPressed,
      isNull,
    );
  });

  testWidgets('says so when logic gets stuck and can reveal the answer', (
    tester,
  ) async {
    await openSolver(tester);
    await paste(tester, '1${'.' * 80}');
    await tester.tap(find.byKey(const Key('teach-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show me anyway'));
    await tester.pumpAndSettle();

    expect(find.text('The solver is stuck.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reveal')));
    await tester.pump();
    expect(
      find.text('The rest was filled in by trial and error.'),
      findsOneWidget,
    );
  });

  group('scanning a photo', () {
    Future<void> openWith(WidgetTester tester, PhotoScanner scanner) async {
      phoneSize(tester);
      await tester.pumpWidget(
        testApp(Scaffold(body: SolverTab(scanner: scanner))),
      );
    }

    testWidgets('fills the grid and tints the cells it doubts', (tester) async {
      var picked = false;
      await openWith(tester, (onPicked) async {
        picked = true;
        onPicked();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return ScanResult(warmUp.text, {2, 4});
      });
      await tester.tap(find.byKey(const Key('scan-photo')));
      await tester.pump();
      expect(find.text('Reading the photo…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(picked, isTrue);
      expect(find.text('Reading the photo…'), findsNothing);
      expect(find.textContaining('tinted cells'), findsOneWidget);
      expect(tester.widget<BoardView>(find.byType(BoardView)).marked, {2, 4});
      expect(
        tester
            .widget<BoardView>(find.byType(BoardView))
            .board
            .values
            .where((v) => v != 0)
            .length,
        30,
      );

      // Typing over a doubtful cell clears only that cell's tint.
      await tester.tapAt(
        tester.getTopLeft(find.byType(BoardView)) +
            Offset(tester.getSize(find.byType(BoardView)).width / 9 * 2.5, 20),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('entry-4')));
      await tester.pump();
      expect(tester.widget<BoardView>(find.byType(BoardView)).marked, {4});
    });

    testWidgets('does nothing if no photo is chosen', (tester) async {
      await openWith(tester, (onPicked) async => null);
      await tester.tap(find.byKey(const Key('scan-photo')));
      await tester.pumpAndSettle();
      expect(
        find.text('Tap a cell, then a digit, to type in your puzzle.'),
        findsOneWidget,
      );
    });

    testWidgets('shows why a photo could not be read', (tester) async {
      await openWith(tester, (onPicked) async {
        onPicked();
        throw const ScanFailure('I could not find the grid in that photo.');
      });
      await tester.tap(find.byKey(const Key('scan-photo')));
      await tester.pumpAndSettle();
      expect(
        find.text('I could not find the grid in that photo.'),
        findsOneWidget,
      );
      expect(find.text('Reading the photo…'), findsNothing);
    });

    testWidgets('is not offered where photos cannot be read', (tester) async {
      await openSolver(tester);
      expect(find.byKey(const Key('scan-photo')), findsNothing);
    });
  });

  group('playing the entered puzzle', () {
    testWidgets('opens the solve screen on the entered puzzle', (tester) async {
      await openSolver(tester);
      await paste(tester, warmUp.text);
      await tester.tap(find.byKey(const Key('play-it')));
      await tester.pumpAndSettle();

      expect(find.text('My puzzle'), findsOneWidget);
      expect(find.byKey(const Key('digit-5')), findsOneWidget);
      expect(find.byTooltip('Get a hint'), findsOneWidget);
    });

    testWidgets('needs one solution', (tester) async {
      await openSolver(tester);
      await paste(tester, '1${'.' * 80}');
      await tester.tap(find.byKey(const Key('play-it')));
      await tester.pumpAndSettle();
      expect(find.textContaining('exactly one solution'), findsOneWidget);
      expect(find.text('My puzzle'), findsNothing);
    });

    testWidgets('asks for a puzzle and rejects clashes', (tester) async {
      await openSolver(tester);
      await tester.tap(find.byKey(const Key('play-it')));
      await tester.pump();
      expect(find.text('Enter a puzzle first.'), findsOneWidget);

      await paste(tester, '11${'.' * 79}');
      await tester.tap(find.byKey(const Key('play-it')));
      await tester.pumpAndSettle();
      expect(find.text('Fix the red digits first.'), findsOneWidget);
    });

    testWidgets('does not save progress for it', (tester) async {
      final store = ProgressStore.memory();
      phoneSize(tester);
      await tester.pumpWidget(SudokuApp(store: store));
      await tester.tap(find.text('Solver'));
      await tester.pumpAndSettle();
      await paste(tester, warmUp.text);
      await tester.tap(find.byKey(const Key('play-it')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('digit-5')));
      await tester.pump();
      expect(store.hasSavedGame('custom'), isFalse);
    });
  });
}
