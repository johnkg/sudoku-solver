import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';

// Solvable with singles alone.
const easy =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

// Needs pointing pairs on top of singles.
const level2 =
    '4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......';

// Needs a naked pair on top of level 1-2 techniques.
const nakedPairPuzzle =
    '050003100000700004000900008807000200030000060502000010120000070000060001079300600';

// Needs a hidden pair on top of level 1-2 techniques.
const hiddenPairPuzzle =
    '000000000068000704074000800006000970000930080000000062590340000010080005400500000';

// Needs an X-Wing, a Y-Wing, or a Skyscraper to finish.
const xWingPuzzle =
    '000000020007906000600430001000001050010890600040000200074000000090000063002703400';
const yWingPuzzle =
    '050000006200000004000006050080000000310054000600020090007000013830700900005230080';
const skyscraperPuzzle =
    '709004006000200009000100780031000000000000450570080002010540900843001000000000000';

// Needs an XYZ-Wing, Unique Rectangle, W-Wing, or Simple Coloring to finish.
const xyzWingPuzzle =
    '100000308800940007005300000507008000000000000000060023000009040001470600000002800';
const uniqueRectanglePuzzle =
    '024001000000040000900070008100300900600009504000000200007000030800000050090150760';
const wWingPuzzle =
    '400006700000300000097000040060000005079080000500900003002003010810400000000060800';
const simpleColoringPuzzle =
    '904003006000000500000008300028075009070000001500090000006082000200000670090030002';

// Needs techniques beyond level 5 (chains): the solver stalls partway.
const hard =
    '070004001000300090941060050006008000800210000030400000700100000200000800003900200';

void main() {
  group('Board', () {
    test('parses and round-trips', () {
      final board = Board.parse(easy.replaceAll('0', '.'));
      expect(board.toLine(), easy.replaceAll('0', '.'));
    });

    test('rejects wrong length', () {
      expect(() => Board.parse('123'), throwsFormatException);
    });

    test('rejects conflicting givens', () {
      expect(() => Board.parse('11${'.' * 79}'), throwsFormatException);
    });

    test('every cell has 20 peers', () {
      for (final peers in Board.peers) {
        expect(peers.length, 20);
      }
    });

    test('there are 27 units of 9 cells', () {
      expect(Board.units.length, 27);
      for (final unit in Board.units) {
        expect(unit.cells.toSet().length, 9);
      }
    });
  });

  group('Solver', () {
    test('solves an easy puzzle with level 1 techniques only', () {
      final result = const Solver().solve(Board.parse(easy));
      expect(result.solved, isTrue);
      expect(result.hardest!.level, 1);
      expect(result.board.hasContradiction, isFalse);
    });

    test('agrees with backtracking', () {
      final board = Board.parse(easy);
      final byTechnique = const Solver().solve(board).board;
      final byBruteForce = solveByBacktracking(board)!;
      expect(byTechnique.toLine(), byBruteForce.toLine());
    });

    test('uses locked candidates when singles run out', () {
      final result = const Solver().solve(Board.parse(level2));
      expect(result.solved, isTrue);
      expect(result.hardest, Technique.pointingPair);
    });

    test('gets stuck on a hard puzzle instead of guessing', () {
      final result = const Solver().solve(Board.parse(hard));
      expect(result.solved, isFalse);
      expect(result.hardest!.level, 5);
    });

    test('uses a naked pair when locked candidates run out', () {
      final result = const Solver().solve(Board.parse(nakedPairPuzzle));
      expect(result.solved, isTrue);
      expect(result.hardest, Technique.nakedPair);
    });

    test('uses a hidden pair when locked candidates run out', () {
      final result = const Solver().solve(Board.parse(hiddenPairPuzzle));
      expect(result.solved, isTrue);
      expect(result.hardest, Technique.hiddenPair);
    });

    for (final (name, puzzle, technique) in [
      ('X-Wing', xWingPuzzle, Technique.xWing),
      ('Y-Wing', yWingPuzzle, Technique.yWing),
      ('Skyscraper', skyscraperPuzzle, Technique.skyscraper),
    ]) {
      test('uses a $name when lower levels run out', () {
        final result = const Solver().solve(Board.parse(puzzle));
        expect(result.solved, isTrue);
        expect(result.hardest, technique);
      });
    }

    for (final (name, puzzle, technique) in [
      ('XYZ-Wing', xyzWingPuzzle, Technique.xyzWing),
      ('Unique Rectangle', uniqueRectanglePuzzle, Technique.uniqueRectangle),
      ('W-Wing', wWingPuzzle, Technique.wWing),
      ('Simple Coloring', simpleColoringPuzzle, Technique.simpleColoring),
    ]) {
      test('uses $name when lower levels run out', () {
        final result = const Solver().solve(Board.parse(puzzle));
        expect(result.solved, isTrue);
        expect(result.hardest, technique);
      });
    }

    test('every step has an explanation', () {
      final result = const Solver().solve(Board.parse(easy));
      for (final step in result.steps) {
        expect(step.explanation, isNotEmpty);
      }
    });
  });

  group('Backtracking', () {
    test('finds exactly one solution for a proper puzzle', () {
      expect(countSolutions(Board.parse(easy)), 1);
      expect(countSolutions(Board.parse(level2)), 1);
    });

    test('finds many solutions for an empty board', () {
      expect(countSolutions(Board.parse('.' * 81), limit: 5), 5);
    });

    test('returns null when unsolvable', () {
      // Row 1 holds 1-8, and column 9 already has a 9 below, so r1c9 has no
      // legal digit.
      final board = Board.parse('12345678.${'........9' * 1}${'.' * 63}');
      expect(solveByBacktracking(board), isNull);
    });
  });
}
