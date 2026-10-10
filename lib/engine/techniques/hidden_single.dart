import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'technique.dart';

/// A digit that fits in only one cell of a unit must go in that cell, even if
/// the cell still has other candidates.
class HiddenSingle extends SolvingTechnique {
  const HiddenSingle();

  @override
  Technique get technique => Technique.hiddenSingle;

  @override
  Step? find(Board board) {
    for (final unit in Board.units) {
      for (var digit = 1; digit <= 9; digit++) {
        final spots = unit.cells
            .where(
              (c) =>
                  board.values[c] == 0 && hasDigit(board.candidates[c], digit),
            )
            .toList();
        if (spots.length != 1) continue;
        // Skip digits already placed in this unit (no spots would be left).
        final cell = spots.single;
        return Step(
          technique: technique,
          placements: [Placement(cell, digit)],
          highlightCells: unit.cells,
          highlightDigits: [digit],
          explanation:
              'In ${unit.name}, the digit $digit has only one place left: '
              '${Board.cellName(cell)}. So ${Board.cellName(cell)} is $digit.',
        );
      }
    }
    return null;
  }
}
