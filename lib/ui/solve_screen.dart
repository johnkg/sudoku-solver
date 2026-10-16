import 'dart:async';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/foundation.dart' show ValueListenable;
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

class _SolveScreenState extends State<SolveScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final ProgressStore store = ProgressScope.read(context);
  late final SolveController controller = _create();

  /// Changes whenever the game needs saving again.
  String _savedSignature = '';
  bool _recorded = false;

  /// A level this solve just opened, to tell the player.
  int? _newlyUnlockedLevel;

  /// Fades the flash over rows, columns and boxes the player just completed.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _seenCompleted = 0;
  int _seenMistakes = 0;
  int _seenMoves = 0;

  Timer? _clock;
  bool _inBackground = false;

  /// Whether the mistake limit has already been dealt with, so the dialog
  /// shows once per run of mistakes.
  late bool _limitHandled = controller.mistakes >= SolveController.maxMistakes;

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
    _seenCompleted = controller.completedSerial;
    _seenMistakes = controller.mistakes;
    _seenMoves = controller.moveCount;
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_inBackground) controller.tick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inBackground = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _flash.dispose();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_onChange);
    controller.dispose();
    super.dispose();
  }

  String _signature() =>
      '${controller.changeCount}/${controller.mistakes}/${controller.hintsUsed}/'
      '${controller.movesShown}';

  /// Saves the game when it changed, and records the solve when it is done.
  /// Light feedback for what the last action did.
  void _feedback() {
    if (controller.mistakes > _seenMistakes) {
      HapticFeedback.heavyImpact();
    } else if (controller.completedSerial != _seenCompleted) {
      HapticFeedback.mediumImpact();
      if (!controller.solved) _flash.forward(from: 0);
    } else if (controller.moveCount > _seenMoves) {
      HapticFeedback.selectionClick();
    }
    _seenMistakes = controller.mistakes;
    _seenCompleted = controller.completedSerial;
    _seenMoves = controller.moveCount;
  }

  void _onChange() {
    _feedback();
    _checkMistakeLimit();
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
          seconds: controller.seconds.value,
        );
        return;
      }
      final next = widget.puzzle.level + 1;
      final wasOpen = isLevelUnlocked(store, next);
      store.recordSolve(
        widget.puzzle.id,
        mistakes: controller.mistakes,
        hints: controller.hintsUsed,
        seconds: controller.seconds.value,
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
    if (controller.changeCount == 0 &&
        controller.mistakes == 0 &&
        controller.hintsUsed == 0) {
      store.clearGame(widget.puzzle.id);
    } else {
      store.saveGame(widget.puzzle.id, controller.toJson());
    }
  }

  void _checkMistakeLimit() {
    if (controller.mistakes < SolveController.maxMistakes) {
      _limitHandled = false;
    } else if (!_limitHandled && !controller.solved) {
      _limitHandled = true;
      // Showing a dialog during a notification would rebuild mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOver();
      });
    }
  }

  Future<void> _showGameOver() async {
    final startOver = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Out of mistakes'),
        content: Text(
          'You have made ${SolveController.maxMistakes} mistakes. Start this '
          'puzzle over, or keep going with the mistakes counted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (startOver ?? false) controller.restart();
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
          centerTitle: true,
          title: Text(widget.puzzle.title),
          actions: [
            if (!controller.solved)
              IconButton(
                tooltip: controller.paused ? 'Resume' : 'Pause',
                icon: Icon(
                  controller.paused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                onPressed: controller.togglePause,
              ),
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
                final stats = _StatsRow(
                  level: widget.puzzle.level,
                  mistakes: controller.mistakes,
                  hints: controller.hintsUsed,
                  seconds: controller.seconds,
                );
                final liveBoard = AnimatedBuilder(
                  animation: _flash,
                  builder: (context, _) => BoardView(
                    board: controller.board,
                    givens: controller.givens,
                    showCandidates: controller.showCandidates,
                    step: controller.shown,
                    selected: controller.selected,
                    wrong: controller.wrong,
                    marks: controller.marks,
                    flash: _flash.isAnimating ? controller.completed : const {},
                    flashProgress: _flash.value,
                    onCellTap: controller.tapCell,
                  ),
                );
                final board = controller.paused
                    ? _PausedBoard(onResume: controller.togglePause)
                    : liveBoard;
                final status = _StatusLine(controller: controller);
                final tools = _Disabled(
                  disabled: controller.paused,
                  child: _ToolBar(controller: controller),
                );
                final pad = _Disabled(
                  disabled: controller.paused,
                  child: _NumberPad(controller: controller),
                );
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                stats,
                                const SizedBox(height: 8),
                                status,
                                tools,
                                pad,
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
                // Phone layout: the board and the hint panel scroll, the
                // tools and digits stay within thumb reach at the bottom.
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          stats,
                          board,
                          status,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: panel,
                          ),
                        ],
                      ),
                    ),
                    tools,
                    pad,
                    const SizedBox(height: 8),
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

