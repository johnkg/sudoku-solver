import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import '../lessons/lessons.dart';
import '../progress/progress_scope.dart';
import '../progress/progress_store.dart';
import 'board_view.dart';
import 'hint_ladder.dart';
import 'learn_tab.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'solve_controller.dart';
import 'stars.dart';
import 'unlocking.dart';

class SolveScreen extends StatefulWidget {
  const SolveScreen({
    super.key,
    required this.puzzle,
    this.recordProgress = true,
    this.onNewPuzzle,
    this.dailyKey,
  });

  final PuzzleEntry puzzle;

  /// Whether to save the game and record the solve. Random puzzles turn this
  /// off.
  final bool recordProgress;

  /// If set, the solved screen offers a button that calls this.
  final VoidCallback? onNewPuzzle;

  /// Set for the daily puzzle: the day it belongs to, such as `2026-10-10`.
  /// The solve counts towards the streak rather than towards unlocking.
  final String? dailyKey;

  @override
  State<SolveScreen> createState() => _SolveScreenState();
}

class _SolveScreenState extends State<SolveScreen> {
  late final ProgressStore store = ProgressScope.read(context);
  late final SolveController controller = _create();

  /// Changes whenever the game needs saving again.
  String _savedSignature = '';
  bool _recorded = false;

  /// A level this solve just opened, to tell the player.
  int? _newlyUnlockedLevel;

  SolveController _create() {
    final text = widget.puzzle.text;
    final saved = widget.recordProgress
        ? store.savedGame(widget.puzzle.id)
        : null;
    if (saved != null) {
      try {
        return SolveController.restore(text, saved);
      } on Object {
        // Notifying during initState would rebuild widgets mid-build.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => store.clearGame(widget.puzzle.id),
        );
      }
    }
    return SolveController(text);
  }

  @override
  void initState() {
    super.initState();
    _savedSignature = _signature();
    controller.addListener(_onChange);
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    controller.dispose();
    super.dispose();
  }

  String _signature() =>
      '${controller.moveCount}/${controller.mistakes}/${controller.hintsUsed}/'
      '${controller.movesShown}';

  /// Saves the game when it changed, and records the solve when it is done.
  void _onChange() {
    if (!widget.recordProgress) return;
    if (controller.solved) {
      if (_recorded) return;
      _recorded = true;
      final dailyKey = widget.dailyKey;
      if (dailyKey != null) {
        store.recordDaily(
          dailyKey,
          mistakes: controller.mistakes,
          hints: controller.hintsUsed,
        );
        return;
      }
      final next = widget.puzzle.level + 1;
      final wasOpen = isLevelUnlocked(store, next);
      store.recordSolve(
        widget.puzzle.id,
        mistakes: controller.mistakes,
        hints: controller.hintsUsed,
      );
      if (!wasOpen &&
          isLevelUnlocked(store, next) &&
          levelNames.containsKey(next)) {
        _newlyUnlockedLevel = next;
      }
      return;
    }
    _recorded = false;
    _newlyUnlockedLevel = null;

    final signature = _signature();
    if (signature == _savedSignature) return;
    _savedSignature = signature;
    if (controller.moveCount == 0 &&
        controller.mistakes == 0 &&
        controller.hintsUsed == 0) {
      store.clearGame(widget.puzzle.id);
    } else {
      store.saveGame(widget.puzzle.id, controller.toJson());
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final label = key.keyLabel;
    if (label.length == 1 && '123456789'.contains(label)) {
      controller.enter(int.parse(label));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      controller.moveSelection(-1, 0);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      controller.moveSelection(1, 0);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      controller.moveSelection(0, -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      controller.moveSelection(0, 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.puzzle.title),
          actions: [
            IconButton(
              tooltip: controller.showCandidates
                  ? 'Hide pencil marks'
                  : 'Show pencil marks',
              icon: Icon(
                controller.showCandidates
                    ? Icons.grid_view
                    : Icons.grid_view_outlined,
              ),
              onPressed: controller.toggleCandidates,
            ),
            IconButton(
              tooltip: 'Undo',
              icon: const Icon(Icons.undo),
              onPressed: controller.canUndo ? controller.undo : null,
            ),
            IconButton(
              tooltip: 'Start over',
              icon: const Icon(Icons.restart_alt),
              onPressed: controller.canUndo || controller.pending != null
                  ? controller.restart
                  : null,
            ),
          ],
        ),
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final board = BoardView(
                  board: controller.board,
                  givens: controller.givens,
                  showCandidates: controller.showCandidates,
                  step: controller.shown,
                  selected: controller.selected,
                  onCellTap: controller.select,
                );
                final entry = _EntryPad(controller: controller);
                final panel = _StepPanel(
                  controller: controller,
                  focus: widget.puzzle.technique,
                  newlyUnlockedLevel: _newlyUnlockedLevel,
                  onNewPuzzle: widget.onNewPuzzle,
                  dailyStreak: widget.dailyKey == null
                      ? null
                      : store.dailyStreak,
                );

                if (constraints.maxWidth >= 840) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: board),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                entry,
                                const SizedBox(height: 16),
                                panel,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    board,
                    const SizedBox(height: 16),
                    entry,
                    const SizedBox(height: 16),
                    panel,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Mode switch, digit buttons, and feedback for the player's own moves.
class _EntryPad extends StatelessWidget {
  const _EntryPad({required this.controller});

  final SolveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.solved) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<EntryMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: EntryMode.place,
                  label: Text('Place digit'),
                ),
                ButtonSegment(
                  value: EntryMode.remove,
                  label: Text('Remove candidate'),
                ),
              ],
              selected: {controller.mode},
              onSelectionChanged: (s) => controller.setMode(s.first),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var digit = 1; digit <= 9; digit++)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => controller.enter(digit),
                      child: Text('$digit', style: theme.textTheme.titleLarge),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              controller.message ??
                  (controller.selected == null
                      ? 'Tap a cell, then pick a digit.'
                      : controller.board.values[controller.selected!] != 0
                      ? 'Tap an empty cell to continue.'
                      : controller.mode == EntryMode.place
                      ? 'Pick the digit that goes in '
                            '${Board.cellName(controller.selected!)}.'
                      : 'Pick a candidate to rule out in '
                            '${Board.cellName(controller.selected!)}.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: controller.messageIsError
                    ? theme.colorScheme.error
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mistakes: ${controller.mistakes} · Hints: ${controller.hintsUsed}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.controller,
    required this.focus,
    required this.newlyUnlockedLevel,
    required this.onNewPuzzle,
    required this.dailyStreak,
  });

  final SolveController controller;

  /// The hardest technique the puzzle needs.
  final Technique focus;

  /// A level this solve just opened, if any.
  final int? newlyUnlockedLevel;

  final VoidCallback? onNewPuzzle;

  /// The daily-puzzle streak, or null when this is not the daily puzzle.
  final int? dailyStreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = controller.pending;

    final Widget content;
    if (controller.solved) {
      content = _Summary(
        controller: controller,
        newlyUnlockedLevel: newlyUnlockedLevel,
        onNewPuzzle: onNewPuzzle,
        dailyStreak: dailyStreak,
      );
    } else if (step != null) {
      content = switch (controller.hintLevel) {
        1 => _hintStage(context, step, controller),
        2 => _hintStage(context, step, controller),
        _ => _fullMove(context, step, controller),
      };
    } else if (controller.stuck) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No technique applies', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'This puzzle needs something beyond the Level 5 techniques the '
            'solver knows (for example chains). Try undoing a step or '
            'starting over.',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      );
    } else {
      final count = controller.moveCount;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? 'Ready when you are'
                : '$count ${count == 1 ? 'move' : 'moves'} so far',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Stuck? Ask for a hint: first where to look, then the technique, '
            'then the move. Hardest technique here: ${focus.label}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: controller.findNextStep,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Get a hint'),
          ),
        ],
      );
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.controller,
    required this.newlyUnlockedLevel,
    required this.onNewPuzzle,
    required this.dailyStreak,
  });

  final SolveController controller;
  final int? newlyUnlockedLevel;
  final VoidCallback? onNewPuzzle;
  final int? dailyStreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <Technique, int>{};
    for (final technique in controller.applied) {
      counts[technique] = (counts[technique] ?? 0) + 1;
    }
    final techniques = counts.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Solved!', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Stars(
          count: PuzzleRecord(
            mistakes: controller.mistakes,
            hints: controller.hintsUsed,
          ).stars,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          '${controller.moveCount} moves · ${controller.mistakes} mistakes · '
          '${controller.hintsUsed} hints (${controller.movesShown} showed the '
          'full move)',
          style: theme.textTheme.bodyMedium,
        ),
        if (newlyUnlockedLevel != null) ...[
          const SizedBox(height: 8),
          Text(
            'Level $newlyUnlockedLevel · ${levelNames[newlyUnlockedLevel]} '
            'unlocked!',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        if (dailyStreak != null && dailyStreak! > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '$dailyStreak ${dailyStreak == 1 ? 'day' : 'days'} in a row',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
        if (onNewPuzzle != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onNewPuzzle,
            icon: const Icon(Icons.shuffle),
            label: const Text('New random puzzle'),
          ),
        ],
        if (techniques.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Solver steps you applied:', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          for (final t in techniques)
            Text(
              '• ${t.label} × ${counts[t]}',
              style: theme.textTheme.bodyLarge,
            ),
        ],
      ],
    );
  }
}

