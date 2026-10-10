import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';

void main() {
  lockedCandidatesTests();
  subsetTests();
  level4Tests();
  level5Tests();
  test('Full House fills the last cell of a row', () {
    // Row 1 is 1-8 with r1c9 empty.
    final board = Board.parse('12345678.${'.' * 72}');
    final step = const FullHouse().find(board)!;
    expect(step.technique, Technique.fullHouse);
    expect(step.placements.single.cell, 8);
    expect(step.placements.single.digit, 9);
  });

  test('Naked Single fires when a cell has one candidate', () {
    // r1c1 sees 1-8 across its row, leaving only 9.
    final board = Board.parse('.2345678.${'.' * 72}');
    // r1c1 and r1c9 both see 2-8 in the row, so both have candidates 1 and 9.
    // Pin r1c9 to 1, leaving r1c1 with only 9.
    board.place(8, 1);
    final step = const NakedSingle().find(board)!;
    expect(step.technique, Technique.nakedSingle);
    expect(step.placements.single.cell, 0);
    expect(step.placements.single.digit, 9);
  });

  test('Hidden Single finds the only place for a digit in a unit', () {
    // Box 1 is rows 1-3, columns 1-3. Four 5s elsewhere rule out every cell
    // of the box except r1c3: r2c6 and r3c9 cover rows 2 and 3, r4c1 covers
    // column 1, r7c2 covers column 2.
    final cells = List.filled(81, '.');
    cells[1 * 9 + 5] = '5';
    cells[2 * 9 + 8] = '5';
    cells[3 * 9 + 0] = '5';
    cells[6 * 9 + 1] = '5';
    final board = Board.parse(cells.join());
    final step = const HiddenSingle().find(board)!;
    expect(step.technique, Technique.hiddenSingle);
    expect(step.placements.single.cell, 2);
    expect(step.placements.single.digit, 5);
  });

  test('techniques do not modify the board they inspect', () {
    final board = Board.parse('12345678.${'.' * 72}');
    final before = board.toLine();
    const FullHouse().find(board);
    expect(board.toLine(), before);
  });
}

void lockedCandidatesTests() {
  group('Locked candidates', () {
    test('Pointing Pair removes a digit from the rest of the line', () {
      // Rows 2 and 3 of box 1 are filled with 1-4, 6, 7, so box 1's 5 must be
      // in row 1 (r1c1-r1c3). Row 1's other cells lose the 5 candidate.
      final cells = List.filled(81, '.');
      const filled = {9: '1', 10: '2', 11: '3', 18: '4', 19: '6', 20: '7'};
      filled.forEach((cell, digit) => cells[cell] = digit);
      final board = Board.parse(cells.join());
      final step = const PointingPair().find(board)!;
      expect(step.technique, Technique.pointingPair);
      expect(step.highlightCells, [0, 1, 2]);
      expect(step.highlightDigits, [5]);
      expect({for (final e in step.eliminations) e.cell}, {3, 4, 5, 6, 7, 8});
      expect(step.eliminations.every((e) => e.digits.single == 5), isTrue);
    });

    test('Pointing Pair works along a column', () {
      // Columns 2 and 3 of box 1 are filled, so box 1's 5 must be in column 1.
      final cells = List.filled(81, '.');
      const filled = {1: '1', 10: '2', 19: '3', 2: '4', 11: '6', 20: '7'};
      filled.forEach((cell, digit) => cells[cell] = digit);
      final board = Board.parse(cells.join());
      final step = const PointingPair().find(board)!;
      expect(step.highlightCells, [0, 9, 18]);
      expect(
        {for (final e in step.eliminations) e.cell},
        {27, 36, 45, 54, 63, 72},
      );
    });

    test('Box/Line Reduction removes a digit from the rest of the box', () {
      // Row 1 is filled with 1-4 and 6-7 in columns 4-9, so its 5 must be in
      // box 1. Rows 2 and 3 of box 1 lose the 5 candidate.
      final cells = List.filled(81, '.');
      const row = '...123467';
      for (var c = 0; c < 9; c++) {
        cells[c] = row[c];
      }
      final board = Board.parse(cells.join());
      final step = const BoxLineReduction().find(board)!;
      expect(step.technique, Technique.boxLineReduction);
      expect(step.highlightDigits, [5]);
      expect(
        {for (final e in step.eliminations) e.cell},
        {9, 10, 11, 18, 19, 20},
      );
    });

    test('does nothing when there is no elimination to make', () {
      final board = Board.parse('.' * 81);
      expect(const PointingPair().find(board), isNull);
      expect(const BoxLineReduction().find(board), isNull);
    });
  });
}

