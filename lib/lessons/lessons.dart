import '../engine/engine.dart';

/// One technique lesson: the idea, how to spot it, and a worked example.
///
/// The example board is built by hand, but the move shown on it is found by
/// the real engine, so the lesson can never disagree with the solver.
class Lesson {
  const Lesson({
    required this.technique,
    required this.tagline,
    required this.idea,
    required this.spot,
    required this.buildExample,
  });

  final Technique technique;

  /// One line for the lesson list.
  final String tagline;

  /// What the technique is and why it is valid.
  final String idea;

  /// How to notice a chance to use it.
  final String spot;

  final Board Function() buildExample;

  int get level => technique.level;

  SolvingTechnique get solver =>
      defaultTechniques.firstWhere((t) => t.technique == technique);

  /// The worked example board and the move the engine finds on it.
  ({Board board, Step step}) example() {
    final board = buildExample();
    final step = solver.find(board);
    if (step == null) {
      throw StateError('Lesson example for ${technique.label} found nothing');
    }
    return (board: board, step: step);
  }
}

/// An empty board where [allowed] limits the candidates of the listed cells.
Board _candidates(Map<int, List<int>> allowed) {
  final board = Board.parse('.' * 81);
  allowed.forEach((cell, digits) {
    board.candidates[cell] = digits.fold(0, (m, d) => m | digitBit(d));
  });
  return board;
}

Board _givens(Map<int, int> cells) {
  final chars = List.filled(81, '.');
  cells.forEach((cell, digit) => chars[cell] = '$digit');
  return Board.parse(chars.join());
}

const _noOne = [2, 3, 4, 5, 6, 7, 8, 9];

