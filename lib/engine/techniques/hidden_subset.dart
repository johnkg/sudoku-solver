import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'subsets.dart';
import 'technique.dart';

/// [size] digits in a unit that, taken together, fit in only [size] cells.
/// Those cells must hold those digits, so every other candidate can be
/// removed from them.
///
/// Size 2 is a hidden pair, 3 a triple, 4 a quad.
class HiddenSubset extends SolvingTechnique {
  const HiddenSubset(this.size) : assert(size >= pairSize && size <= quadSize);

  final int size;

  @override
  Technique get technique => switch (size) {
    pairSize => Technique.hiddenPair,
    tripleSize => Technique.hiddenTriple,
    _ => Technique.hiddenQuad,
  };

  @override
  Step? find(Board board) {
    for (final unit in Board.units) {
      // For each digit still missing from the unit, the cells that could
      // take it. A digit with one spot is a hidden single, not part of a
      // subset.
      final spots = <int, List<int>>{};
      for (var digit = 1; digit <= maxDigit; digit++) {
        final cells = [
          for (final c in unit.cells)
            if (board.values[c] == 0 && hasDigit(board.candidates[c], digit)) c,
        ];
        if (cells.length >= pairSize && cells.length <= size) {
          spots[digit] = cells;
        }
      }

      for (final digits in combinations(spots.keys.toList(), size)) {
        final cells = {for (final d in digits) ...spots[d]!}.toList()..sort();
        if (cells.length != size) continue;

        final keep = digits.fold(0, (m, d) => m | digitBit(d));
        final eliminations = [
          for (final c in cells)
            if (board.candidates[c] & ~keep != 0)
              Elimination(c, digitsOf(board.candidates[c] & ~keep)),
        ];
        if (eliminations.isEmpty) continue;

        return Step(
          technique: technique,
          eliminations: eliminations,
          highlightCells: cells,
          highlightDigits: digits,
          explanation:
              'In ${unit.name}, the digits ${joinDigits(digits)} can only go '
              'in ${joinCells(cells)}. Those cells must hold those digits '
              '(a hidden ${sizeNames[size]}), so any other candidate in them '
              'can be removed.',
        );
      }
    }
    return null;
  }
}
