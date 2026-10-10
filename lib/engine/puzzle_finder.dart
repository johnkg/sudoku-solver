import 'dart:async';
import 'dart:math';

import 'board.dart';
import 'generator.dart';
import 'rater.dart';

/// A puzzle together with how it was rated.
class FoundPuzzle {
  const FoundPuzzle(this.puzzle, this.rating);

  final Board puzzle;
  final PuzzleRating rating;
}

/// Clue floors worth trying for [level]. Puzzles with more clues tend to be
/// easier, so low levels start from fuller grids.
List<int> _clueFloorsFor(int level) => switch (level) {
  1 => const [40, 46, 52, 58],
  2 => const [34, 38, 42],
  3 => const [26, 30, 34],
  4 => const [0, 24, 28],
  _ => const [0, 0, 24],
};

/// Generates random puzzles until one rates at exactly [level] (1-5), and
/// returns it. Returns null after [maxAttempts] tries or once [isCancelled]
/// says to stop.
///
/// Generating a puzzle takes tens of milliseconds, so [yieldTurn] runs between
/// attempts to let the caller keep the app responsive. By default it waits one
/// event-loop turn.
Future<FoundPuzzle?> findPuzzleOfLevel(
  int level,
  Random random, {
  int maxAttempts = 3000,
  bool Function()? isCancelled,
  Future<void> Function()? yieldTurn,
}) async {
  final floors = _clueFloorsFor(level);
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (isCancelled?.call() ?? false) return null;

    final puzzle = generatePuzzle(
      random,
      minClues: floors[random.nextInt(floors.length)],
    );
    final rating = ratePuzzle(puzzle);
    if (rating.level == level) return FoundPuzzle(puzzle, rating);

    await (yieldTurn?.call() ?? Future<void>.delayed(Duration.zero));
  }
  return null;
}
