import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';

/// Checks every step of a full solve against the puzzle's one solution, and
/// that the links drawn for each step describe real links on the board.
void checkSolve(Board puzzle, Map<Technique, int> used) {
  final solution = solveByBacktracking(puzzle)!;
  final working = puzzle.copy();
  const solver = Solver();
  while (!working.isSolved) {
    final step = solver.nextStep(working);
    if (step == null) break;
    for (final p in step.placements) {
      expect(p.digit, solution.values[p.cell], reason: step.explanation);
    }
    for (final e in step.eliminations) {
      expect(
        e.digits.contains(solution.values[e.cell]),
        isFalse,
        reason: step.explanation,
      );
    }
    checkLinks(working, step);
    used[step.technique] = (used[step.technique] ?? 0) + 1;
    working.applyStep(step);
  }
}

void checkLinks(Board board, Step step) {
  for (final link in step.links) {
    final reason = '${step.technique.label}: ${step.explanation}';
    expect(
      step.highlightCells,
      containsAll([link.from, link.to]),
      reason: reason,
    );
    expect(board.values[link.from], 0, reason: reason);
    expect(board.values[link.to], 0, reason: reason);
    // Wings link a bivalue pivot by one of its digits; every other link joins
    // two cells that both hold the digit.
    if (step.technique != Technique.yWing &&
        step.technique != Technique.xyzWing &&
        step.technique != Technique.xyChain) {
      expect(
        (board.candidates[link.from] >> (link.digit - 1)) & 1,
        1,
        reason: reason,
      );
      expect(
        (board.candidates[link.to] >> (link.digit - 1)) & 1,
        1,
        reason: reason,
      );
    }
    expect(Board.peers[link.from], contains(link.to), reason: reason);

    if (link.strong) {
      // The only two cells in some shared unit that can hold the digit.
      final shared = Board.units.where(
        (u) => u.cells.contains(link.from) && u.cells.contains(link.to),
      );
      final isStrong = shared.any(
        (u) =>
            u.cells
                .where(
                  (c) =>
                      board.values[c] == 0 &&
                      (board.candidates[c] >> (link.digit - 1)) & 1 == 1,
                )
                .length ==
            2,
      );
      expect(isStrong, isTrue, reason: reason);
    }
  }
}

void main() {
  test('chains were added after the techniques the daily puzzle uses', () {
    expect(legacyTechniques, hasLength(20));
    expect(defaultTechniques, hasLength(22));
    expect(defaultTechniques.sublist(20).map((t) => t.technique), [
      Technique.xChain,
      Technique.xyChain,
    ]);
  });

  group('practice puzzles for chains', () {
    for (final id in ['xChain', 'xChain-2', 'xyChain', 'xyChain-2']) {
      test('$id is unique and needs exactly its technique', () {
        final entry = puzzleLibrary.firstWhere((p) => p.id == id);
        final board = Board.parse(entry.text);
        final rating = ratePuzzle(board);
        expect(rating.unique, isTrue);
        expect(rating.required, entry.technique);
        // Without the chain techniques the solver gets stuck.
        expect(
          const Solver(techniques: legacyTechniques).solve(board).solved,
          isFalse,
        );
      });
    }
  });

  test('every step is sound, and its links are real, on hard puzzles', () {
    final used = <Technique, int>{};
    for (final entry in puzzleLibrary) {
      checkSolve(Board.parse(entry.text), used);
    }
    final random = Random(42);
    for (var i = 0; i < 25; i++) {
      checkSolve(generatePuzzle(random), used);
    }
    expect(used[Technique.xChain], greaterThan(0));
    expect(used[Technique.xyChain], greaterThan(0));
    expect(used[Technique.skyscraper], greaterThan(0));
    expect(used[Technique.yWing], greaterThan(0));
  });

  test('chain steps explain themselves and carry links', () {
    for (final id in ['xChain', 'xyChain']) {
      final entry = puzzleLibrary.firstWhere((p) => p.id == id);
      final board = Board.parse(entry.text);
      const solver = Solver();
      for (
        var s = solver.nextStep(board);
        s != null;
        s = solver.nextStep(board)
      ) {
        if (s.technique == entry.technique) {
          expect(s.links, isNotEmpty);
          expect(s.explanation, contains('one of'));
          expect(s.highlightCells.length, greaterThanOrEqualTo(4));
          break;
        }
        board.applyStep(s);
      }
    }
  });

  test('a full solve with chains stays quick', () {
    final sw = Stopwatch()..start();
    for (final entry in puzzleLibrary.where((p) => p.level == 5)) {
      const Solver().solve(Board.parse(entry.text));
    }
    expect(sw.elapsed.inSeconds, lessThan(20));
  });
}
