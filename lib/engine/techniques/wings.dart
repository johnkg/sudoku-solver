import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'strong_links.dart';
import 'subsets.dart';
import 'technique.dart';

/// Y-Wing (XY-Wing): a pivot cell with candidates A,B sees two pincer cells
/// with candidates A,C and B,C. Whichever way the pivot goes, one pincer
/// becomes C, so any cell that sees both pincers cannot be C.
class YWing extends SolvingTechnique {
  const YWing();

  @override
  Technique get technique => Technique.yWing;

  @override
  Step? find(Board board) {
    bool isBivalue(int cell) =>
        board.values[cell] == 0 && popCount(board.candidates[cell]) == 2;

    for (var pivot = 0; pivot < 81; pivot++) {
      if (!isBivalue(pivot)) continue;
      final pivotMask = board.candidates[pivot];
      final bivalue = Board.peers[pivot].where(isBivalue).toList();

      for (final first in bivalue) {
        final shared = board.candidates[first] & pivotMask;
        if (popCount(shared) != 1) continue;
        // first = {a, c}; the second pincer must be {b, c}.
        final c = digitsOf(board.candidates[first] & ~pivotMask).single;
        final b = digitsOf(pivotMask & ~shared).single;
        final secondMask = digitBit(b) | digitBit(c);

        for (final second in bivalue) {
          if (second <= first || board.candidates[second] != secondMask) {
            continue;
          }
          final eliminations = [
            for (final cell in Board.peers[first])
              if (board.values[cell] == 0 &&
                  hasDigit(board.candidates[cell], c) &&
                  Board.peers[second].contains(cell))
                Elimination(cell, [c]),
          ];
          if (eliminations.isEmpty) continue;

          final a = digitsOf(shared).single;
          return Step(
            technique: technique,
            eliminations: eliminations,
            highlightCells: [pivot, first, second],
            highlightDigits: [a, b, c],
            links: [ChainLink(pivot, first, a), ChainLink(pivot, second, b)],
            explanation:
                'Y-Wing: pivot ${Board.cellName(pivot)} holds $a or $b. '
                'If it is $a, then ${Board.cellName(first)} becomes $c. '
                'If it is $b, then ${Board.cellName(second)} becomes $c. '
                'Either way one of ${Board.cellName(first)} and '
                '${Board.cellName(second)} is $c, so any cell that sees both '
                'cannot be $c. Remove $c from '
                '${joinCells(eliminations.map((e) => e.cell))}.',
          );
        }
      }
    }
    return null;
  }
}

/// XYZ-Wing: a pivot with candidates X,Y,Z sees one pincer with X,Z and
/// another with Y,Z. Whatever the pivot is, one of the three cells is Z, so
/// any cell that sees all three cannot be Z.
class XYZWing extends SolvingTechnique {
  const XYZWing();

  @override
  Technique get technique => Technique.xyzWing;

  @override
  Step? find(Board board) {
    for (var pivot = 0; pivot < 81; pivot++) {
      if (board.values[pivot] != 0 || popCount(board.candidates[pivot]) != 3) {
        continue;
      }
      final mask = board.candidates[pivot];
      final pincers = [
        for (final c in Board.peers[pivot])
          if (board.values[c] == 0 &&
              popCount(board.candidates[c]) == 2 &&
              board.candidates[c] & ~mask == 0)
            c,
      ];

      for (final pair in combinations(pincers, 2)) {
        final a = board.candidates[pair[0]];
        final b = board.candidates[pair[1]];
        if (a == b || (a | b) != mask) continue;

        final z = digitsOf(a & b).single;
        final eliminations = [
          for (final cell in Board.peers[pivot])
            if (board.values[cell] == 0 &&
                hasDigit(board.candidates[cell], z) &&
                Board.peers[pair[0]].contains(cell) &&
                Board.peers[pair[1]].contains(cell))
              Elimination(cell, [z]),
        ];
        if (eliminations.isEmpty) continue;

        final x = digitsOf(a & ~digitBit(z)).single;
        final y = digitsOf(b & ~digitBit(z)).single;
        return Step(
          technique: technique,
          eliminations: eliminations,
          highlightCells: [pivot, ...pair],
          highlightDigits: [x, y, z],
          links: [ChainLink(pivot, pair[0], x), ChainLink(pivot, pair[1], y)],
          explanation:
              'XYZ-Wing: pivot ${Board.cellName(pivot)} holds $x, $y or $z. '
              '${Board.cellName(pair[0])} holds $x or $z, and '
              '${Board.cellName(pair[1])} holds $y or $z. If the pivot is $x, '
              '${Board.cellName(pair[0])} must be $z. If the pivot is $y, '
              '${Board.cellName(pair[1])} must be $z. If the pivot is $z, it '
              'is $z itself. Either way one of the three cells is $z, so any '
              'cell that sees all three cannot be $z. Remove $z from '
              '${joinCells(eliminations.map((e) => e.cell))}.',
        );
      }
    }
    return null;
  }
}

/// W-Wing: two cells with the same two candidates A,B that do not see each
/// other, joined by a strong link on A whose ends each see one of the two
/// cells. If both cells were A, both link ends would be non-A, which breaks
/// the link. So one of the cells is B, and any cell that sees both cannot be B.
class WWing extends SolvingTechnique {
  const WWing();

  @override
  Technique get technique => Technique.wWing;

  @override
  Step? find(Board board) {
    final bivalue = [
      for (var c = 0; c < 81; c++)
        if (board.values[c] == 0 && popCount(board.candidates[c]) == 2) c,
    ];
    final linksByDigit = <int, List<(int, int)>>{};

    for (final pair in combinations(bivalue, 2)) {
      final (x, y) = (pair[0], pair[1]);
      if (board.candidates[x] != board.candidates[y]) continue;
      if (Board.peers[x].contains(y)) continue; // that would be a naked pair

      final digits = digitsOf(board.candidates[x]);
      for (final (a, b) in [(digits[0], digits[1]), (digits[1], digits[0])]) {
        final links = linksByDigit[a] ??= strongLinks(board, a);
        for (final (p, q) in links) {
          if ({p, q}.contains(x) || {p, q}.contains(y)) continue;
          for (final (end1, end2) in [(p, q), (q, p)]) {
            if (!Board.peers[x].contains(end1) ||
                !Board.peers[y].contains(end2)) {
              continue;
            }
            final eliminations = [
              for (final cell in Board.peers[x])
                if (board.values[cell] == 0 &&
                    hasDigit(board.candidates[cell], b) &&
                    Board.peers[y].contains(cell))
                  Elimination(cell, [b]),
            ];
            if (eliminations.isEmpty) continue;

            return Step(
              technique: technique,
              eliminations: eliminations,
              highlightCells: [x, end1, end2, y],
              highlightDigits: [a, b],
              links: [
                ChainLink(x, end1, a),
                ChainLink(end1, end2, a, strong: true),
                ChainLink(end2, y, a),
              ],
              explanation:
                  'W-Wing: ${Board.cellName(x)} and ${Board.cellName(y)} both '
                  'hold only $a or $b. In the unit joining '
                  '${Board.cellName(end1)} and ${Board.cellName(end2)}, $a '
                  'must go in one of those two cells. ${Board.cellName(end1)} '
                  'sees ${Board.cellName(x)} and ${Board.cellName(end2)} sees '
                  '${Board.cellName(y)}, so if both cells were $a, neither end '
                  'could be $a. One of the two cells must be $b, and any cell '
                  'that sees both cannot be $b. Remove $b from '
                  '${joinCells(eliminations.map((e) => e.cell))}.',
            );
          }
        }
      }
    }
    return null;
  }
}
