import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';

void main() {
  group('ratePuzzle', () {
    test('rates a singles-only puzzle as level 1', () {
      final rating = ratePuzzle(
        Board.parse(
          '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
        ),
      );
      expect(rating.unique, isTrue);
      expect(rating.solvable, isTrue);
      expect(rating.level, 1);
      expect(rating.stepCount, greaterThan(0));
    });

    test('names the technique the puzzle cannot be solved without', () {
      final rating = ratePuzzle(
        Board.parse(
          '107000000093084060000000900401007093009005700738400100000038000000000007000279040',
        ),
      );
      expect(rating.required, Technique.xWing);
      expect(rating.level, 4);
    });

    test('the required technique really is required', () {
      const text =
          '107000000093084060000000900401007093009005700738400100000038000000000007000279040';
      final puzzle = Board.parse(text);
      final withX = defaultTechniques
          .takeWhile((t) => t.technique != Technique.xWing)
          .toList();
      expect(Solver(techniques: withX).solve(puzzle).solved, isFalse);
      expect(
        Solver(techniques: [...withX, const Fish(2)]).solve(puzzle).solved,
        isTrue,
      );
    });

    test('a puzzle needing chains has no required technique', () {
      final rating = ratePuzzle(
        Board.parse(
          '070004001000300090941060050006008000800210000030400000700100000200000800003900200',
        ),
      );
      expect(rating.unique, isTrue);
      expect(rating.solvable, isFalse);
      expect(rating.level, 0);
      expect(rating.required, isNull);
    });

    test('a puzzle with several solutions is not rated', () {
      final rating = ratePuzzle(Board.parse('.' * 81));
      expect(rating.unique, isFalse);
      expect(rating.solvable, isFalse);
    });

    test('uses are counted in technique order', () {
      final rating = ratePuzzle(
        Board.parse(
          '4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......',
        ),
      );
      expect(
        rating.uses.keys.toList(),
        [...rating.uses.keys]..sort((a, b) => a.index.compareTo(b.index)),
      );
      expect(rating.uses.containsKey(rating.required), isTrue);
    });
  });

  group('generator', () {
    test('a solution is a full valid grid', () {
      final grid = generateSolution(Random(1));
      expect(grid.isSolved, isTrue);
      for (final unit in Board.units) {
        expect({for (final c in unit.cells) grid.values[c]}.length, 9);
      }
    });

    test('a puzzle has exactly one solution', () {
      for (var seed = 0; seed < 5; seed++) {
        expect(countSolutions(generatePuzzle(Random(seed))), 1);
      }
    });

    test('minClues stops removal early', () {
      final puzzle = generatePuzzle(Random(3), minClues: 40);
      final clues = puzzle.values.where((v) => v != 0).length;
      expect(clues, inInclusiveRange(40, 41));
    });

    test('the same seed gives the same puzzle', () {
      expect(
        generatePuzzle(Random(9)).toLine(),
        generatePuzzle(Random(9)).toLine(),
      );
    });
  });
}
