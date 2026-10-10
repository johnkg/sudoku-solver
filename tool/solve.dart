// Prints a step-by-step walkthrough of a puzzle.
//
//   dart run tool/solve.dart <81-char puzzle>
//   dart run tool/solve.dart path/to/puzzle.txt
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:sudoku_solver/engine/engine.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/solve.dart <puzzle or file>');
    exit(64);
  }
  final input = File(args.first).existsSync()
      ? File(args.first).readAsStringSync()
      : args.first;

  final Board board;
  try {
    board = Board.parse(input);
  } on FormatException catch (e) {
    stderr.writeln('Bad puzzle: ${e.message}');
    exit(65);
  }

  print(board);
  final result = const Solver().solve(board);
  for (var i = 0; i < result.steps.length; i++) {
    final step = result.steps[i];
    print('${i + 1}. [${step.technique.label}] ${step.explanation}');
  }
  print('');
  print(result.board);
  if (result.solved) {
    print(
      'Solved in ${result.steps.length} steps. '
      'Hardest technique: ${result.hardest?.label ?? 'none'}.',
    );
  } else {
    print(
      'Stuck after ${result.steps.length} steps: '
      'no implemented technique applies.',
    );
  }
}
