import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';
import '../progress/progress_scope.dart';
import 'board_legend.dart';
import 'board_view.dart';
import 'board_with_panel.dart';
import 'layout.dart';
import 'walkthrough/controls.dart';
import 'walkthrough/end_panel.dart';
import 'walkthrough/question.dart';
import 'walkthrough/step_panel.dart';

/// Steps through the way the solver would crack [start], one move at a time,
/// explaining each and linking the technique to its lesson.
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({
    super.key,
    required this.start,
    this.givens,
    this.title = 'How to solve it',
  });

  final Board start;

  /// Cells drawn as givens. Defaults to every filled cell of [start].
  final Set<int>? givens;

  final String title;

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  /// `boards[i]` is the board before `steps[i]`; the last one is the end.
  final boards = <Board>[];
  final steps = <Step>[];
  late final Set<int> givens;
  Board? solution;
  int index = 0;
  bool allNotes = false;

  /// In "your turn" mode the player finds each move before it is explained.
  bool play = false;
  final revealedSteps = <int>{};
  final askedSteps = <int>{};
  final firstTry = <int>{};

  // The player's attempt at the step being asked.
  int? selected;
  String? message;
  final wrongChoices = <Technique>{};
  bool missed = false;

  /// The answer to the whole puzzle, used to tell a correct digit that logic
  /// cannot prove yet from a wrong one.
  late final Board? answer = solveByBacktracking(boards.first);

  @override
  void initState() {
    super.initState();
    _solveStepByStep();
  }

  void _solveStepByStep() {
    const solver = Solver();
    var board = widget.start.copy();
    givens =
        widget.givens ??
        {
          for (var i = 0; i < Board.cellCount; i++)
            if (board.values[i] != 0) i,
        };
    boards.add(board);
    while (!board.isSolved && !board.hasContradiction) {
      final step = solver.nextStep(board);
      if (step == null) break;
      steps.add(step);
      board = board.copy()..applyStep(step);
      boards.add(board);
    }
  }

  bool get atEnd => index == steps.length;
  bool get solved => boards.last.isSolved;

  /// Whether step [index] is waiting for the player to find the move.
  bool get asking => play && !atEnd && !revealedSteps.contains(index);

  /// Forgets the player's attempt at the current step.
  void _clearAttempt() {
    selected = null;
    message = null;
    wrongChoices.clear();
    missed = false;
  }

  void _go(int to) => setState(() {
    index = to.clamp(0, steps.length);
    _clearAttempt();
  });

  void _setPlay(bool on) => setState(() {
    play = on;
    _clearAttempt();
    if (on) {
      revealedSteps
        ..clear()
        ..addAll([for (var i = 0; i < index; i++) i]);
      askedSteps.clear();
      firstTry.clear();
    }
  });

  /// Ends the question for the current step, noting whether the player found
  /// the move on their own.
  void _revealStep({required bool found}) {
    ProgressScope.read(context)
        .recordTechnique(steps[index].technique.name, right: found && !missed);
    askedSteps.add(index);
    if (found && !missed) firstTry.add(index);
    revealedSteps.add(index);
    _clearAttempt();
  }

  void _miss(String text) {
    missed = true;
    message = text;
  }

  void _showMe() => setState(() => _revealStep(found: false));

  void _enter(int digit) {
    final cell = selected;
    if (cell == null) return;
    final step = steps[index];
    setState(() {
      if (step.placements.any((p) => p.cell == cell && p.digit == digit)) {
        _revealStep(found: true);
      } else if (step.placements.any((p) => p.cell == cell)) {
        _miss('That cell is the right one to look at, but not that digit.');
      } else if (boards[index].values[cell] != 0) {
        _miss('That cell is already filled. Pick an empty one.');
      } else if (answer?.values[cell] == digit) {
        _miss(
          'That digit is correct, but logic cannot prove it yet. Look for a '
          'cell with a certain digit.',
        );
      } else {
        _miss('$digit does not go in ${Board.cellName(cell)}. Try again.');
      }
    });
  }

  void _choose(Technique technique) => setState(() {
    if (technique == steps[index].technique) {
      _revealStep(found: true);
    } else {
      wrongChoices.add(technique);
      _miss('Not ${technique.label}: it finds nothing on this board.');
    }
  });

  void _revealAnswer() =>
      setState(() => solution = solveByBacktracking(boards.last));

  String? get _score => play && askedSteps.isNotEmpty
      ? 'You found ${firstTry.length} of ${askedSteps.length} moves on your '
            'own.'
      : null;

  @override
  Widget build(BuildContext context) {
    final step = atEnd ? null : steps[index];
    final hidden = asking;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: allNotes
                ? 'Show only this step\'s notes'
                : 'Show all notes',
            icon: Icon(allNotes ? Icons.grid_off : Icons.grid_view),
            onPressed: () => setState(() => allNotes = !allNotes),
          ),
        ],
      ),
      body: SafeArea(
        child: BoardWithPanel(
          board: BoardView(
            board: solution ?? boards[index],
            givens: givens,
            showCandidates: solution == null,
            step: hidden ? null : step,
            candidateFocus: allNotes || hidden ? null : step,
            selected: hidden ? selected : null,
            onCellTap: hidden ? (c) => setState(() => selected = c) : null,
          ),
          panel: _buildPanel(step, hidden: hidden),
        ),
      ),
    );
  }

  Widget _buildPanel(Step? step, {required bool hidden}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WalkthroughModeToggle(play: play, onChanged: _setPlay),
        const SizedBox(height: Space.md),
        if (step != null && !hidden) const BoardLegend(),
        const SizedBox(height: Space.lg),
        if (step != null && hidden)
          WalkthroughQuestion(
            step: step,
            number: index + 1,
            of: steps.length,
            board: boards[index],
            selected: selected,
            message: message,
            wrongChoices: wrongChoices,
            onDigit: _enter,
            onChoose: _choose,
            onShowMe: _showMe,
          )
        else if (step != null)
          WalkthroughStepPanel(step: step, number: index + 1, of: steps.length),
        if (atEnd)
          WalkthroughEndPanel(
            solved: solved,
            revealed: solution != null,
            steps: steps,
            onReveal: _revealAnswer,
            score: _score,
          ),
        const SizedBox(height: Space.lg),
        WalkthroughControls(
          index: index,
          last: steps.length,
          canAdvance: !hidden,
          showSlider: !play,
          onChanged: _go,
        ),
      ],
    );
  }
}
