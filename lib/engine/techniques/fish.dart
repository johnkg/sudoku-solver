import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'subsets.dart';
import 'technique.dart';

/// A fish: for one digit, [size] "base" lines (rows, or columns) where the
/// digit can only go in the same [size] "cover" lines at right angles.
/// The digit must then sit at the crossings, so it can be removed from the
/// rest of the cover lines.
///
/// A pair of lines is an X-Wing, a triple a Swordfish, a quad a Jellyfish.
class Fish extends SolvingTechnique {
  const Fish(this.size) : assert(size >= pairSize && size <= quadSize);

  final int size;

  @override
  Technique get technique => switch (size) {
    pairSize => Technique.xWing,
    tripleSize => Technique.swordfish,
    _ => Technique.jellyfish,
  };

  String get _name => technique.label;

  @override
  Step? find(Board board) {
    for (var digit = 1; digit <= maxDigit; digit++) {
      for (final rowsAreBase in const [true, false]) {
        final step = _findFor(board, digit, rowsAreBase);
        if (step != null) return step;
      }
    }
    return null;
  }

  Step? _findFor(Board board, int digit, bool rowsAreBase) {
    int baseIndex(int cell) =>
        rowsAreBase ? Board.rowOf(cell) : Board.columnOf(cell);
    int coverIndex(int cell) =>
        rowsAreBase ? Board.columnOf(cell) : Board.rowOf(cell);
    final baseLabel = rowsAreBase ? 'Rows' : 'Columns';
    final coverLabel = rowsAreBase ? 'Columns' : 'Rows';

    // Base lines where the digit has 2..size spots, with their cover indexes.
    final spots = <int, List<int>>{};
    for (var i = 0; i < Board.size; i++) {
      final line = rowsAreBase ? Board.row(i) : Board.column(i);
      final cells = [
        for (final c in line.cells)
          if (board.values[c] == 0 && hasDigit(board.candidates[c], digit)) c,
      ];
      if (cells.length >= pairSize && cells.length <= size) spots[i] = cells;
    }

    for (final bases in combinations(spots.keys.toList(), size)) {
      final covers = {
        for (final b in bases) ...spots[b]!.map(coverIndex),
      }.toList()..sort();
      if (covers.length != size) continue;

      final eliminations = [
        for (final cover in covers)
          for (final c
              in (rowsAreBase ? Board.column(cover) : Board.row(cover)).cells)
            if (board.values[c] == 0 &&
                hasDigit(board.candidates[c], digit) &&
                !bases.contains(baseIndex(c)))
              Elimination(c, [digit]),
      ];
      if (eliminations.isEmpty) continue;

      String names(String label, Iterable<int> indexes) =>
          '$label ${indexes.map((i) => i + 1).join(', ')}';
      return Step(
        technique: technique,
        eliminations: eliminations,
        highlightCells: [for (final b in bases) ...spots[b]!],
        highlightDigits: [digit],
        links: [
          for (final b in bases)
            if (spots[b]!.length == pairSize)
              ChainLink(spots[b]![0], spots[b]![1], digit, strong: true),
        ],
        explanation:
            '$_name on $digit: in ${names(baseLabel, bases)}, the digit '
            '$digit can only go in ${names(coverLabel, covers)}. Those $size '
            'lines must take $digit at their crossings, so no other cell in '
            '${names(coverLabel, covers)} can be $digit. Remove it from '
            '${joinCells(eliminations.map((e) => e.cell))}.',
      );
    }
    return null;
  }
}
