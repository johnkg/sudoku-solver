import 'dart:async';
import 'dart:math';

import 'board.dart';
import 'generator.dart';
import 'rater.dart';
import 'solver.dart';
import 'step.dart';
import 'techniques/technique.dart';
import 'techniques/techniques.dart';

/// A puzzle together with how it was rated.
class FoundPuzzle {
  const FoundPuzzle(this.puzzle, this.rating);

  final Board puzzle;
  final PuzzleRating rating;

  /// The puzzle as 81 digits, with 0 for an empty cell.
  String get text => puzzle.toDigits();
}

/// How many puzzles a search tries before giving up.
const defaultMaxAttempts = 3000;

/// Clue floors worth trying for [level]. Puzzles with more clues tend to be
/// easier, so low levels start from fuller grids. A floor of 0 removes every
/// clue it can.
List<int> clueFloorsFor(int level) => switch (level) {
  1 => const [40, 46, 52, 58],
  2 => const [34, 38, 42],
  3 => const [26, 30, 34],
  4 => const [0, 24, 28],
  _ => const [0, 0, 24],
};

/// A random puzzle whose clue floor is picked from [clueFloors].
Board _generateWithRandomFloor(Random random, List<int> clueFloors) =>
    generatePuzzle(
      random,
      minClues: clueFloors[random.nextInt(clueFloors.length)],
    );

/// Calls [tryOnce] up to [maxAttempts] times and returns the first non-null
/// result. Returns null once [isCancelled] says to stop, and [whenExhausted]
/// (null by default) after the last attempt.
///
/// Generating a puzzle takes tens of milliseconds, so [yieldTurn] runs
/// between attempts to let the caller keep the app responsive. By default it
/// waits one event-loop turn.
Future<T?> _searchAttempts<T>({
  required int maxAttempts,
  required T? Function(int attempt) tryOnce,
  T? Function()? whenExhausted,
  bool Function()? isCancelled,
  Future<void> Function()? yieldTurn,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (isCancelled?.call() ?? false) return null;

    final result = tryOnce(attempt);
    if (result != null) return result;

    await (yieldTurn?.call() ?? Future<void>.delayed(Duration.zero));
  }
  return whenExhausted?.call();
}

/// Generates random puzzles until one rates at exactly [level] (1-5) using
/// [techniques], and returns it. Returns null after [maxAttempts] tries or once
/// [isCancelled] says to stop. [yieldTurn] runs between attempts (see
/// [_searchAttempts]).
Future<FoundPuzzle?> findPuzzleOfLevel(
  int level,
  Random random, {
  int maxAttempts = defaultMaxAttempts,
  List<SolvingTechnique> techniques = defaultTechniques,
  bool Function()? isCancelled,
  Future<void> Function()? yieldTurn,
}) {
  final floors = clueFloorsFor(level);
  return _searchAttempts(
    maxAttempts: maxAttempts,
    isCancelled: isCancelled,
    yieldTurn: yieldTurn,
    tryOnce: (_) {
      final puzzle = _generateWithRandomFloor(random, floors);
      final rating = ratePuzzle(puzzle, techniques: techniques);
      return rating.level == level ? FoundPuzzle(puzzle, rating) : null;
    },
  );
}

/// Tries spent looking for a puzzle that needs a technique before one that
/// only uses it will do.
const defaultPreferAttempts = 80;

/// Floors added to a technique's own, since a hard technique can turn up in a
/// fuller grid and an easy one in a sparse grid.
const _extraFloors = [0, 28, 36];

/// Generates random puzzles until one is built around [technique]. A puzzle
/// that cannot be solved without it (see [ratePuzzle]) is best; harder
/// techniques are rarely strictly needed, so after [preferAttempts] tries a
/// puzzle that merely uses it is accepted. Check `rating.required` to tell
/// which one came back. Returns null after [maxAttempts] tries or once
/// [isCancelled] says to stop.
Future<FoundPuzzle?> findPuzzleRequiring(
  Technique technique,
  Random random, {
  int maxAttempts = defaultMaxAttempts,
  int preferAttempts = defaultPreferAttempts,
  bool Function()? isCancelled,
  Future<void> Function()? yieldTurn,
}) {
  final floors = [...clueFloorsFor(technique.level), ..._extraFloors];
  FoundPuzzle? uses;
  return _searchAttempts(
    maxAttempts: maxAttempts,
    isCancelled: isCancelled,
    yieldTurn: yieldTurn,
    whenExhausted: () => uses,
    tryOnce: (attempt) {
      final puzzle = _generateWithRandomFloor(random, floors);
      final rating = ratePuzzle(puzzle);
      if (rating.required == technique) return FoundPuzzle(puzzle, rating);
      if (rating.uses.containsKey(technique)) {
        uses ??= FoundPuzzle(puzzle, rating);
        if (attempt >= preferAttempts) return uses;
      }
      return null;
    },
  );
}

/// A board partway through a solve where [step], a use of its technique, is
/// the solver's next move.
class TechniqueMoment {
  const TechniqueMoment(this.board, this.step);

  final Board board;
  final Step step;
}

/// Clue floors for [findMomentOf]. Harder techniques turn up in sparse
/// puzzles, but easier ones such as pointing pairs are crowded out there by
/// singles, so mix both.
const _momentClueFloors = [0, 0, 24, 30, 36, 42];

/// Generates random puzzles and solves them like a human until the solver
/// reaches a use of [technique], and returns that moment. Returns null after
/// [maxAttempts] puzzles or once [isCancelled] says to stop.
Future<TechniqueMoment?> findMomentOf(
  Technique technique,
  Random random, {
  int maxAttempts = defaultMaxAttempts,
  bool Function()? isCancelled,
  Future<void> Function()? yieldTurn,
}) {
  const solver = Solver();
  return _searchAttempts(
    maxAttempts: maxAttempts,
    isCancelled: isCancelled,
    yieldTurn: yieldTurn,
    tryOnce: (_) {
      final board = _generateWithRandomFloor(random, _momentClueFloors);
      for (
        var step = solver.nextStep(board);
        step != null;
        step = solver.nextStep(board)
      ) {
        if (step.technique == technique) {
          return TechniqueMoment(board.copy(), step);
        }
        board.applyStep(step);
      }
      return null;
    },
  );
}
