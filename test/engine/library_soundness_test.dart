import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_solver/engine/engine.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';

/// Replays every library puzzle step by step and checks no step contradicts
/// the true solution.
void main() {
  for (final entry in puzzleLibrary) {
    test('every step is sound: ${entry.id}', () {
      final board = Board.parse(entry.text);
      final solution = solveByBacktracking(board)!;
      final working = board.copy();
      const solver = Solver();
      while (!working.isSolved) {
        final step = solver.nextStep(working);
        expect(step, isNotNull, reason: '${entry.id} stalled');
        for (final p in step!.placements) {
          expect(p.digit, solution.values[p.cell], reason: step.explanation);
        }
        for (final e in step.eliminations) {
          expect(
            e.digits.contains(solution.values[e.cell]),
            isFalse,
            reason: step.explanation,
          );
        }
        working.applyStep(step);
      }
    });
  }
}
