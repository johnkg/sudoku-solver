import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';

const puzzles = {
  'easy': '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
  'norvig hard': '4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......',
  'norvig hardest': '85...24..72......9..4.........1.7..23.5...9...4...........8..7..17..........36.4.',
  'brute-force killer': '000000000000003085001020000000507000004000100090000000500000073002010000000040009',
  'naked pair': '050003100000700004000900008807000200030000060502000010120000070000060001079300600',
  'hidden pair': '000000000068000704074000800006000970000930080000000062590340000010080005400500000',
  'x-wing': '000000020007906000600430001000001050010890600040000200074000000090000063002703400',
  'y-wing': '050000006200000004000006050080000000310054000600020090007000013830700900005230080',
  'skyscraper': '709004006000200009000100780031000000000000450570080002010540900843001000000000000',
  'stuck at level 4': '000005470000003005000200800031004006060037000000090000200000740057000921010000000',
  'stuck at level 3': '020000900400800000000000037009000000100900300042010500060050040005006780800002010',
  'medium': '..9748...7.........2.1.9.....7...24..64.1.59..98...3.....8.3.2.........6...2759..',
};

/// Replays the solver step by step and checks no step contradicts the true
/// solution: a placement must match it, and an elimination must never remove
/// the true digit of a cell.
void main() {
  puzzles.forEach((name, text) {
    test('every step is sound: $name', () {
      final board = Board.parse(text);
      expect(countSolutions(board), 1, reason: 'puzzle must be unique');
      final solution = solveByBacktracking(board)!;

      final working = board.copy();
      const solver = Solver();
      while (!working.isSolved) {
        final step = solver.nextStep(working);
        if (step == null) break;
        for (final p in step.placements) {
          expect(p.digit, solution.values[p.cell], reason: step.explanation);
        }
        for (final e in step.eliminations) {
          expect(
            e.digits.contains(solution.values[e.cell]),
            isFalse,
            reason: step.explanation,
          );
        }
        working.applyStep(step);
      }
    });
  });
}
