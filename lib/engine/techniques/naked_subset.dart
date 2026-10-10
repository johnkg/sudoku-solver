import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'subsets.dart';
import 'technique.dart';

/// [size] cells in a unit whose candidates, taken together, are only [size]
/// different digits. Those digits must fill those cells, so no other cell in
/// the unit can hold them.
///
/// Size 2 is a naked pair, 3 a triple, 4 a quad.
class NakedSubset extends SolvingTechnique {
  const NakedSubset(this.size) : assert(size >= 2 && size <= 4);

  final int size;

  @override
  Technique get technique => switch (size) {
    2 => Technique.nakedPair,
    3 => Technique.nakedTriple,
    _ => Technique.nakedQuad,
  };

  @override
  Step? find(Board board) {
    for (final unit in Board.units) {
      // A cell with one candidate is a naked single, not part of a subset.
      final open = [
        for (final c in unit.cells)
          if (board.values[c] == 0 &&
              popCount(board.candidates[c]) >= 2 &&
              popCount(board.candidates[c]) <= size)
            c,
      ];
      for (final group in combinations(open, size)) {
        final union = group.fold(0, (m, c) => m | board.candidates[c]);
        if (popCount(union) != size) continue;

        final eliminations = [
          for (final c in unit.cells)
            if (board.values[c] == 0 &&
                !group.contains(c) &&
                board.candidates[c] & union != 0)
              Elimination(c, digitsOf(board.candidates[c] & union)),
        ];
        if (eliminations.isEmpty) continue;

        final digits = digitsOf(union);
        return Step(
          technique: technique,
          eliminations: eliminations,
          highlightCells: group,
          highlightDigits: digits,
          explanation:
              'In ${unit.name}, ${joinCells(group)} can only hold '
              '${joinDigits(digits)} between them. Those ${sizeNames[size]} '
              'digits must fill those $size cells, so no other cell in '
              '${unit.name} can be ${joinDigits(digits)}. Remove them from '
              '${joinCells(eliminations.map((e) => e.cell))}.',
        );
      }
    }
    return null;
  }
}