/// An empty board where [allowed] limits each listed cell's candidates.
Board _boardWithCandidates(Map<int, List<int>> allowed) {
  final board = Board.parse('.' * 81);
  allowed.forEach((cell, digits) {
    board.candidates[cell] = digits.fold(0, (m, d) => m | digitBit(d));
  });
  return board;
}

void subsetTests() {
  group('Subsets', () {
    test('Naked Pair clears the pair digits from the rest of the unit', () {
      final board = _boardWithCandidates({
        0: [1, 2],
        1: [1, 2],
      });
      final step = const NakedSubset(2).find(board)!;
      expect(step.technique, Technique.nakedPair);
      expect(step.highlightCells, [0, 1]);
      expect(step.highlightDigits, [1, 2]);
      expect(
        {for (final e in step.eliminations) e.cell},
        {2, 3, 4, 5, 6, 7, 8},
      );
      expect(step.eliminations.every((e) => e.digits.length == 2), isTrue);
    });

    test('Naked Triple allows cells with only some of the digits', () {
      final board = _boardWithCandidates({
        0: [1, 2],
        1: [2, 3],
        2: [1, 3],
      });
      final step = const NakedSubset(3).find(board)!;
      expect(step.technique, Technique.nakedTriple);
      expect(step.highlightCells, [0, 1, 2]);
      expect(step.highlightDigits, [1, 2, 3]);
      expect({for (final e in step.eliminations) e.cell}, {3, 4, 5, 6, 7, 8});
    });

    test('Hidden Pair strips other candidates from the pair cells', () {
      // In row 1, only r1c1 and r1c2 can hold a 1 or a 2.
      final board = _boardWithCandidates({
        for (var c = 2; c < 9; c++) c: [3, 4, 5, 6, 7, 8, 9],
      });
      final step = const HiddenSubset(2).find(board)!;
      expect(step.technique, Technique.hiddenPair);
      expect(step.highlightCells, [0, 1]);
      expect(step.highlightDigits, [1, 2]);
      expect({for (final e in step.eliminations) e.cell}, {0, 1});
      for (final e in step.eliminations) {
        expect(e.digits, [3, 4, 5, 6, 7, 8, 9]);
      }
    });

    test('Hidden Triple strips other candidates from the triple cells', () {
      final board = _boardWithCandidates({
        for (var c = 3; c < 9; c++) c: [4, 5, 6, 7, 8, 9],
      });
      final step = const HiddenSubset(3).find(board)!;
      expect(step.technique, Technique.hiddenTriple);
      expect(step.highlightCells, [0, 1, 2]);
      expect(step.highlightDigits, [1, 2, 3]);
      expect({for (final e in step.eliminations) e.cell}, {0, 1, 2});
    });

    test('nothing to find on an empty board', () {
      final board = Board.parse('.' * 81);
      for (final t in const [
        NakedSubset(2),
        NakedSubset(3),
        HiddenSubset(2),
        HiddenSubset(3),
      ]) {
        expect(t.find(board), isNull);
      }
    });
  });
}

