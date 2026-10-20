import 'dart:math';

import 'backtracking.dart';
import 'bits.dart';
import 'board.dart';

/// Shuffles [items] in place. `List.shuffle` may change between Dart versions,
/// and the daily puzzle must not.
void _shuffle<T>(List<T> items, Random random) {
  for (var i = items.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final tmp = items[i];
    items[i] = items[j];
    items[j] = tmp;
  }
}

/// A random completed grid.
Board generateSolution(Random random) {
  Board? fill(Board board) {
    if (board.hasContradiction) return null;
    var best = -1;
    var bestCount = maxDigit + 1; // more than any cell can have
    for (var cell = 0; cell < Board.cellCount; cell++) {
      if (board.values[cell] != 0) continue;
      final n = popCount(board.candidates[cell]);
      if (n < bestCount) {
        best = cell;
        bestCount = n;
      }
    }
    if (best == -1) return board;
    final digits = digitsOf(board.candidates[best]);
    _shuffle(digits, random);
    for (final digit in digits) {
      final solved = fill(board.copy()..place(best, digit));
      if (solved != null) return solved;
    }
    return null;
  }

  return fill(Board.parse('.' * Board.cellCount))!;
}

/// A random puzzle with exactly one solution.
///
/// Starts from a full grid and blanks cells in random order, keeping each
/// blank only if the solution stays unique. Stops early once [minClues] or
/// fewer clues remain, so a higher [minClues] gives an easier puzzle. With the
/// default of 0 it removes every clue it can.
Board generatePuzzle(Random random, {int minClues = 0}) {
  final cells = generateSolution(random).toLine().split('');
  final order = List.generate(Board.cellCount, (i) => i);
  _shuffle(order, random);
  var clues = Board.cellCount;
  for (final cell in order) {
    if (clues <= minClues) break;
    final saved = cells[cell];
    cells[cell] = '.';
    if (countSolutions(Board.parse(cells.join())) == 1) {
      clues--;
    } else {
      cells[cell] = saved;
    }
  }
  return Board.parse(cells.join());
}