/// Hint stages 1 and 2: where to look, then which technique.
Widget _hintStage(BuildContext context, Step step, SolveController controller) {
  final theme = Theme.of(context);
  final level = controller.hintLevel;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hint $level of 3',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      const SizedBox(height: 8),
      if (level == 1)
        Text(nudgeText(step), style: theme.textTheme.bodyLarge)
      else ...[
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text(step.technique.label)),
            Text(
              'Level ${step.technique.level} · ${levelNames[step.technique.level]}',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          lessonFor(step.technique).tagline,
          style: theme.textTheme.bodyLarge,
        ),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (level == 1)
            FilledButton.tonal(
              onPressed: controller.moreHelp,
              child: const Text('Another hint'),
            ),
          if (level == 1)
            TextButton(
              onPressed: controller.showMove,
              child: const Text('Show the move'),
            )
          else
            FilledButton.tonal(
              onPressed: controller.showMove,
              child: const Text('Show the move'),
            ),
          if (level == 2)
            TextButton(
              onPressed: () => openLesson(context, lessonFor(step.technique)),
              child: const Text('How it works'),
            ),
          TextButton(
            onPressed: controller.dismissPending,
            child: const Text('Hide'),
          ),
        ],
      ),
    ],
  );
}

/// Hint stage 3: the full move, ready to apply.
Widget _fullMove(BuildContext context, Step step, SolveController controller) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text(step.technique.label)),
          Text(
            'Level ${step.technique.level} · ${levelNames[step.technique.level]}',
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(step.explanation, style: theme.textTheme.bodyLarge),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: controller.applyPending,
            icon: const Icon(Icons.check),
            label: const Text('Apply'),
          ),
          TextButton(
            onPressed: controller.dismissPending,
            child: const Text('Hide'),
          ),
          TextButton(
            onPressed: () => openLesson(context, lessonFor(step.technique)),
            child: const Text('How it works'),
          ),
        ],
      ),
    ],
  );
}
