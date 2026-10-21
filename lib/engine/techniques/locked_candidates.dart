import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'subsets.dart';
import 'technique.dart';

/// Cells in [cells] that are empty and still allow [digit].
List<int> _spots(Board board, Iterable<int> cells, int digit) => [
  for (final c in cells)
    if (board.values[c] == 0 && hasDigit(board.candidates[c], digit)) c,
];

List<Elimination> _eliminationsFor(
  Board board,
  Iterable<int> cells,
  Set<int> keep,
  int digit,
) => [
  for (final c in _spots(board, cells, digit))
    if (!keep.contains(c)) Elimination(c, [digit]),
];

String _cellList(List<int> cells) => cells.map(Board.cellName).join(', ');

/// Inside a box, a digit's only candidates all lie on one row or column.
/// That line must take the digit from the box, so the digit can be removed
/// from the rest of the line (the cells outside the box).
class PointingPair extends SolvingTechnique {
  const PointingPair();

  @override
  Technique get technique => Technique.pointingPair;

  @override
  Step? find(Board board) {
    for (final box in Board.units.where((u) => u.kind == UnitKind.box)) {
      for (var digit = 1; digit <= maxDigit; digit++) {
        final spots = _spots(board, box.cells, digit);
        if (spots.length < pairSize) continue;

        final lines = [
          if (spots.map(Board.rowOf).toSet().length == 1)
            Board.units[Board.rowOf(spots.first)],
          if (spots.map(Board.columnOf).toSet().length == 1)
            Board.column(Board.columnOf(spots.first)),
        ];
        for (final line in lines) {
          final eliminations = _eliminationsFor(
            board,
            line.cells,
            spots.toSet(),
            digit,
          );
          if (eliminations.isEmpty) continue;
          return Step(
            technique: technique,
            eliminations: eliminations,
            highlightCells: spots,
            highlightDigits: [digit],
            explanation:
                'In ${box.name}, the digit $digit can only go in '
                '${_cellList(spots)}, all in ${line.name}. So $digit must be '
                'in one of those cells, and no other cell in ${line.name} '
                'can be $digit. Remove $digit from '
                '${_cellList([for (final e in eliminations) e.cell])}.',
          );
        }
      }
    }
    return null;
  }
}

/// In a row or column, a digit's only candidates all lie inside one box.
/// The line must take the digit there, so it can be removed from the rest of
/// the box (the cells off the line).
class BoxLineReduction extends SolvingTechnique {
  const BoxLineReduction();

  @override
  Technique get technique => Technique.boxLineReduction;

  @override
  Step? find(Board board) {
    for (final line in Board.units.where((u) => u.kind != UnitKind.box)) {
      for (var digit = 1; digit <= maxDigit; digit++) {
        final spots = _spots(board, line.cells, digit);
        if (spots.length < pairSize) continue;
        if (spots.map(Board.boxOf).toSet().length != 1) continue;

        final box = Board.box(Board.boxOf(spots.first));
        final eliminations = _eliminationsFor(
          board,
          box.cells,
          spots.toSet(),
          digit,
        );
        if (eliminations.isEmpty) continue;
        return Step(
          technique: technique,
          eliminations: eliminations,
          highlightCells: spots,
          highlightDigits: [digit],
          explanation:
              'In ${line.name}, the digit $digit can only go in '
              '${_cellList(spots)}, all inside ${box.name}. So $digit must be '
              'in one of those cells, and no other cell in ${box.name} can '
              'be $digit. Remove $digit from '
              '${_cellList([for (final e in eliminations) e.cell])}.',
        );
      }
    }
    return null;
  }
}
