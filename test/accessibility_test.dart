import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/settings/settings.dart';
import 'package:sudoku_solver/ui/app.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/solve_screen.dart';
import 'package:sudoku_solver/ui/walkthrough_screen.dart';

import 'support.dart';

void main() {
  void phone(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('screen reader', () {
    testWidgets('each cell says where it is and what it holds', (tester) async {
      final handle = tester.ensureSemantics();
      phone(tester, const Size(500, 900));
      final board = Board.parse(warmUp.text);
      var tapped = -1;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: BoardView(
              board: board,
              givens: {
                for (var i = 0; i < 81; i++)
                  if (board.values[i] != 0) i,
              },
              showCandidates: true,
              wrong: const {2: 4},
              marks: List.generate(81, (i) => i == 3 ? 0x6 : 0),
              onCellTap: (c) => tapped = c,
            ),
          ),
        ),
      );

      await tester.pump();
      final nodes = <String, SemanticsNode>{};
      void collect(SemanticsNode node) {
        nodes[node.label] = node;
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.getSemantics(find.byType(BoardView)));

      expect(nodes, contains('Row 1, column 1, 5, given'));
      expect(nodes, contains('Row 1, column 3, 4, mistake'));
      expect(nodes, contains('Row 1, column 4, empty, notes 2, 3'));
      expect(nodes, contains('Row 1, column 5, 7, given'));
      expect(nodes.keys.where((l) => l.startsWith('Row ')), hasLength(81));

      RendererBinding.instance.renderViews.first.owner!.semanticsOwner!
          .performAction(
            nodes['Row 1, column 3, 4, mistake']!.id,
            SemanticsAction.tap,
          );
      expect(tapped, 2);
      handle.dispose();
    });
  });

  group('extra markings', () {
    testWidgets('are off by default and can be switched on', (tester) async {
      phone(tester, const Size(500, 2400));
      final settings = Settings.memory();
      expect(settings.patterns, isFalse);
      await tester.pumpWidget(
        SudokuApp(store: ProgressStore.memory(), settings: settings),
      );
      await tester.tap(find.byTooltip('Progress options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setting-patterns')));
      await tester.pump();
      expect(settings.patterns, isTrue);
    });

    testWidgets('a board with them still paints', (tester) async {
      phone(tester, const Size(500, 900));
      final board = Board.parse(warmUp.text);
      final step = const Solver().nextStep(board)!;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: BoardView(
              board: board,
              givens: const {},
              showCandidates: true,
              step: step,
              wrong: const {2: 4},
            ),
          ),
          settings: Settings.memory()..patterns = true,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('large text', () {
    for (final scale in [1.5, 2.0]) {
      for (final size in [const Size(360, 640), const Size(320, 568)]) {
        testWidgets('screens fit at ${scale}x on $size', (tester) async {
          phone(tester, size);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(
            SudokuApp(store: ProgressStore.memory()..unlockAllLevels()),
          );
          for (final tab in ['Practice', 'Solver', 'Learn']) {
            await tester.tap(find.text(tab).last);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: tab);
          }

          await tester.tap(find.byTooltip('Progress options'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Statistics'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'statistics');

          await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'solve screen');

          await tester.pumpWidget(
            testApp(WalkthroughScreen(start: Board.parse(warmUp.text))),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('mode-play')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'walkthrough');
        });
      }
    }
  });
}
