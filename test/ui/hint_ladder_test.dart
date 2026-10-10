import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/lessons/lessons.dart';
import 'package:sudoku_solver/ui/hint_ladder.dart';
import 'package:sudoku_solver/ui/solve_controller.dart';
import 'package:sudoku_solver/ui/solve_screen.dart';

Step stepFor(Technique technique) => lessonFor(technique).example().step;

void main() {
  group('nudge', () {
    test('a hidden single points at its unit and digit', () {
      final text = nudgeText(stepFor(Technique.hiddenSingle));
      expect(
        text,
        matches(
          RegExp(r'^Look at (Row|Column|Box) \d\. Focus on the digit 5\.$'),
        ),
      );
    });

    test('a naked single points at a unit but never names the answer', () {
      final step = stepFor(Technique.nakedSingle);
      final answer = step.placements.single.digit;
      final text = nudgeText(step);
      expect(text, startsWith('Look at '));
      expect(text, isNot(contains('$answer')));
    });

    test('a full house does not name the digit either', () {
      final step = stepFor(Technique.fullHouse);
      expect(
        nudgeText(step),
        matches(RegExp(r'^Look at (Row|Column|Box) \d\.$')),
      );
    });

    test('a naked pair points at the unit it works in', () {
      final text = nudgeText(stepFor(Technique.nakedPair));
      expect(text, startsWith('Look at Row 1.'));
      expect(text, contains('1 and 2'));
    });

    test('a box/line reduction points at the box', () {
      expect(
        nudgeText(stepFor(Technique.boxLineReduction)),
        startsWith('Look at Box 1.'),
      );
    });

    test('an X-Wing spans several units, so only the digit is named', () {
      final text = nudgeText(stepFor(Technique.xWing));
      expect(text, startsWith('Focus on the digit 1.'));
      expect(text, isNot(matches(RegExp(r'Look at (Row|Column|Box)'))));
    });

    test('a Y-Wing inside one box still points at that box', () {
      expect(
        nudgeText(stepFor(Technique.yWing)),
        'Look at Box 1. The digits 1, 2 and 3 matter here.',
      );
    });

    test('a W-Wing spans several units, so a pattern with its digits', () {
      expect(
        nudgeText(stepFor(Technique.wWing)),
        'Look for a pattern that uses the digits 1 and 2.',
      );
    });

    test('the nudge view tints the unit and shows no changes', () {
      final view = nudgeView(stepFor(Technique.hiddenSingle));
      expect(view.highlightCells, hasLength(9));
      expect(view.placements, isEmpty);
      expect(view.eliminations, isEmpty);
      expect(view.highlightDigits, isEmpty);
    });

    test('every lesson example yields a nudge', () {
      for (final lesson in lessons) {
        expect(nudgeText(lesson.example().step), isNotEmpty);
      }
    });
  });

  group('pattern view', () {
    test('keeps the pattern but hides what changes', () {
      for (final lesson in lessons) {
        final step = lesson.example().step;
        final view = patternView(step);
        expect(view.highlightCells, step.highlightCells);
        expect(view.highlightDigits, step.highlightDigits);
        expect(view.placements, isEmpty);
        expect(view.eliminations, isEmpty);
      }
    });
  });

  group('ladder in the controller', () {
    late SolveController c;
    setUp(() => c = SolveController(warmUp.text));

    test('climbs 1, 2, 3 and then stays at 3', () {
      expect(c.hintLevel, 0);
      c.findNextStep();
      expect(c.hintLevel, 1);
      expect(c.shown!.eliminations, isEmpty);
      expect(c.shown!.placements, isEmpty);
      c.moreHelp();
      expect(c.hintLevel, 2);
      c.moreHelp();
      expect(c.hintLevel, 3);
      expect(c.shown, same(c.pending));
      c.moreHelp();
      expect(c.hintLevel, 3);
      expect(c.movesShown, 1);
      expect(c.hintsUsed, 1);
    });

    test('showMove jumps to the full move once', () {
      c.findNextStep();
      c.showMove();
      c.showMove();
      expect(c.hintLevel, 3);
      expect(c.movesShown, 1);
    });

    test('a hint that stops early does not count as showing the move', () {
      c.findNextStep();
      c.moreHelp();
      c.dismissPending();
      expect(c.hintsUsed, 1);
      expect(c.movesShown, 0);
      expect(c.hintLevel, 0);
      expect(c.pending, isNull);
    });

    test('a player move, undo, or restart drops the hint', () {
      final cell = c.board.values.indexOf(0);
      c.findNextStep();
      c.select(cell);
      c.enter(c.solution.values[cell]);
      expect(c.hintLevel, 0);
      expect(c.pending, isNull);

      c.findNextStep();
      c.undo();
      expect(c.hintLevel, 0);

      c.findNextStep();
      c.restart();
      expect(c.hintLevel, 0);
      expect(c.movesShown, 0);
    });

    test('applying the step finishes the ladder', () {
      c.findNextStep();
      c.showMove();
      c.applyPending();
      expect(c.hintLevel, 0);
      expect(c.applied, hasLength(1));
    });
  });

  testWidgets('hint stages show the right text and buttons', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(SolveScreen(puzzle: warmUp)));
    await tester.tap(find.text('Get a hint'));
    await tester.pumpAndSettle();
    expect(find.text('Hint 1 of 3'), findsOneWidget);
    expect(find.textContaining('Look at'), findsOneWidget);
    expect(find.text('Another hint'), findsOneWidget);

    await tester.tap(find.text('Another hint'));
    await tester.pumpAndSettle();
    expect(find.text('Hint 2 of 3'), findsOneWidget);
    expect(find.text('Another hint'), findsNothing);
    expect(find.text('How it works'), findsOneWidget);

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.text('Get a hint'), findsOneWidget);
  });
}
