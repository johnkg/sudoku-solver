import 'package:flutter/material.dart';

import 'progress/progress_store.dart';
import 'settings/settings.dart';
import 'ui/app.dart';
import 'ui/puzzle_link.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ProgressStore.load();
  final settings = await Settings.load();
  runApp(
    SudokuApp(
      store: store,
      settings: settings,
      initialPuzzle: puzzleFromUri(Uri.base),
    ),
  );
}
