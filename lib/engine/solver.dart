import 'board.dart';
import 'step.dart';
import 'techniques/technique.dart';
import 'techniques/techniques.dart';

class SolveResult {
  const SolveResult(this.board, this.steps);

  /// The board after every step was applied.
  final Board board;
  final List<Step> steps;

  bool get solved => board.isSolved;

  /// The hardest technique used, or null if no step was needed.
  Technique? get hardest {
    Technique? best;
    for (final step in steps) {
      if (best == null || step.technique.level > best.level) {
        best = step.technique;
      }
    }
    return best;
  }
}

/// Solves like a human: applies the easiest available technique, repeats, and
/// stops when none applies.
class Solver {
  const Solver({this.techniques = defaultTechniques});

  final List<SolvingTechnique> techniques;

  /// The next step on [board], or null if no technique applies.
  Step? nextStep(Board board) {
    for (final technique in techniques) {
      final step = technique.find(board);
      if (step != null) return step;
    }
    return null;
  }

  SolveResult solve(Board start) {
    final board = start.copy();
    final steps = <Step>[];
    while (!board.isSolved && !board.hasContradiction) {
      final step = nextStep(board);
      if (step == null) break;
      board.applyStep(step);
      steps.add(step);
    }
    return SolveResult(board, steps);
  }
}