void level4Tests() {
  group('Level 4', () {
    test('X-Wing removes the digit from the cover columns', () {
      // Digit 1 only fits in columns 3 and 7 of rows 1 and 5.
      final board = _boardWithCandidates({
        for (final r in [0, 4])
          for (var c = 0; c < 9; c++)
            if (c != 2 && c != 6) r * 9 + c: [2, 3, 4, 5, 6, 7, 8, 9],
      });
      final step = const Fish(2).find(board)!;
      expect(step.technique, Technique.xWing);
      expect(step.highlightDigits, [1]);
      expect(
        {for (final e in step.eliminations) e.cell},
        {
          for (final c in [2, 6])
            for (var r = 0; r < 9; r++)
              if (r != 0 && r != 4) r * 9 + c,
        },
      );
    });

    test('Swordfish uses three lines and three crossing columns', () {
      // Digit 1: row 1 in columns 2,5; row 4 in 5,8; row 7 in 2,8.
      const allowed = {
        0: [2, 5],
        3: [5, 8],
        6: [2, 8],
      };
      final board = _boardWithCandidates({
        for (final entry in allowed.entries)
          for (var c = 0; c < 9; c++)
            if (!entry.value.contains(c + 1))
              entry.key * 9 + c: [2, 3, 4, 5, 6, 7, 8, 9],
      });
      final step = const Fish(3).find(board)!;
      expect(step.technique, Technique.swordfish);
      expect({for (final e in step.eliminations) e.cell % 9}, {1, 4, 7});
      expect(step.eliminations.length, 18);
    });

    test('Skyscraper removes the digit from cells seeing both roofs', () {
      // Digit 1: row 1 only in columns 3 and 6, row 5 only in columns 3 and 4.
      // Shared column 3 is the base; r1c6 and r5c4 are the roofs.
      final board = _boardWithCandidates({
        for (var c = 0; c < 9; c++)
          if (c != 2 && c != 5) c: [2, 3, 4, 5, 6, 7, 8, 9],
        for (var c = 0; c < 9; c++)
          if (c != 2 && c != 3) 36 + c: [2, 3, 4, 5, 6, 7, 8, 9],
      });
      final step = const Skyscraper().find(board)!;
      expect(step.technique, Technique.skyscraper);
      expect(step.highlightCells, [2, 38, 5, 39]);
      expect({for (final e in step.eliminations) e.cell}, {12, 21, 32, 50});
    });

    test('Y-Wing removes C from cells seeing both pincers', () {
      final board = _boardWithCandidates({
        0: [1, 2], // pivot
        1: [1, 3], // pincer: shares a row with the pivot
        9: [2, 3], // pincer: shares a column with the pivot
      });
      final step = const YWing().find(board)!;
      expect(step.technique, Technique.yWing);
      expect(step.highlightCells, [0, 1, 9]);
      expect(step.eliminations, isNotEmpty);
      for (final e in step.eliminations) {
        expect(e.digits, [3]);
        expect(Board.peers[1], contains(e.cell));
        expect(Board.peers[9], contains(e.cell));
      }
      // r2c2 sees r1c2 by column and r2c1 by row.
      expect(step.eliminations.map((e) => e.cell), contains(10));
    });

    test('Naked Quad clears the quad digits from the rest of the unit', () {
      final board = _boardWithCandidates({
        0: [1, 2],
        1: [2, 3],
        2: [3, 4],
        3: [4, 1],
      });
      final step = const NakedSubset(4).find(board)!;
      expect(step.technique, Technique.nakedQuad);
      expect(step.highlightCells, [0, 1, 2, 3]);
      expect({for (final e in step.eliminations) e.cell}, {4, 5, 6, 7, 8});
    });

    test('Hidden Quad strips other candidates from the quad cells', () {
      final board = _boardWithCandidates({
        for (var c = 4; c < 9; c++) c: [5, 6, 7, 8, 9],
      });
      final step = const HiddenSubset(4).find(board)!;
      expect(step.technique, Technique.hiddenQuad);
      expect(step.highlightDigits, [1, 2, 3, 4]);
      expect({for (final e in step.eliminations) e.cell}, {0, 1, 2, 3});
    });

    test('nothing to find on an empty board', () {
      final board = Board.parse('.' * 81);
      for (final t in const [
        Fish(2),
        Fish(3),
        Skyscraper(),
        YWing(),
        NakedSubset(4),
        HiddenSubset(4),
      ]) {
        expect(t.find(board), isNull);
      }
    });
  });
}

/// Candidates 2-9 only, i.e. everything except the digit 1.
const _noOne = [2, 3, 4, 5, 6, 7, 8, 9];