/// All lessons, easiest first.
final List<Lesson> lessons = [
  Lesson(
    technique: Technique.fullHouse,
    tagline: 'The last empty cell in a row, column or box',
    idea:
        'Every row, column and box holds each digit from 1 to 9 exactly once. '
        'When a unit has only one empty cell left, the one digit it is '
        'missing must go there.',
    spot:
        'Scan the rows, columns and boxes for ones that are almost full. '
        'Count the filled cells: eight means a full house.',
    buildExample: () => _givens({for (var c = 0; c < 8; c++) c: c + 1}),
  ),
  Lesson(
    technique: Technique.nakedSingle,
    tagline: 'A cell that can only be one digit',
    idea:
        'A cell cannot hold a digit that already appears in its row, column '
        'or box. If every digit but one is ruled out, the cell must be that '
        'last digit.',
    spot:
        'Pick an empty cell and list the digits its row, column and box '
        'already use. With pencil marks, look for a cell showing just one '
        'candidate.',
    buildExample: () => _givens({
      4: 5, 13: 6, 22: 7, 31: 8, // column 5
      36: 1, 37: 2, 38: 3, 39: 4, // row 5
    }),
  ),
  Lesson(
    technique: Technique.hiddenSingle,
    tagline: 'A digit with only one place left in a unit',
    idea:
        'A cell may have many candidates, but what matters is where a digit '
        'can go. If a digit fits in only one cell of a row, column or box, '
        'it must go in that cell, because the unit needs that digit somewhere.',
    spot:
        'Pick a digit and a unit, then look at where the digit is still '
        'allowed. Digits already placed in crossing rows and columns often '
        'leave just one cell.',
    buildExample: () => _givens({14: 5, 26: 5, 27: 5, 55: 5}),
  ),
  Lesson(
    technique: Technique.pointingPair,
    tagline: 'A digit in a box is stuck on one line',
    idea:
        'Inside a box, a digit may be possible only in cells that lie on one '
        'row or column. Then the box will put that digit on that line, so no '
        'other cell on the line, outside the box, can hold it.',
    spot:
        'Look at a box and one digit. If its two or three candidate cells '
        'line up, remove that digit from the rest of that row or column.',
    buildExample: () => _givens({9: 1, 10: 2, 11: 3, 18: 4, 19: 6, 20: 7}),
  ),
  Lesson(
    technique: Technique.boxLineReduction,
    tagline: 'A digit in a line is stuck in one box',
    idea:
        'This is the reverse of a pointing pair. If every place a digit can '
        'go in a row or column lies inside one box, then that line gets its '
        'digit from that box, so the box cannot use the digit in its other '
        'rows or columns.',
    spot:
        'Look at a row or column and one digit. If all its candidates fall '
        'within one box, clear the digit from the rest of that box.',
    buildExample: () => _givens({
      3: 1, 4: 2, 5: 3, 6: 4, 7: 6, 8: 7, // the rest of row 1
    }),
  ),
  Lesson(
    technique: Technique.nakedPair,
    tagline: 'Two cells that share the same two digits',
    idea:
        'If two cells in a unit have exactly the same two candidates, those '
        'two digits must fill those two cells in some order. So no other '
        'cell in the unit can hold either digit.',
    spot:
        'Look for two cells in one row, column or box showing identical '
        'two-digit pencil marks.',
    buildExample: () => _candidates({
      0: [1, 2],
      1: [1, 2],
    }),
  ),
  Lesson(
    technique: Technique.hiddenPair,
    tagline: 'Two digits that fit in only two cells',
    idea:
        'If two digits can only go in the same two cells of a unit, those '
        'cells must hold those two digits. Every other candidate in those '
        'two cells can be removed.',
    spot:
        'Look for two digits that appear in exactly two cells of a row, '
        'column or box, and in the same two cells.',
    buildExample: () => _candidates({
      for (var c = 2; c < 9; c++) c: [3, 4, 5, 6, 7, 8, 9],
    }),
  ),
  Lesson(
    technique: Technique.nakedTriple,
    tagline: 'Three cells sharing three digits',
    idea:
        'If three cells in a unit between them hold only three different '
        'candidates, those digits must fill those cells. Each cell need not '
        'show all three. Remove the three digits from the rest of the unit.',
    spot:
        'Look for three cells whose pencil marks, put together, make just '
        'three digits, such as 12, 23 and 13.',
    buildExample: () => _candidates({
      0: [1, 2],
      1: [2, 3],
      2: [1, 3],
    }),
  ),
  Lesson(
    technique: Technique.hiddenTriple,
    tagline: 'Three digits that fit in only three cells',
    idea:
        'If three digits can only go in the same three cells of a unit, '
        'those cells must hold those digits. Remove every other candidate '
        'from the three cells.',
    spot:
        'Look for three digits that, in a row, column or box, are confined '
        'to the same three cells.',
    buildExample: () => _candidates({
      for (var c = 3; c < 9; c++) c: [4, 5, 6, 7, 8, 9],
    }),
  ),
  Lesson(
    technique: Technique.xWing,
    tagline: 'A rectangle of one digit across two lines',
    idea:
        'Suppose a digit can go in only two cells of each of two rows, and '
        'those cells share the same two columns. The digit must sit in '
        'opposite corners of that rectangle, so those two columns cannot '
        'have it anywhere else. It works the same with rows and columns '
        'swapped.',
    spot:
        'Pick a digit and look for two rows where it has exactly two '
        'candidates, lined up in the same columns.',
    buildExample: () => _candidates({
      for (final r in [0, 4])
        for (var c = 0; c < 9; c++)
          if (c != 2 && c != 6) r * 9 + c: _noOne,
    }),
  ),
  Lesson(
    technique: Technique.skyscraper,
    tagline: 'Two towers joined at the base',
    idea:
        'Take a digit with exactly two candidates in each of two rows, where '
        'one candidate from each row shares a column (the base). The two '
        'cells at the other ends cannot both be wrong, because ruling one '
        'out forces the base cell, and then the other end. So one of the two '
        'ends holds the digit, and any cell that sees both ends cannot.',
    spot:
        'Find two rows (or columns) where a digit appears twice each, with '
        'one pair of cells in the same column and the other two cells in '
        'different columns.',
    buildExample: () => _candidates({
      for (var c = 0; c < 9; c++)
        if (c != 2 && c != 5) c: _noOne,
      for (var c = 0; c < 9; c++)
        if (c != 2 && c != 3) 36 + c: _noOne,
    }),
  ),
  Lesson(
    technique: Technique.yWing,
    tagline: 'A pivot with two wings',
    idea:
        'Take a cell with candidates A and B (the pivot). It sees one cell '
        'holding A and C and another holding B and C. If the pivot is A, the '
        'first wing becomes C. If the pivot is B, the second does. Either '
        'way one wing is C, so any cell that sees both wings cannot be C.',
    spot:
        'Look for three two-candidate cells forming a chain AB, AC, BC, '
        'where the AB cell sees both of the others.',
    buildExample: () => _candidates({
      0: [1, 2],
      1: [1, 3],
      9: [2, 3],
    }),
  ),
  Lesson(
    technique: Technique.swordfish,
    tagline: 'An X-Wing stretched to three lines',
    idea:
        'If a digit appears in two or three cells of each of three rows, '
        'and all those cells fall in the same three columns, the digit '
        'must take one cell in each of those rows and each of those '
        'columns. Remove it from the rest of the three columns.',
    spot:
        'Pick a digit and find three rows whose candidates for it sit in a '
        'total of only three columns.',
    buildExample: () {
      const allowed = {
        0: [2, 5],
        3: [5, 8],
        6: [2, 8],
      };
      return _candidates({
        for (final entry in allowed.entries)
          for (var c = 0; c < 9; c++)
            if (!entry.value.contains(c + 1)) entry.key * 9 + c: _noOne,
      });
    },
  ),
  Lesson(
    technique: Technique.nakedQuad,
    tagline: 'Four cells sharing four digits',
    idea:
        'If four cells in a unit between them hold only four different '
        'candidates, those digits must fill those cells. Remove them from '
        'the rest of the unit.',
    spot:
        'Look for four cells whose pencil marks together use only four '
        'digits. It is rare and easier to find with a pencil mark list.',
    buildExample: () => _candidates({
      0: [1, 2],
      1: [2, 3],
      2: [3, 4],
      3: [4, 1],
    }),
  ),
  Lesson(
    technique: Technique.hiddenQuad,
    tagline: 'Four digits that fit in only four cells',
    idea:
        'If four digits can only go in the same four cells of a unit, those '
        'cells must hold those digits. Remove every other candidate from '
        'the four cells.',
    spot:
        'Look for four digits confined to the same four cells of a row, '
        'column or box.',
    buildExample: () => _candidates({
      for (var c = 4; c < 9; c++) c: [5, 6, 7, 8, 9],
    }),
  ),
  Lesson(
    technique: Technique.xyzWing,
    tagline: 'A Y-Wing whose pivot holds the shared digit too',
    idea:
        'The pivot has candidates X, Y and Z. One wing holds X and Z, the '
        'other Y and Z. If the pivot is X, the first wing is Z. If it is Y, '
        'the second wing is Z. If it is Z, the pivot itself is. So one of '
        'the three cells is Z, and any cell that sees all three cannot be Z.',
    spot:
        'Find a three-candidate cell that sees two two-candidate cells '
        'whose digits are two of its three, sharing one digit.',
    buildExample: () => _candidates({
      0: [1, 2, 3],
      1: [1, 3],
      9: [2, 3],
    }),
  ),
  Lesson(
    technique: Technique.uniqueRectangle,
    tagline: 'Avoid the pattern that has two solutions',
    idea:
        'A valid puzzle has exactly one solution. Four cells at the corners '
        'of a rectangle that spans two boxes, all holding only digits A and '
        'B, could swap those digits and give a second solution. So when '
        'three corners hold only A and B, the fourth cannot be A or B.',
    spot:
        'Look for four cells in two rows and two columns, across exactly two '
        'boxes, where three show the same two candidates. Only use this '
        'when the puzzle is known to have one solution.',
    buildExample: () => _candidates({
      0: [1, 2],
      3: [1, 2],
      9: [1, 2],
      12: [1, 2, 3],
    }),
  ),
  Lesson(
    technique: Technique.wWing,
    tagline: 'Two matching cells joined by a link',
    idea:
        'Two cells that do not see each other both hold only A and B. '
        'Elsewhere, A has just two places in a unit (a strong link), and '
        'each end of that link sees one of the two cells. If both cells '
        'were A, both link ends would lose A, which breaks the link. So one '
        'of the two cells is B, and any cell that sees both cannot be B.',
    spot:
        'Find two cells with the same two candidates, then look for a unit '
        'where one of those digits has exactly two places, each pointing at '
        'one of the cells.',
    buildExample: () => _candidates({
      0: [1, 2],
      38: [1, 2],
      for (var r = 0; r < 9; r++)
        if (r != 0 && r != 4) r * 9 + 8: _noOne,
    }),
  ),
  Lesson(
    technique: Technique.simpleColoring,
    tagline: 'Follow a chain of either-or links in two colours',
    idea:
        'When a digit has exactly two places in a unit, one of them is '
        'true. Chain such links together and colour the cells in two '
        'alternating colours: exactly one colour holds the digit. A cell '
        'that sees both colours cannot be the digit, and a colour whose '
        'cells see each other is false.',
    spot:
        'Pick a digit and mark every pair that are its only two places in a '
        'unit. Join pairs that share a cell, then colour them alternately.',
    buildExample: () => _candidates({
      for (var c = 0; c < 9; c++)
        if (c != 0 && c != 4) c: _noOne,
      for (var r = 0; r < 9; r++)
        if (r != 0 && r != 2) r * 9 + 4: _noOne,
    }),
  ),
  Lesson(
    technique: Technique.jellyfish,
    tagline: 'An X-Wing stretched to four lines',
    idea:
        'If a digit appears in two to four cells of each of four rows, and '
        'all those cells fall in the same four columns, the digit takes one '
        'cell in each row and each column. Remove it from the rest of the '
        'four columns.',
    spot:
        'Pick a digit and find four rows whose candidates for it sit in a '
        'total of only four columns. It is rare.',
    buildExample: () {
      const allowed = {
        0: [1, 3],
        2: [3, 5],
        4: [5, 7],
        6: [7, 1],
      };
      return _candidates({
        for (final entry in allowed.entries)
          for (var c = 0; c < 9; c++)
            if (!entry.value.contains(c)) entry.key * 9 + c: _noOne,
      });
    },
  ),
];

Lesson lessonFor(Technique technique) =>
    lessons.firstWhere((l) => l.technique == technique);
