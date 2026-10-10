import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'subsets.dart';
import 'technique.dart';

/// Unique Rectangle (types 1 and 2).
///
/// A proper puzzle has exactly one solution. Four cells at the corners of a
/// rectangle that spans exactly two boxes, all holding only the digits A and
/// B, could be filled two ways (swap A and B), so that "deadly pattern" can
/// never be the final state. Wherever a rectangle comes close to it, the extra
/// candidates must be real.
///
/// * Type 1: three corners are exactly {A,B}. The fourth cannot be A or B.
/// * Type 2: two corners are exactly {A,B}; the other two are {A,B,C}. One of
///   those two is C, so cells that see both cannot be C.
class UniqueRectangle extends SolvingTechnique {
  const UniqueRectangle();

  @override
  Technique get technique => Technique.uniqueRectangle;

  @override
  Step? find(Board board) {
    for (var r1 = 0; r1 < 8; r1++) {
      for (var r2 = r1 + 1; r2 < 9; r2++) {
        for (var c1 = 0; c1 < 8; c1++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            final step = _checkRectangle(board, [
              r1 * 9 + c1,
              r1 * 9 + c2,
              r2 * 9 + c1,
              r2 * 9 + c2,
            ]);
            if (step != null) return step;
          }
        }
      }
    }
    return null;
  }

  Step? _checkRectangle(Board board, List<int> cells) {
    if (cells.any((c) => board.values[c] != 0)) return null;
    if (cells.map(Board.boxOf).toSet().length != 2) return null;

    final common = cells.fold(allDigitsMask, (m, c) => m & board.candidates[c]);
    if (popCount(common) < 2) return null;

    for (final pair in combinations(digitsOf(common), 2)) {
      final (a, b) = (pair[0], pair[1]);
      final pairMask = digitBit(a) | digitBit(b);
      final exact = [
        for (final c in cells)
          if (board.candidates[c] == pairMask) c,
      ];
      final others = [
        for (final c in cells)
          if (board.candidates[c] != pairMask) c,
      ];
      final rectangle = joinCells(cells);

      if (exact.length == 3) {
        final cell = others.single;
        return Step(
          technique: technique,
          eliminations: [
            Elimination(cell, [a, b]),
          ],
          highlightCells: cells,
          highlightDigits: [a, b],
          explanation:
              'Unique Rectangle: $rectangle sit in two boxes, and '
              '${joinCells(exact)} hold only $a and $b. If ${Board.cellName(cell)} '
              'were also $a or $b, the four cells could swap $a and $b, giving '
              'two solutions. A proper puzzle has just one, so '
              '${Board.cellName(cell)} cannot be $a or $b. Remove both.',
        );
      }

      if (exact.length == 2) {
        final extra0 = board.candidates[others[0]] & ~pairMask;
        final extra1 = board.candidates[others[1]] & ~pairMask;
        if (extra0 != extra1 || popCount(extra0) != 1) continue;

        final c = digitsOf(extra0).single;
        final eliminations = [
          for (final cell in Board.peers[others[0]])
            if (board.values[cell] == 0 &&
                hasDigit(board.candidates[cell], c) &&
                Board.peers[others[1]].contains(cell))
              Elimination(cell, [c]),
        ];
        if (eliminations.isEmpty) continue;
        return Step(
          technique: technique,
          eliminations: eliminations,
          highlightCells: cells,
          highlightDigits: [a, b, c],
          explanation:
              'Unique Rectangle: $rectangle sit in two boxes, and '
              '${joinCells(exact)} hold only $a and $b. If neither '
              '${joinCells(others)} were $c, all four cells would hold only '
              '$a and $b and could swap them, giving two solutions. So one of '
              '${joinCells(others)} is $c, and any cell that sees both cannot '
              'be $c. Remove $c from '
              '${joinCells(eliminations.map((e) => e.cell))}.',
        );
      }
    }
    return null;
  }
}
