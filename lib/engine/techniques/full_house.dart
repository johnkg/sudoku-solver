import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'technique.dart';

/// A row, column, or box with exactly one empty cell: the missing digit goes
/// there.
class FullHouse extends SolvingTechnique {
  const FullHouse();

  @override
  Technique get technique => Technique.fullHouse;

  @override
  Step? find(Board board) {
    for (final unit in Board.units) {
      final empty = unit.cells.where((c) => board.values[c] == 0).toList();
      if (empty.length != 1) continue;
      var used = 0;
      for (final c in unit.cells) {
        if (board.values[c] != 0) used |= digitBit(board.values[c]);
      }
      final digit = digitsOf(allDigitsMask & ~used).single;
      final cell = empty.single;
      return Step(
        technique: technique,
        placements: [Placement(cell, digit)],
        highlightCells: unit.cells,
        highlightDigits: [digit],
        explanation:
            '${unit.name} has only one empty cell, ${Board.cellName(cell)}. '
            'The only digit it is missing is $digit, so ${Board.cellName(cell)} '
            'must be $digit.',
      );
    }
    return null;
  }
}
