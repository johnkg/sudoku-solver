import 'package:flutter/material.dart';
import 'package:sudoku_solver/progress/progress_scope.dart';
import 'package:sudoku_solver/progress/progress_store.dart';
import 'package:sudoku_solver/ui/puzzle_library.dart';

/// A [MaterialApp] showing [home] with an in-memory progress store.
Widget testApp(Widget home, {ProgressStore? store}) => ProgressScope(
  store: store ?? ProgressStore.memory(),
  child: MaterialApp(home: home),
);

/// A small puzzle that single-candidate cells solve, with a known layout: the
/// first empty cell is r1c3.
final warmUp = puzzleLibrary.firstWhere((p) => p.title == 'Warm-up');
