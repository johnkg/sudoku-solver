import 'package:flutter/material.dart';

import 'progress/progress_store.dart';
import 'ui/app.dart';
import 'ui/puzzle_link.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ProgressStore.load();
  runApp(SudokuApp(store: store, initialPuzzle: puzzleFromUri(Uri.base)));
}
