import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'technique.dart';

/// A cell with exactly one candidate left must hold that digit.
class NakedSingle extends SolvingTechnique {
  const NakedSingle();

  @override
  Technique get technique => Technique.nakedSingle;

  @override
  Step? find(Board board) {
    for (var cell = 0; cell < Board.cellCount; cell++) {
      if (board.values[cell] != 0 || popCount(board.candidates[cell]) != 1) {
        continue;
      }
      final digit = digitsOf(board.candidates[cell]).single;
      return Step(
        technique: technique,
        placements: [Placement(cell, digit)],
        highlightCells: [cell],
        highlightDigits: [digit],
        explanation:
            '${Board.cellName(cell)} can only be $digit: every other digit '
            'already appears in its row, column, or box.',
      );
    }
    return null;
  }
}
