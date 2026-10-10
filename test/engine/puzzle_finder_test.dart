import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';

void main() {
  for (final level in [1, 2, 3, 4, 5]) {
    test('finds a puzzle rated exactly level $level', () async {
      final found = await findPuzzleOfLevel(level, Random(level));
      expect(found, isNotNull);
      expect(found!.rating.level, level);
      expect(countSolutions(found.puzzle), 1);
      // Rated again from scratch, it agrees.
      expect(ratePuzzle(found.puzzle).required, found.rating.required);
    });
  }

  test('the same seed finds the same puzzle', () async {
    final a = await findPuzzleOfLevel(2, Random(5));
    final b = await findPuzzleOfLevel(2, Random(5));
    expect(a!.puzzle.toLine(), b!.puzzle.toLine());
  });

  test('stops after maxAttempts', () async {
    expect(await findPuzzleOfLevel(5, Random(1), maxAttempts: 0), isNull);
  });

  test('stops when cancelled', () async {
    var calls = 0;
    final found = await findPuzzleOfLevel(
      5,
      Random(1),
      isCancelled: () => ++calls > 2,
    );
    expect(found, isNull);
    expect(calls, 3);
  });

  test('gives the caller a turn between attempts', () async {
    var turns = 0;
    await findPuzzleOfLevel(
      5,
      Random(1),
      maxAttempts: 3,
      yieldTurn: () async => turns++,
    );
    expect(turns, lessThanOrEqualTo(3));
  });
}
