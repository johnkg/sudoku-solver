import 'dart:async';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import '../progress/progress_scope.dart';
import '../progress/progress_store.dart';
import '../settings/settings.dart';
import 'achievements.dart';
import 'board_view.dart';
import 'layout.dart';
import 'levels.dart';
import 'navigation.dart';
import 'puzzle_library.dart';
import 'share_result.dart';
import 'solve_controller.dart';
import 'solve/disabled.dart';
import 'solve/number_pad.dart';
import 'solve/paused_board.dart';
import 'solve/stats_row.dart';
import 'solve/status_line.dart';
import 'solve/step_panel.dart';
import 'solve/tool_bar.dart';
import 'unlocking.dart';
import 'walkthrough_screen.dart';

class SolveScreen extends StatefulWidget {
  const SolveScreen({
    super.key,
    required this.puzzle,
    this.recordProgress = true,
    this.onNewPuzzle,
    this.dailyKey,
    this.shareBase,
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

  /// The page address share links are built from. Defaults to the browser's.
  final Uri? shareBase;

  @override
  State<SolveScreen> createState() => _SolveScreenState();
}

/// How long a completed row, column or box flashes.
const _flashDuration = Duration(milliseconds: 700);

class _SolveScreenState extends State<SolveScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final ProgressStore store = ProgressScope.read(context);
  late final Settings settings = SettingsScope.read(context);
  late final SolveController controller = _create();

  /// Changes whenever the game needs saving again.
  String _savedSignature = '';
  bool _recorded = false;

  /// A level this solve just opened, to tell the player.
  int? _newlyUnlockedLevel;

  /// Fades the flash over rows, columns and boxes the player just completed.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: _flashDuration,
  );
  int _seenCompleted = 0;
  int _seenMistakes = 0;
  int _seenMoves = 0;

  Timer? _clock;
  bool _inBackground = false;

  /// Whether the mistake limit has already been dealt with, so the dialog
  /// shows once per run of mistakes.
  late bool _limitHandled = _limitReached;

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
      settings.haptic(HapticFeedback.heavyImpact);
    } else if (controller.completedSerial != _seenCompleted) {
      settings.haptic(HapticFeedback.mediumImpact);
      if (!controller.solved && !MediaQuery.disableAnimationsOf(context)) {
        _flash.forward(from: 0);
      }
    } else if (controller.moveCount > _seenMoves) {
      settings.haptic(HapticFeedback.selectionClick);
    }
    _seenMistakes = controller.mistakes;
    _seenCompleted = controller.completedSerial;
    _seenMoves = controller.moveCount;
  }

  /// Tells the player about achievements this solve earned.
  void _announce(Set<String> before) {
    final fresh = [
      for (final a in achievementsFor(store))
        if (a.unlocked && !before.contains(a.id)) a.title,
    ];
    if (fresh.isEmpty) return;
    // A snack bar cannot be shown while the screen is rebuilding.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Achievement unlocked: ${fresh.join(', ')}')),
        );
    });
  }

  /// Copies a short summary of today's daily result to share.
  Future<void> _shareResult() async {
    final key = widget.dailyKey!;
    final level = widget.puzzle.level;
    final text = dailyShareText(
      date: DateTime.parse(key),
      level: level,
      levelName: levelNames[level] ?? '',
      stars: PuzzleRecord(
        mistakes: controller.mistakes,
        hints: controller.hintsUsed,
      ).stars,
      seconds: controller.seconds.value,
      mistakes: controller.mistakes,
      hints: controller.hintsUsed,
      streak: store.dailyStreak,
      link: appHome(widget.shareBase ?? Uri.base),
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Result copied. Paste it anywhere.')),
      );
  }

  void _onChange() {
    _feedback();
    _checkMistakeLimit();
    if (!widget.recordProgress) return;
    if (controller.solved) {
      if (_recorded) return;
      _recorded = true;
      final before = unlockedAchievementIds(store);
      // Techniques the player needed a hint for count as ones to revisit.
      for (final technique in controller.applied) {
        store.recordTechnique(technique.name, right: false);
      }
      final dailyKey = widget.dailyKey;
      if (dailyKey != null) {
        store.recordDaily(
          dailyKey,
          mistakes: controller.mistakes,
          hints: controller.hintsUsed,
          seconds: controller.seconds.value,
        );
        _announce(before);
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
      _announce(before);
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

  bool get _limitReached =>
      settings.mistakeLimit > 0 && controller.mistakes >= settings.mistakeLimit;

  void _checkMistakeLimit() {
    if (!_limitReached) {
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
          'You have made ${settings.mistakeLimit} mistakes. Start this '
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

  /// Walks through the rest of the puzzle with explanations. It counts as a
  /// hint, and the clock waits while the player reads.
  Future<void> _openGuide() async {
    if (controller.hintsUsed == 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Open the step-by-step guide?'),
          content: const Text(
            'It explains every move from where you are now, so it counts as '
            'a hint.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Show me'),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    controller.useGuide();
    final wasPaused = controller.paused;
    if (!wasPaused) controller.togglePause();
    await pushScreen(
      context,
      (_) => WalkthroughScreen(
        start: controller.board.copy(),
        givens: {
          for (var c = 0; c < Board.cellCount; c++)
            if (controller.board.values[c] != 0) c,
        },
        title: 'Guide: ${widget.puzzle.title}',
      ),
    );
    if (mounted && !wasPaused && controller.paused) controller.togglePause();
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
                tooltip: 'Step-by-step guide',
                icon: const Icon(Icons.school_outlined),
                onPressed: _openGuide,
              ),
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
                final stats = StatsRow(
                  level: widget.puzzle.level,
                  mistakes: controller.mistakes,
                  hints: controller.hintsUsed,
                  seconds: controller.seconds,
                  limit: settings.mistakeLimit,
                  showClock: settings.showClock,
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
                    ? PausedBoard(onResume: controller.togglePause)
                    : liveBoard;
                final status = StatusLine(controller: controller);
                final tools = Disabled(
                  disabled: controller.paused,
                  child: ToolBar(controller: controller),
                );
                final pad = Disabled(
                  disabled: controller.paused,
                  child: NumberPad(controller: controller),
                );
                final panel = StepPanel(
                  controller: controller,
                  focus: widget.puzzle.technique,
                  newlyUnlockedLevel: _newlyUnlockedLevel,
                  onNewPuzzle: widget.onNewPuzzle,
                  dailyStreak: widget.dailyKey == null
                      ? null
                      : store.dailyStreak,
                  onShare: widget.dailyKey == null ? null : _shareResult,
                );

                // Side by side on wide screens and on phones turned sideways, where a
                // full-width board would not fit the height.
                if (useSideBySide(constraints)) {
                  return Padding(
                    padding: const EdgeInsets.all(Space.xl),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: boardFlex, child: board),
                        const SizedBox(width: Space.xl),
                        Expanded(
                          flex: panelFlex,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                stats,
                                const SizedBox(height: Space.sm),
                                status,
                                tools,
                                pad,
                                const SizedBox(height: Space.lg),
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
                        padding: const EdgeInsets.only(bottom: Space.md),
                        children: [
                          stats,
                          board,
                          status,
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.md,
                            ),
                            child: panel,
                          ),
                        ],
                      ),
                    ),
                    tools,
                    pad,
                    const SizedBox(height: Space.sm),
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
