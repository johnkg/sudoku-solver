import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'layout.dart';
import 'navigation.dart';
import 'practice_card.dart';
import 'puzzle_library.dart';
import 'search_dialog.dart';
import 'solve_screen.dart';

/// Looks for a random puzzle built around [technique], then opens it. With
/// [replace] the current screen is swapped for the new puzzle.
///
/// Like random puzzles, these are practice only: not saved, and they do not
/// count towards unlocking levels.
Future<void> playTechniquePuzzle(
  BuildContext context,
  Technique technique, {
  bool replace = false,
}) async {
  final navigator = Navigator.of(context);
  final found = await runSearchWithDialog<FoundPuzzle>(
    context,
    message: 'Looking for a puzzle that uses ${technique.label}…',
    notFound: 'Could not find one this time. Try again.',
    search: (isCancelled) =>
        findPuzzleRequiring(technique, Random(), isCancelled: isCancelled),
  );
  if (found == null) return;

  final entry = PuzzleEntry(
    id: 'technique',
    title: '${technique.label} puzzle',
    text: found.text,
    technique: found.rating.required ?? technique,
  );
  openScreen(
    navigator,
    (context) => SolveScreen(
      puzzle: entry,
      recordProgress: false,
      onNewPuzzle: () => playTechniquePuzzle(context, technique, replace: true),
    ),
    replace: replace,
  );
}

/// A card on the Practice tab: pick a technique, get a puzzle built around it.
class TechniquePuzzleCard extends StatefulWidget {
  const TechniquePuzzleCard({super.key, required this.isUnlocked});

  /// Whether a level is open to the player.
  final bool Function(int level) isUnlocked;

  @override
  State<TechniquePuzzleCard> createState() => _TechniquePuzzleCardState();
}

class _TechniquePuzzleCardState extends State<TechniquePuzzleCard> {
  Technique? chosen;

  @override
  Widget build(BuildContext context) {
    // Full House only ever finishes a unit, so no puzzle needs it.
    final options = [
      for (final t in Technique.values)
        if (t != Technique.fullHouse && widget.isUnlocked(t.level)) t,
    ];
    final selected = options.contains(chosen) ? chosen : options.first;

    return PracticeCard(
      title: 'Practise a technique',
      description:
          'A fresh puzzle built around the technique you pick. Harder ones '
          'can take a little while to find.',
      children: [
        DropdownButton<Technique>(
          key: const Key('technique-picker'),
          isExpanded: true,
          value: selected,
          items: [
            for (final t in options)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) => setState(() => chosen = t),
        ),
        const SizedBox(height: Space.md),
        FilledButton.icon(
          key: const Key('technique-puzzle'),
          onPressed: () => playTechniquePuzzle(context, selected!),
          icon: const Icon(Icons.psychology_outlined),
          label: const Text('Play a puzzle with it'),
        ),
      ],
    );
  }
}