/// Seconds as `m:ss`, or `h:mm:ss` past an hour.
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Stands in for the board while paused, so the puzzle cannot be studied with
/// the clock stopped.
class _PausedBoard extends StatelessWidget {
  const _PausedBoard({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: onResume,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text('Paused', style: theme.textTheme.titleLarge),
              Text('Tap to resume', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Greys out and blocks [child] while [disabled].
class _Disabled extends StatelessWidget {
  const _Disabled({required this.disabled, required this.child});

  final bool disabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: disabled,
    child: Opacity(opacity: disabled ? 0.4 : 1, child: child),
  );
}

/// Level, mistakes, hints and time at a glance above the board.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.level,
    required this.mistakes,
    required this.hints,
    required this.seconds,
  });

  final int level;
  final int mistakes;
  final int hints;
  final ValueListenable<int> seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget stat(String label, String value, {Key? valueKey}) => Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              key: valueKey,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          stat('Level $level', levelNames[level] ?? ''),
          stat(
            'Mistakes',
            '$mistakes/${SolveController.maxMistakes}',
            valueKey: const Key('mistakes-value'),
          ),
          stat('Hints', '$hints', valueKey: const Key('hints-value')),
          ValueListenableBuilder<int>(
            valueListenable: seconds,
            builder: (context, value, _) => stat(
              'Time',
              formatClock(value),
              valueKey: const Key('time-value'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of feedback for the player's last move.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.controller});

  final SolveController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.solved) return const SizedBox.shrink();

    final armed = controller.armed;
    final text =
        controller.message ??
        (armed != null
            ? 'Tap cells to fill in $armed. Tap $armed again to stop.'
            : controller.selected == null
            ? 'Tap a cell, then pick a digit.'
            : controller.board.values[controller.selected!] != 0
            ? 'Tap an empty cell to continue.'
            : controller.mode == EntryMode.place
            ? 'Pick the digit that goes in '
                  '${Board.cellName(controller.selected!)}.'
            : 'Tap digits to add or remove notes in '
                  '${Board.cellName(controller.selected!)}.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: controller.messageIsError
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Undo, pencil marks, candidate removal and hint, as big icon buttons.
class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.controller});

  final SolveController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.solved) return const SizedBox.shrink();
    final notes = controller.mode == EntryMode.notes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _ToolButton(
              tooltip: 'Undo',
              label: 'Undo',
              icon: Icons.undo,
              onPressed: controller.canUndo ? controller.undo : null,
            ),
          ),
          Expanded(
            child: _ToolButton(
              tooltip: 'Erase',
              label: 'Erase',
              icon: Icons.backspace_outlined,
              onPressed: controller.erase,
            ),
          ),
          Expanded(
            child: _ToolButton(
              tooltip: notes ? 'Switch to placing digits' : 'Edit notes',
              label: 'Notes',
              icon: Icons.edit_outlined,
              badge: notes ? 'ON' : 'OFF',
              onPressed: () =>
                  controller.setMode(notes ? EntryMode.place : EntryMode.notes),
            ),
          ),
          Expanded(
            child: _ToolButton(
              tooltip: controller.notesFilled
                  ? 'Hide all notes'
                  : 'Show all notes',
              label: 'Auto',
              icon: Icons.auto_fix_high,
              badge: controller.notesFilled ? 'ON' : 'OFF',
              onPressed: controller.toggleAutoNotes,
            ),
          ),
          Expanded(
            child: _ToolButton(
              tooltip: 'Get a hint',
              label: 'Hint',
              icon: Icons.lightbulb_outline,
              onPressed: controller.findNextStep,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// A small ON / OFF pill on the icon, for tools that stay switched.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final color = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurface.withValues(alpha: 0.38);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 28, color: color),
                  if (badge != null)
                    Positioned(
                      left: 16,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: badge == 'ON'
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badge == 'ON'
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single row of big digits. A digit that is already placed nine times is
/// dimmed.
class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.controller});

  final SolveController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.solved) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final values = controller.board.values;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (var digit = 1; digit <= 9; digit++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final done = values.where((v) => v == digit).length >= 9;
                  return InkWell(
                    key: Key('digit-$digit'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: done
                        ? null
                        : () => controller.armed == null
                              ? controller.enter(digit)
                              : controller.toggleArmed(digit),
                    onLongPress: done
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            controller.toggleArmed(digit);
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        color: controller.armed == digit
                            ? scheme.primaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        '$digit',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: done
                              ? scheme.onSurface.withValues(alpha: 0.2)
                              : scheme.primary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
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
            'Stuck? Tap Hint: first where to look, then the technique, '
            'then the move. Hardest technique here: ${focus.label}.',
            style: theme.textTheme.bodyMedium,
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
          '${formatClock(controller.seconds.value)} · '
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
