import 'backtracking.dart';
import 'board.dart';
import 'solver.dart';
import 'step.dart';
import 'techniques/technique.dart';
import 'techniques/techniques.dart';

/// How hard a puzzle is to solve with the engine's techniques.
class PuzzleRating {
  const PuzzleRating({
    required this.unique,
    required this.required,
    required this.uses,
  });

  /// Whether the puzzle has exactly one solution. Other fields are only
  /// meaningful when this is true.
  final bool unique;

  /// The hardest technique the puzzle cannot be solved without, in the
  /// solver's easiest-first order. Null if the puzzle is not unique or needs
  /// something the engine does not know.
  final Technique? required;

  /// How many times each technique was used in a full solve, in the order
  /// techniques appear in [Technique].
  final Map<Technique, int> uses;

  /// 1 (beginner) to 6 (master), or 0 when the engine cannot solve it.
  int get level => required?.level ?? 0;

  int get stepCount => uses.values.fold(0, (a, b) => a + b);
}

/// Rates [puzzle] by finding the shortest easiest-first prefix of
/// [techniques] that solves it. The last technique in that prefix is what the
/// puzzle needs: without it the solver stalls.
PuzzleRating ratePuzzle(
  Board puzzle, {
  List<SolvingTechnique> techniques = defaultTechniques,
}) {
  if (countSolutions(puzzle) != 1) {
    return const PuzzleRating(unique: false, required: null, uses: {});
  }

  final full = Solver(techniques: techniques).solve(puzzle);
  if (!full.solved) {
    return const PuzzleRating(unique: true, required: null, uses: {});
  }
  final uses = <Technique, int>{};
  for (final step in full.steps) {
    uses[step.technique] = (uses[step.technique] ?? 0) + 1;
  }

  bool solvesWith(int count) =>
      Solver(techniques: techniques.sublist(0, count)).solve(puzzle).solved;

  // Solving power only grows with a longer prefix, so binary search. The
  // full solve never reached past the hardest technique it used, so the
  // answer is no later than that one.
  var low = 1;
  var high = 1;
  for (var i = 0; i < techniques.length; i++) {
    if (uses.containsKey(techniques[i].technique)) high = i + 1;
  }
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (solvesWith(mid)) {
      high = mid;
    } else {
      low = mid + 1;
    }
  }

  final ordered = {
    for (final t in Technique.values)
      if (uses.containsKey(t)) t: uses[t]!,
  };
  return PuzzleRating(
    unique: true,
    required: techniques[low - 1].technique,
    uses: ordered,
  );
}
