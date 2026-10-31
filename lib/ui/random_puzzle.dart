import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'layout.dart';
import 'levels.dart';
import 'navigation.dart';
import 'practice_card.dart';
import 'puzzle_library.dart';
import 'search_dialog.dart';
import 'solve_screen.dart';

/// The search that finds a puzzle of a level. Tests replace it, for example
/// with one that never finishes, to test cancelling.
@visibleForTesting
Future<FoundPuzzle?> Function(
  int level,
  Random random, {
  bool Function()? isCancelled,
})
randomPuzzleFinder = (level, random, {isCancelled}) =>
    findPuzzleOfLevel(level, random, isCancelled: isCancelled);

/// Looks for a random puzzle at [level] while a dialog shows progress, then
/// opens it. With [replace] the current screen is swapped for the new puzzle,
/// which is what "new random puzzle" does.
///
/// Random puzzles are for practice only: they are not saved, and they do not
/// count towards unlocking levels.
Future<void> playRandomPuzzle(
  BuildContext context,
  int level, {
  bool replace = false,
}) async {
  final navigator = Navigator.of(context);
  final found = await runSearchWithDialog(
    context,
    message: 'Looking for a Level $level puzzle…',
    search: (isCancelled) =>
        randomPuzzleFinder(level, Random(), isCancelled: isCancelled),
  );
  if (found == null) return;

  final entry = PuzzleEntry(
    id: 'random',
    title: 'Random · Level $level',
    text: found.text,
    technique: found.rating.required!,
  );
  openScreen(
    navigator,
    (context) => SolveScreen(
      puzzle: entry,
      recordProgress: false,
      onNewPuzzle: () => playRandomPuzzle(context, level, replace: true),
    ),
    replace: replace,
  );
}

/// A card on the Practice tab: pick a level, get a fresh puzzle.
class RandomPuzzleCard extends StatefulWidget {
  const RandomPuzzleCard({super.key, required this.isUnlocked});

  /// Whether a level is open to the player.
  final bool Function(int level) isUnlocked;

  @override
  State<RandomPuzzleCard> createState() => _RandomPuzzleCardState();
}

class _RandomPuzzleCardState extends State<RandomPuzzleCard> {
  int level = 1;

  @override
  Widget build(BuildContext context) {
    return PracticeCard(
      title: 'Random puzzle',
      description:
          'A fresh puzzle at the level you choose. Practice only: it does '
          'not count towards unlocking.',
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final l in levelNames.keys)
              ChoiceChip(
                label: Text('Level $l'),
                tooltip: levelNames[l],
                selected: level == l,
                onSelected: widget.isUnlocked(l)
                    ? (_) => setState(() => level = l)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        FilledButton.icon(
          onPressed: () => playRandomPuzzle(context, level),
          icon: const Icon(Icons.shuffle),
          label: const Text('Play random puzzle'),
        ),
      ],
    );
  }
}
