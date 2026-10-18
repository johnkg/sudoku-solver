import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';
import '../lessons/lessons.dart';
import 'board_view.dart';
import 'learn_tab.dart';
import 'levels.dart';
import 'step_text.dart';
import 'technique_choices.dart';

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
  int? selected;
  String? message;
  final wrongChoices = <Technique>{};
  bool missed = false;

  @override
  void initState() {
    super.initState();
    const solver = Solver();
    var board = widget.start.copy();
    givens =
        widget.givens ??
        {
          for (var i = 0; i < 81; i++)
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

  void _go(int to) => setState(() {
    index = to.clamp(0, steps.length);
    selected = null;
    message = null;
    wrongChoices.clear();
    missed = false;
  });

  void _setPlay(bool on) => setState(() {
    play = on;
    selected = null;
    message = null;
    wrongChoices.clear();
    missed = false;
    if (on) {
      revealedSteps
        ..clear()
        ..addAll([for (var i = 0; i < index; i++) i]);
      askedSteps.clear();
      firstTry.clear();
    }
  });

  void _found() {
    askedSteps.add(index);
    if (!missed) firstTry.add(index);
    revealedSteps.add(index);
    selected = null;
    message = null;
    wrongChoices.clear();
  }

  void _showMe() => setState(() {
    askedSteps.add(index);
    revealedSteps.add(index);
    selected = null;
    message = null;
    wrongChoices.clear();
  });

  void _miss(String text) {
    missed = true;
    message = text;
  }

  late final Board? answer = solveByBacktracking(boards.first);

  void _enter(int digit) {
    final cell = selected;
    if (cell == null) return;
    final step = steps[index];
    setState(() {
      if (step.placements.any((p) => p.cell == cell && p.digit == digit)) {
        _found();
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

  void _choose(Technique t) => setState(() {
    if (t == steps[index].technique) {
      _found();
    } else {
      wrongChoices.add(t);
      _miss('Not ${t.label}: it finds nothing on this board.');
    }
  });

  void _reveal() => setState(() => solution = solveByBacktracking(boards.last));

  @override
  Widget build(BuildContext context) {
    final board = solution ?? boards[index];
    final step = atEnd ? null : steps[index];
    final hidden = asking;

    final boardView = BoardView(
      board: board,
      givens: givens,
      showCandidates: solution == null,
      step: hidden ? null : step,
      candidateFocus: allNotes || hidden ? null : step,
      selected: hidden ? selected : null,
      onCellTap: hidden ? (c) => setState(() => selected = c) : null,
    );

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Watch', key: Key('mode-watch')),
              icon: Icon(Icons.visibility_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Your turn', key: Key('mode-play')),
              icon: Icon(Icons.touch_app_outlined),
            ),
          ],
          selected: {play},
          onSelectionChanged: (s) => _setPlay(s.first),
        ),
        const SizedBox(height: 16),
        if (step != null && hidden)
          _Question(
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
          _StepPanel(step: step, number: index + 1, of: steps.length),
        if (atEnd)
          _EndPanel(
            solved: solved,
            revealed: solution != null,
            steps: steps,
            onReveal: _reveal,
            score: play && askedSteps.isNotEmpty
                ? 'You found ${firstTry.length} of ${askedSteps.length} moves '
                      'on your own.'
                : null,
          ),
        const SizedBox(height: 16),
        _Controls(
          index: index,
          last: steps.length,
          canAdvance: !hidden,
          slider: !play,
          onChanged: _go,
        ),
      ],
    );

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 840 ||
                constraints.maxWidth > constraints.maxHeight * 1.2;
            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxHeight - 32,
                          ),
                          child: boardView,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(child: panel),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [boardView, const SizedBox(height: 16), panel],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.step,
    required this.number,
    required this.of,
  });

  final Step step;
  final int number;
  final int of;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $number of $of',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        TechniqueLink(technique: step.technique),
        const SizedBox(height: 12),
        Text(step.explanation, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              describeResult(step),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A chip that opens the lesson for [technique].
class TechniqueLink extends StatelessWidget {
  const TechniqueLink({super.key, required this.technique, this.count});

  final Technique technique;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        key: Key('technique-${technique.name}'),
        avatar: const Icon(Icons.school_outlined, size: 18),
        label: Text(
          count == null
              ? '${technique.label} · ${levelNames[technique.level]}'
              : '${technique.label} × $count',
        ),
        tooltip: 'Learn about ${technique.label}',
        onPressed: () => openLesson(context, lessonFor(technique)),
      ),
    );
  }
}

