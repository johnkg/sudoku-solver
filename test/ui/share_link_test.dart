import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/puzzle_link.dart';
import 'package:sudoku_solver/ui/solver_tab.dart';

import '../support.dart';

void main() {
  final cells = parsePuzzleText(warmUp.text)!;
  final base = Uri.parse('https://example.com/sudoku-solver/#/');

  group('links', () {
    test('write blanks as dots and drop the fragment', () {
      final link = puzzleLink(base, cells);
      expect(link.path, '/sudoku-solver/');
      expect(link.hasFragment, isFalse);
      expect(link.queryParameters['puzzle'], warmUp.text.replaceAll('0', '.'));
    });

    test('round trip', () {
      expect(puzzleFromUri(puzzleLink(base, cells)), cells);
    });

    test('ignore a missing or malformed puzzle', () {
      expect(puzzleFromUri(base), isNull);
      expect(puzzleFromUri(Uri.parse('https://x.test/?puzzle=123')), isNull);
    });
  });

  testWidgets('a shared link opens the Solver tab with the puzzle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      SudokuApp(store: ProgressStore.memory(), initialPuzzle: cells),
    );
    expect(find.text('Loaded the puzzle from the link.'), findsOneWidget);
    expect(
      tester
          .widget<BoardView>(find.byType(BoardView))
          .board
          .values
          .where((v) => v != 0)
          .length,
      cells.where((v) => v != 0).length,
    );
  });

  testWidgets('copies a link to the entered puzzle', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SolverTab(initialCells: cells, baseUri: base),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('copy-link')));
    await tester.pumpAndSettle();

    expect(copied, puzzleLink(base, cells).toString());
    expect(find.textContaining('Link copied'), findsOneWidget);
  });

  testWidgets('has nothing to copy on a blank grid', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const Scaffold(body: SolverTab())));
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('copy-link')))
          .onPressed,
      isNull,
    );
  });
}
