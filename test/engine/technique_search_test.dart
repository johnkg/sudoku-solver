import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';

void main() {
  Future<void> noWait() async {}

  group('findMomentOf', () {
    const techniques = [
      Technique.nakedSingle,
      Technique.hiddenSingle,
      Technique.pointingPair,
      Technique.boxLineReduction,
      Technique.nakedPair,
      Technique.hiddenPair,
      Technique.skyscraper,
      Technique.yWing,
      Technique.wWing,
    ];

    for (final technique in techniques) {
      test('finds a sound ${technique.label}', () async {
        final moment = await findMomentOf(
          technique,
          Random(7),
          yieldTurn: noWait,
        );
        expect(moment, isNotNull);
        expect(moment!.step.technique, technique);

        // The move must agree with the puzzle's one solution.
        final solution = solveByBacktracking(moment.board)!;
        for (final p in moment.step.placements) {
          expect(solution.values[p.cell], p.digit);
        }
        for (final e in moment.step.eliminations) {
          expect(e.digits, isNot(contains(solution.values[e.cell])));
        }
      });
    }

    test('gives up when cancelled', () async {
      expect(
        await findMomentOf(
          Technique.nakedPair,
          Random(1),
          isCancelled: () => true,
          yieldTurn: noWait,
        ),
        isNull,
      );
    });
  });

  group('findPuzzleRequiring', () {
    test('returns a puzzle that needs the technique when it can', () async {
      final found = await findPuzzleRequiring(
        Technique.hiddenSingle,
        Random(3),
        yieldTurn: noWait,
      );
      expect(found, isNotNull);
      expect(found!.rating.required, Technique.hiddenSingle);
      expect(countSolutions(found.puzzle), 1);
    });

    test('settles for a puzzle that uses a rarely needed technique', () async {
      final found = await findPuzzleRequiring(
        Technique.xWing,
        Random(3),
        yieldTurn: noWait,
      );
      expect(found, isNotNull);
      expect(found!.rating.uses, contains(Technique.xWing));
      expect(found.rating.unique, isTrue);
    });

    test('gives up when cancelled', () async {
      expect(
        await findPuzzleRequiring(
          Technique.nakedPair,
          Random(1),
          isCancelled: () => true,
          yieldTurn: noWait,
        ),
        isNull,
      );
    });
  });
}
