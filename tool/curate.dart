// ignore_for_file: avoid_print
// Searches for practice puzzles. Generates random unique puzzles (some with
// extra clues, so easy techniques turn up), rates each one, and keeps a few
// per technique they require. Every solver step is also checked against the
// true solution, and the run fails if any is unsound.
//
//   dart run tool/curate.dart <count> <seed> [keep=3] [clue floors, e.g. 56,62]
//
// Prints one line per kept puzzle as soon as it is found:
// `<technique> <81 digits> <clues> <steps>`.
import 'dart:io';
import 'dart:math';

import 'package:sudoku_solver/engine/engine.dart';

void _checkSound(Board puzzle, Board solution) {
  final working = puzzle.copy();
  const solver = Solver();
  while (!working.isSolved) {
    final step = solver.nextStep(working);
    if (step == null) return;
    for (final p in step.placements) {
      if (solution.values[p.cell] != p.digit) {
        throw StateError('Unsound placement: ${step.explanation}\n$puzzle');
      }
    }
    for (final e in step.eliminations) {
      for (final d in e.digits) {
        if (solution.values[e.cell] == d) {
          throw StateError('Unsound elimination: ${step.explanation}\n$puzzle');
        }
      }
    }
    working.applyStep(step);
  }
}

void main(List<String> args) {
  final count = int.parse(args[0]);
  final random = Random(int.parse(args[1]));
  final keep = args.length > 2 ? int.parse(args[2]) : 3;

  // Mostly minimal puzzles (hard), some with more clues (easy). Pass a fourth
  // argument such as `56,62,68` to search only puzzles with at least that many
  // clues, which is where a Full House can be enough.
  final clueFloors = args.length > 3
      ? args[3].split(',').map(int.parse).toList()
      : const [0, 0, 0, 0, 24, 28, 32, 36, 40];
  final kept = <Technique, List<String>>{};

  for (var i = 0; i < count; i++) {
    final puzzle = generatePuzzle(
      random,
      minClues: clueFloors[random.nextInt(clueFloors.length)],
    );
    final rating = ratePuzzle(puzzle);
    _checkSound(puzzle, solveByBacktracking(puzzle)!);
    final technique = rating.required;
    if (technique == null) continue;

    final list = kept.putIfAbsent(technique, () => []);
    if (list.length < keep) {
      final clues = puzzle.values.where((v) => v != 0).length;
      final line =
          '${technique.name} ${puzzle.toLine().replaceAll('.', '0')} '
          '$clues ${rating.stepCount}';
      list.add(line);
      // Print as soon as found, so a long run can be read before it ends.
      print(line);
      stdout.flush();
    }
  }
}
