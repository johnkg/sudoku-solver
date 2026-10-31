import 'dart:async';

import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';
import '../progress/progress_scope.dart';
import '../progress/progress_store.dart';
import '../settings/settings.dart';
import 'board_view.dart';
import 'confirm_dialog.dart';
import 'navigation.dart';
import 'puzzle_library.dart';
import 'solve/board_keys.dart';
import 'solve/disabled.dart';
import 'solve/move_feedback.dart';
import 'solve/number_pad.dart';
import 'solve/paused_board.dart';
import 'solve/share_daily_result.dart';
import 'solve/solve_app_bar.dart';
import 'solve/solve_layout.dart';
import 'solve/solve_recorder.dart';
import 'solve/stats_row.dart';
import 'solve/status_line.dart';
import 'solve/step_panel.dart';
import 'solve/tool_bar.dart';
import 'solve_controller.dart';
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

/// How often the clock ticks.
const _clockTick = Duration(seconds: 1);

class _SolveScreenState extends State<SolveScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final ProgressStore store = ProgressScope.read(context);
  late final Settings settings = SettingsScope.read(context);
  late final SolveController controller = _create();
  late final MoveFeedback feedback;

  /// Saves the game and records the result. Null when this puzzle is not
  /// tracked.
  late final SolveRecorder? recorder;

  /// Fades the flash over rows, columns and boxes the player just completed.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: _flashDuration,
  );

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
    // Both start from the game as it was loaded.
    feedback = MoveFeedback(controller: controller, settings: settings);
    recorder = widget.recordProgress
        ? SolveRecorder(
            store: store,
            controller: controller,
            puzzle: widget.puzzle,
            dailyKey: widget.dailyKey,
          )
        : null;
    controller.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(_clockTick, (_) {
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

  void _onChange() {
    if (feedback.react() && !MediaQuery.disableAnimationsOf(context)) {
      _flash.forward(from: 0);
    }
    _checkMistakeLimit();
    final achievements = recorder?.update() ?? const [];
    if (achievements.isNotEmpty) _announce(achievements);
  }

  /// Tells the player about achievements this solve earned.
  void _announce(List<String> titles) {
    // A snack bar cannot be shown while the screen is rebuilding.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Achievement unlocked: ${titles.join(', ')}')),
        );
    });
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
    final startOver = await confirm(
      context,
      title: 'Out of mistakes',
      message:
          'You have made ${settings.mistakeLimit} mistakes. Start this '
          'puzzle over, or keep going with the mistakes counted.',
      cancelLabel: 'Keep playing',
      confirmLabel: 'Start over',
    );
    if (startOver) controller.restart();
  }

  /// Walks through the rest of the puzzle with explanations. It counts as a
  /// hint, and the clock waits while the player reads.
  Future<void> _openGuide() async {
    if (controller.hintsUsed == 0) {
      final go = await confirm(
        context,
        title: 'Open the step-by-step guide?',
        message:
            'It explains every move from where you are now, so it counts as '
            'a hint.',
        cancelLabel: 'Not yet',
        confirmLabel: 'Show me',
      );
      if (!go || !mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: SolveAppBar(
          title: widget.puzzle.title,
          controller: controller,
          onOpenGuide: _openGuide,
        ),
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) => handleSolveKey(controller, event),
          child: SafeArea(
            child: SolveLayout(
              stats: StatsRow(
                level: widget.puzzle.level,
                mistakes: controller.mistakes,
                hints: controller.hintsUsed,
                seconds: controller.seconds,
                limit: settings.mistakeLimit,
                showClock: settings.showClock,
              ),
              board: controller.paused
                  ? PausedBoard(onResume: controller.togglePause)
                  : _buildLiveBoard(),
              status: StatusLine(controller: controller),
              tools: Disabled(
                disabled: controller.paused,
                child: ToolBar(controller: controller),
              ),
              pad: Disabled(
                disabled: controller.paused,
                child: NumberPad(controller: controller),
              ),
              panel: _buildStepPanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBoard() {
    return AnimatedBuilder(
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
  }

  Widget _buildStepPanel() {
    final dailyKey = widget.dailyKey;
    return StepPanel(
      controller: controller,
      focus: widget.puzzle.technique,
      newlyUnlockedLevel: recorder?.newlyUnlockedLevel,
      onNewPuzzle: widget.onNewPuzzle,
      dailyStreak: dailyKey == null ? null : store.dailyStreak,
      onShare: dailyKey == null
          ? null
          : () => copyDailyResult(
              context,
              dailyKey: dailyKey,
              puzzle: widget.puzzle,
              controller: controller,
              store: store,
              shareBase: widget.shareBase ?? Uri.base,
            ),
    );
  }
}
