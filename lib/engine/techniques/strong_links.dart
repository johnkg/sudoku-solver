import '../bits.dart';
import '../board.dart';
import 'subsets.dart';

/// Every strong link for [digit]: a pair of cells that are the only two places
/// the digit can go in some row, column, or box. Exactly one of the two holds
/// the digit. A pair sharing two units is listed once.
List<(int, int)> strongLinks(Board board, int digit) {
  final seen = <int>{};
  final links = <(int, int)>[];
  for (final unit in Board.units) {
    final spots = [
      for (final c in unit.cells)
        if (board.values[c] == 0 && hasDigit(board.candidates[c], digit)) c,
    ];
    if (spots.length == pairSize &&
        seen.add(spots[0] * Board.cellCount + spots[1])) {
      links.add((spots[0], spots[1]));
    }
  }
  return links;
}