void level5Tests() {
  group('Level 5', () {
    test('XYZ-Wing removes Z from cells seeing pivot and both pincers', () {
      final board = _boardWithCandidates({
        0: [1, 2, 3], // pivot
        1: [1, 3], // pincer in the same row
        9: [2, 3], // pincer in the same column
      });
      final step = const XYZWing().find(board)!;
      expect(step.technique, Technique.xyzWing);
      expect(step.highlightCells, [0, 1, 9]);
      // The only cells seeing all three are the rest of box 1.
      expect(
        {for (final e in step.eliminations) e.cell},
        {2, 10, 11, 18, 19, 20},
      );
      expect(step.eliminations.every((e) => e.digits.single == 3), isTrue);
    });

    test('W-Wing removes B from cells seeing both bivalue cells', () {
      // r1c1 and r5c3 both hold {1,2}. In column 9, 1 fits only in r1c9 and
      // r5c9, a strong link whose ends see one bivalue cell each.
      final board = _boardWithCandidates({
        0: [1, 2],
        38: [1, 2],
        for (var r = 0; r < 9; r++)
          if (r != 0 && r != 4) r * 9 + 8: _noOne,
      });
      final step = const WWing().find(board)!;
      expect(step.technique, Technique.wWing);
      expect(step.highlightCells, [0, 8, 44, 38]);
      expect(
        {for (final e in step.eliminations) e.cell},
        {2, 11, 20, 27, 36, 45},
      );
      expect(step.eliminations.every((e) => e.digits.single == 2), isTrue);
    });

    test('Simple Coloring: colour wrap removes the clashing colour', () {
      // Digit 1 chain: r1c1 - r1c5 (row 1), r1c5 - r3c5 (column 5),
      // r3c5 - r3c4 (row 3). r1c5 and r3c4 share a colour and a box.
      final board = _boardWithCandidates({
        for (var c = 0; c < 9; c++)
          if (c != 0 && c != 4) c: _noOne,
        for (var r = 0; r < 9; r++)
          if (r != 0 && r != 2) r * 9 + 4: _noOne,
        for (var c = 0; c < 9; c++)
          if (c != 3 && c != 4) 18 + c: _noOne,
      });
      final step = const SimpleColoring().find(board)!;
      expect(step.technique, Technique.simpleColoring);
      expect({for (final e in step.eliminations) e.cell}, {4, 21});
    });

    test('Simple Coloring: colour trap removes a cell seeing both colours', () {
      // Chain r1c1 - r1c5 (row 1), r1c5 - r3c5 (column 5). The ends share a
      // colour; box 2 cells see r1c5 and r3c5, so they see both colours.
      final board = _boardWithCandidates({
        for (var c = 0; c < 9; c++)
          if (c != 0 && c != 4) c: _noOne,
        for (var r = 0; r < 9; r++)
          if (r != 0 && r != 2) r * 9 + 4: _noOne,
      });
      final step = const SimpleColoring().find(board)!;
      expect({for (final e in step.eliminations) e.cell}, {12, 14, 21, 23});
    });

    test('Unique Rectangle type 1 clears the fourth corner', () {
      final board = _boardWithCandidates({
        0: [1, 2],
        3: [1, 2],
        9: [1, 2],
        12: [1, 2, 3],
      });
      final step = const UniqueRectangle().find(board)!;
      expect(step.technique, Technique.uniqueRectangle);
      expect(step.eliminations.single.cell, 12);
      expect(step.eliminations.single.digits, [1, 2]);
    });

    test(
      'Unique Rectangle type 2 clears the extra digit from shared cells',
      () {
        final board = _boardWithCandidates({
          0: [1, 2],
          3: [1, 2],
          9: [1, 2, 3],
          12: [1, 2, 3],
        });
        final step = const UniqueRectangle().find(board)!;
        expect(
          {for (final e in step.eliminations) e.cell},
          {10, 11, 13, 14, 15, 16, 17},
        );
        expect(step.eliminations.every((e) => e.digits.single == 3), isTrue);
      },
    );

    test('Jellyfish uses four lines and four crossing columns', () {
      // Digit 1: rows 1,3,5,7 fit only in columns {2,4}, {4,6}, {6,8}, {8,2}.
      const allowed = {
        0: [1, 3],
        2: [3, 5],
        4: [5, 7],
        6: [7, 1],
      };
      final board = _boardWithCandidates({
        for (final entry in allowed.entries)
          for (var c = 0; c < 9; c++)
            if (!entry.value.contains(c)) entry.key * 9 + c: _noOne,
      });
      final step = const Fish(4).find(board)!;
      expect(step.technique, Technique.jellyfish);
      expect({for (final e in step.eliminations) e.cell % 9}, {1, 3, 5, 7});
      expect(step.eliminations.length, 20);
    });

    test('nothing to find on an empty board', () {
      final board = Board.parse('.' * 81);
      for (final t in const [
        XYZWing(),
        WWing(),
        SimpleColoring(),
        UniqueRectangle(),
        Fish(4),
      ]) {
        expect(t.find(board), isNull);
      }
    });
  });
}
