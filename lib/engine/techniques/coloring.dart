import '../bits.dart';
import '../board.dart';
import '../step.dart';
import 'strong_links.dart';
import 'subsets.dart';
import 'technique.dart';

/// Skyscraper: for one digit, two rows (or columns) each have the digit in
/// exactly two cells, and one end of each pair lines up in the same column
/// (row). The two remaining ends cannot both be false: if the shared line's
/// cell is false in one, the other must be true. So one of those two ends
/// holds the digit, and any cell that sees both can drop it.
class Skyscraper extends SolvingTechnique {
  const Skyscraper();

  @override
  Technique get technique => Technique.skyscraper;

  @override
  Step? find(Board board) {
    for (var digit = 1; digit <= 9; digit++) {
      for (final rowsAreLines in const [true, false]) {
        final step = _findFor(board, digit, rowsAreLines);
        if (step != null) return step;
      }
    }
    return null;
  }

  Step? _findFor(Board board, int digit, bool rowsAreLines) {
    int along(int cell) =>
        rowsAreLines ? Board.columnOf(cell) : Board.rowOf(cell);

    // Lines where the digit has exactly two spots (a strong link).
    final links = <Unit, List<int>>{};
    for (var i = 0; i < 9; i++) {
      final line = Board.units[(rowsAreLines ? 0 : 9) + i];
      final cells = [
        for (final c in line.cells)
          if (board.values[c] == 0 && hasDigit(board.candidates[c], digit)) c,
      ];
      if (cells.length == 2) links[line] = cells;
    }

    final lines = links.keys.toList();
    for (var i = 0; i < lines.length; i++) {
      for (var j = i + 1; j < lines.length; j++) {
        final first = links[lines[i]]!;
        final second = links[lines[j]]!;
        final firstPositions = first.map(along).toSet();
        final shared = firstPositions.intersection(second.map(along).toSet());
        if (shared.length != 1) continue; // none, or an X-Wing

        final base = shared.single;
        final roof1 = first.firstWhere((c) => along(c) != base);
        final roof2 = second.firstWhere((c) => along(c) != base);

        final eliminations = [
          for (final cell in Board.peers[roof1])
            if (board.values[cell] == 0 &&
                hasDigit(board.candidates[cell], digit) &&
                Board.peers[roof2].contains(cell))
              Elimination(cell, [digit]),
        ];
        if (eliminations.isEmpty) continue;

        final kind = rowsAreLines ? 'rows' : 'columns';
        final baseCells = [
          first.firstWhere((c) => along(c) == base),
          second.firstWhere((c) => along(c) == base),
        ];
        return Step(
          technique: technique,
          eliminations: eliminations,
          highlightCells: [...baseCells, roof1, roof2],
          highlightDigits: [digit],
          explanation:
              'Skyscraper on $digit: ${lines[i].name} and ${lines[j].name} '
              'each have $digit in only two cells ($kind), and '
              '${joinCells(baseCells)} line up. If ${Board.cellName(roof1)} is '
              'not $digit, then ${Board.cellName(baseCells[0])} is. Since '
              '${joinCells(baseCells)} share a line, ${Board.cellName(baseCells[1])} '
              'is not $digit, which forces ${Board.cellName(roof2)} to be '
              '$digit. So one of '
              '${Board.cellName(roof1)} and ${Board.cellName(roof2)} is '
              '$digit, and any cell that sees both cannot be. Remove $digit '
              'from ${joinCells(eliminations.map((e) => e.cell))}.',
        );
      }
    }
    return null;
  }
}

/// Simple Coloring: for one digit, join cells by strong links into a chain
/// and colour it in two alternating colours. Exactly one colour is true.
///
/// * Colour wrap: two cells of one colour see each other, so that colour
///   cannot be true. Remove the digit from every cell of that colour.
/// * Colour trap: a cell outside the chain sees both colours, so it cannot
///   hold the digit whichever colour is true.
class SimpleColoring extends SolvingTechnique {
  const SimpleColoring();

  @override
  Technique get technique => Technique.simpleColoring;

  @override
  Step? find(Board board) {
    for (var digit = 1; digit <= 9; digit++) {
      final step = _findFor(board, digit);
      if (step != null) return step;
    }
    return null;
  }

  Step? _findFor(Board board, int digit) {
    final neighbours = <int, List<int>>{};
    for (final (a, b) in strongLinks(board, digit)) {
      (neighbours[a] ??= []).add(b);
      (neighbours[b] ??= []).add(a);
    }

    final colour = <int, int>{};
    for (final start in neighbours.keys) {
      if (colour.containsKey(start)) continue;
      colour[start] = 0;
      final queue = [start];
      final chain = [start];
      for (var i = 0; i < queue.length; i++) {
        for (final next in neighbours[queue[i]]!) {
          if (colour.containsKey(next)) continue;
          colour[next] = 1 - colour[queue[i]]!;
          queue.add(next);
          chain.add(next);
        }
      }

      final byColour = [
        [
          for (final c in chain)
            if (colour[c] == 0) c,
        ],
        [
          for (final c in chain)
            if (colour[c] == 1) c,
        ],
      ];
      final names = ['blue', 'green'];

      for (var k = 0; k < 2; k++) {
        final clash = combinations(
          byColour[k],
          2,
        ).where((p) => Board.peers[p[0]].contains(p[1])).firstOrNull;
        if (clash == null) continue;
        return Step(
          technique: technique,
          eliminations: [
            for (final c in byColour[k]) Elimination(c, [digit]),
          ],
          highlightCells: chain,
          highlightDigits: [digit],
          explanation:
              'Simple Coloring on $digit: the strong links join '
              '${joinCells(chain)} into a chain, coloured '
              '${names[0]} (${joinCells(byColour[0])}) and ${names[1]} '
              '(${joinCells(byColour[1])}). Exactly one colour is $digit. '
              '${Board.cellName(clash[0])} and ${Board.cellName(clash[1])} are '
              'both ${names[k]} and see each other, so ${names[k]} cannot be '
              'true. Remove $digit from every ${names[k]} cell: '
              '${joinCells(byColour[k])}.',
        );
      }

      final eliminations = [
        for (var cell = 0; cell < 81; cell++)
          if (board.values[cell] == 0 &&
              hasDigit(board.candidates[cell], digit) &&
              !colour.containsKey(cell) &&
              byColour[0].any(Board.peers[cell].contains) &&
              byColour[1].any(Board.peers[cell].contains))
            Elimination(cell, [digit]),
      ];
      if (eliminations.isNotEmpty) {
        return Step(
          technique: technique,
          eliminations: eliminations,
          highlightCells: chain,
          highlightDigits: [digit],
          explanation:
              'Simple Coloring on $digit: the strong links join '
              '${joinCells(chain)} into a chain, coloured '
              '${names[0]} (${joinCells(byColour[0])}) and ${names[1]} '
              '(${joinCells(byColour[1])}). Exactly one colour is $digit. '
              'A cell that sees both colours cannot be $digit either way. '
              'Remove $digit from '
              '${joinCells(eliminations.map((e) => e.cell))}.',
        );
      }
    }
    return null;
  }
}