class _EndPanel extends StatelessWidget {
  const _EndPanel({
    required this.solved,
    required this.revealed,
    required this.steps,
    required this.onReveal,
    this.score,
  });

  final bool solved;
  final bool revealed;
  final List<Step> steps;
  final VoidCallback onReveal;
  final String? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <Technique, int>{};
    for (final step in steps) {
      counts[step.technique] = (counts[step.technique] ?? 0) + 1;
    }
    final used = Technique.values.where(counts.containsKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          solved
              ? 'Solved in ${steps.length} steps.'
              : revealed
              ? 'The rest was filled in by trial and error.'
              : 'The solver is stuck.',
          style: theme.textTheme.headlineSmall,
        ),
        if (score != null) ...[
          const SizedBox(height: 8),
          Text(
            score!,
            key: const Key('score'),
            style: theme.textTheme.titleMedium,
          ),
        ],
        const SizedBox(height: 8),
        if (!solved && !revealed) ...[
          Text(
            'None of the techniques in this app finds another move. The rest '
            'needs something harder, or trial and error.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('reveal'),
            onPressed: onReveal,
            child: const Text('Show the answer'),
          ),
        ],
        if (used.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Techniques used', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final t in used)
                TechniqueLink(technique: t, count: counts[t]),
            ],
          ),
        ],
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.index,
    required this.last,
    required this.canAdvance,
    required this.slider,
    required this.onChanged,
  });

  final int index;
  final int last;

  /// False while the player still has to find the move.
  final bool canAdvance;
  final bool slider;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (last > 1 && slider)
          Slider(
            value: index.toDouble(),
            max: last.toDouble(),
            divisions: last,
            label: index == last ? 'Done' : 'Step ${index + 1}',
            onChanged: (v) => onChanged(v.round()),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('prev-step'),
                onPressed: index == 0 ? null : () => onChanged(index - 1),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('next-step'),
                onPressed: index == last || !canAdvance
                    ? null
                    : () => onChanged(index + 1),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Asks the player to find the move of [step] on [board].
class _Question extends StatelessWidget {
  const _Question({
    required this.step,
    required this.number,
    required this.of,
    required this.board,
    required this.selected,
    required this.message,
    required this.wrongChoices,
    required this.onDigit,
    required this.onChoose,
    required this.onShowMe,
  });

  final Step step;
  final int number;
  final int of;
  final Board board;
  final int? selected;
  final String? message;
  final Set<Technique> wrongChoices;
  final ValueChanged<int> onDigit;
  final ValueChanged<Technique> onChoose;
  final VoidCallback onShowMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final places = step.placements.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $number of $of · your turn',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          places
              ? 'Find a digit you can place for certain. Tap its cell, then '
                    'choose the digit.'
              : 'No digit can be placed yet, but a technique lets you remove '
                    'candidates. Which one finds a move on this board?',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        if (places)
          Row(
            children: [
              for (var d = 1; d <= 9; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FilledButton.tonal(
                      key: Key('play-digit-$d'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: selected == null ? null : () => onDigit(d),
                      child: Text('$d', style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in techniqueChoices(board, step.technique))
                ChoiceChip(
                  key: Key('choice-${t.name}'),
                  label: Text(t.label),
                  selected: false,
                  onSelected: wrongChoices.contains(t)
                      ? null
                      : (_) => onChoose(t),
                ),
            ],
          ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            key: const Key('feedback'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          key: const Key('show-me'),
          onPressed: onShowMe,
          child: const Text('Show me'),
        ),
      ],
    );
  }
}
