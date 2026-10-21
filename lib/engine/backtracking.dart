import 'bits.dart';
import 'board.dart';

/// Brute-force search. Used only to check a puzzle has exactly one solution,
/// never to teach.
///
/// Returns a solved board, or null if there is no solution.
Board? solveByBacktracking(Board board) {
  final solutions = _findSolutions(board, 1);
  return solutions.isEmpty ? null : solutions.first;
}

/// Counts solutions, stopping at [limit]. The default of 2 is enough to tell
/// a unique puzzle from one with several solutions.
int countSolutions(Board board, {int limit = 2}) =>
    _findSolutions(board, limit).length;

List<Board> _findSolutions(Board board, int limit) {
  final solutions = <Board>[];
  _search(board.copy(), limit, solutions);
  return solutions;
}

void _search(Board board, int limit, List<Board> solutions) {
  if (board.hasContradiction) return;

  // Branch on the empty cell with the fewest candidates.
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
  if (best == -1) {
    solutions.add(board);
    return;
  }

  for (final digit in digitsOf(board.candidates[best])) {
    _search(board.copy()..place(best, digit), limit, solutions);
    if (solutions.length >= limit) return;
  }
}
