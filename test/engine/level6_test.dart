import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/lessons/lessons.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';

int rc(int row, int column) => Board.cellAt(row - 1, column - 1);

/// An empty board where [allowed] limits the candidates of the listed cells.
Board candidates(Map<int, List<int>> allowed) {
  final board = Board.parse('.' * Board.cellCount);
  allowed.forEach((cell, digits) {
    board.candidates[cell] = digits.fold(0, (m, d) => m | digitBit(d));
  });
  return board;
}

void main() {
  group('AIC', () {
    test('follows a chain that changes digit and removes what both ends '
        'rule out', () {
      final example = lessonFor(Technique.aic).example();
      final step = example.step;

      expect(step.technique, Technique.aic);
      // The ends are 1 in r1c1 and 1 in r6c1, so 1 leaves the rest of
      // column 1.
      expect(
        {for (final e in step.eliminations) e.cell},
        {
          for (var row = 1; row <= Board.size; row++)
            if (row != 1 && row != 6) rc(row, 1),
        },
      );
      expect(step.eliminations.every((e) => e.digits.single == 1), isTrue);
      expect(step.highlightDigits, [1, 2]);
      expect(step.explanation, contains('(1)r6c1 = (2)r6c1 - (2)r6c5'));
    });

    test('links alternate strong and weak, and can join two digits', () {
      final links = lessonFor(Technique.aic).example().step.links;

      expect(links, hasLength(5));
      for (var i = 0; i < links.length; i++) {
        expect(links[i].strong, i.isEven);
      }
      expect(links.any((l) => l.from == l.to && l.digit != l.toDigit), isTrue);
    });

    test('ends in one cell leave it only those two digits', () {
      // 1 and 2 run round a loop through r1c1, r1c5, r5c5 and r5c1, each
      // with only two places in its line. Every chain round it ends back in
      // r1c1, so r1c1 is 1 or 2 and its 3 can go.
      final board = candidates({
        for (var column = 1; column <= Board.size; column++)
          if (column != 1 && column != 5)
            rc(1, column): [2, 3, 4, 5, 6, 7, 8, 9],
        rc(5, 5): [1, 2],
        for (var row = 2; row <= Board.size; row++)
          if (row != 5) rc(row, 5): [2, 3, 4, 5, 6, 7, 8, 9],
        for (var row = 2; row <= Board.size; row++)
          if (row != 5) rc(row, 1): [1, 3, 4, 5, 6, 7, 8, 9],
        for (var column = 2; column <= Board.size; column++)
          if (column != 5) rc(5, column): [1, 3, 4, 5, 6, 7, 8, 9],
        rc(1, 1): [1, 2, 3],
      });

      final step = const Aic().find(board)!;

      expect(step.eliminations, hasLength(1), reason: step.explanation);
      expect(step.eliminations.single.cell, rc(1, 1));
      expect(step.eliminations.single.digits, [3]);
    });

    test('finds nothing on a board with no strong links', () {
      expect(const Aic().find(Board.parse('.' * Board.cellCount)), isNull);
    });
  });

  group('Forcing Chain', () {
    test('removes a candidate that leads to a cell with no candidate', () {
      final step = lessonFor(Technique.forcingChain).example().step;

      expect(step.technique, Technique.forcingChain);
      expect(step.eliminations.single.cell, rc(1, 1));
      expect(step.eliminations.single.digits, [1]);
      expect(step.explanation, contains('suppose r1c1 is 1'));
      expect(step.explanation, contains('r5c5 has no candidate left'));
    });

    test('removes a candidate that leaves a digit nowhere to go', () {
      // If r1c1 is 1, row 1 has no place left for 2: only r1c1 could hold it.
      final board = candidates({
        for (var column = 2; column <= Board.size; column++)
          rc(1, column): [1, 3, 4, 5, 6, 7, 8, 9],
      });

      final step = const ForcingChain().find(board)!;

      expect(step.eliminations.single.cell, rc(1, 1));
      expect(step.explanation, contains('2 has nowhere to go in Row 1'));
    });

    test('finds nothing when no supposition breaks the board', () {
      expect(
        const ForcingChain().find(Board.parse('.' * Board.cellCount)),
        isNull,
      );
    });
  });

  group('level 6 practice puzzles', () {
    final level6 = puzzleLibrary.where((p) => p.level == 6).toList();

    test('there are some for both techniques', () {
      expect(
        {for (final p in level6) p.technique},
        {Technique.aic, Technique.forcingChain},
      );
    });

    for (final entry in level6) {
      test('${entry.id} cannot be solved with levels 1 to 5 alone', () {
        final board = Board.parse(entry.text);
        final upToLevel5 = [
          for (final t in defaultTechniques)
            if (t.technique.level < 6) t,
        ];

        expect(Solver(techniques: upToLevel5).solve(board).solved, isFalse);
        expect(const Solver().solve(board).solved, isTrue);
      });
    }
  });

  test('a ChainLink joins one digit unless told otherwise', () {
    expect(const ChainLink(0, 1, 5).toDigit, 5);
    expect(const ChainLink(0, 0, 5, toDigit: 7).toDigit, 7);
  });
}
