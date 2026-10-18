import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/ui/board_view.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';
import 'package:sudoku_solver/ui/technique_choices.dart';
import 'package:sudoku_solver/ui/walkthrough_screen.dart';

import '../support.dart';

void main() {
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> tapCell(WidgetTester tester, int cell) async {
    final box = find.byType(BoardView);
    final size = tester.getSize(box).width / 9;
    await tester.tapAt(
      tester.getTopLeft(box) +
          Offset(
            (Board.columnOf(cell) + 0.5) * size,
            (Board.rowOf(cell) + 0.5) * size,
          ),
    );
    await tester.pump();
  }

  testWidgets(
    'your turn: a wrong digit is refused, the right one is explained',
    (tester) async {
      phoneSize(tester);
      final start = Board.parse(warmUp.text);
      final first = const Solver().nextStep(start)!;
      final target = first.placements.first;

      await tester.pumpWidget(testApp(WalkthroughScreen(start: start)));
      await tester.tap(find.byKey(const Key('mode-play')));
      await tester.pump();

      expect(find.textContaining('your turn'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('next-step')))
            .onPressed,
        isNull,
      );

      await tapCell(tester, target.cell);
      final wrong = target.digit == 1 ? 2 : 1;
      await tester.tap(find.byKey(Key('play-digit-$wrong')));
      await tester.pump();
      expect(find.byKey(const Key('feedback')), findsOneWidget);

      await tester.tap(find.byKey(Key('play-digit-${target.digit}')));
      await tester.pump();
      expect(find.byKey(const Key('feedback')), findsNothing);
      expect(find.text(first.explanation), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('next-step')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('your turn: the score counts first-try moves', (tester) async {
    phoneSize(tester);
    final start = Board.parse(warmUp.text);
    final steps = <Step>[];
    final board = start.copy();
    const solver = Solver();
    for (
      var s = solver.nextStep(board);
      s != null;
      s = solver.nextStep(board)
    ) {
      steps.add(s);
      board.applyStep(s);
    }

    await tester.pumpWidget(testApp(WalkthroughScreen(start: start)));
    await tester.tap(find.byKey(const Key('mode-play')));
    await tester.pump();

    // Get the first move right, then ask to be shown every other one.
    final p = steps.first.placements.first;
    await tapCell(tester, p.cell);
    await tester.tap(find.byKey(Key('play-digit-${p.digit}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('next-step')));
    await tester.pump();
    for (var i = 1; i < steps.length; i++) {
      await tester.tap(find.byKey(const Key('show-me')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('next-step')));
      await tester.pump();
    }
    expect(
      find.text('You found 1 of ${steps.length} moves on your own.'),
      findsOneWidget,
    );
  });

  testWidgets('your turn: removing candidates asks which technique', (
    tester,
  ) async {
    phoneSize(tester);
    final puzzle = puzzleLibrary.firstWhere(
      (p) => p.technique == Technique.pointingPair,
    );
    await tester.pumpWidget(
      testApp(WalkthroughScreen(start: Board.parse(puzzle.text))),
    );
    await tester.tap(find.byKey(const Key('mode-play')));
    await tester.pump();

    final choice = find.byWidgetPredicate(
      (w) => w is ChoiceChip && w.key.toString().contains('choice-'),
    );
    for (var i = 0; i < 100 && choice.evaluate().isEmpty; i++) {
      await tester.tap(find.byKey(const Key('show-me')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('next-step')));
      await tester.pump();
    }
    expect(choice, findsNWidgets(4));

    final right = find.byKey(const Key('choice-pointingPair'));
    final others = choice.evaluate().map((e) => e.widget.key).toList()
      ..remove(right.evaluate().single.widget.key);
    await tester.tap(find.byKey(others.first!));
    await tester.pump();
    expect(find.byKey(const Key('feedback')), findsOneWidget);

    await tester.tap(right);
    await tester.pump();
    expect(find.byKey(const Key('feedback')), findsNothing);
    expect(choice, findsNothing);
  });

  test('choices include the answer and nothing that applies', () {
    final puzzle = puzzleLibrary.firstWhere(
      (p) => p.technique == Technique.pointingPair,
    );
    final board = Board.parse(puzzle.text);
    const solver = Solver();
    for (
      var s = solver.nextStep(board);
      s != null;
      s = solver.nextStep(board)
    ) {
      if (s.placements.isEmpty) {
        final answer = s.technique;
        final options = techniqueChoices(board, answer);
        expect(options, contains(answer));
        expect(options, hasLength(4));
        for (final t in options.where((t) => t != answer)) {
          expect(
            defaultTechniques.firstWhere((x) => x.technique == t).find(board),
            isNull,
          );
        }
        return;
      }
      board.applyStep(s);
    }
    fail('no elimination step found');
  });
}
