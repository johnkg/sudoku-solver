import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';
import '../lessons/lessons.dart';
import 'board_view.dart';
import 'learn_tab.dart';
import 'levels.dart';
import 'step_text.dart';

/// Steps through the way the solver would crack [start], one move at a time,
/// explaining each and linking the technique to its lesson.
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key, required this.start});

  final Board start;

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

  @override
  void initState() {
    super.initState();
    const solver = Solver();
    var board = widget.start.copy();
    givens = {
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

  void _go(int to) => setState(() => index = to.clamp(0, steps.length));

  void _reveal() => setState(() => solution = solveByBacktracking(boards.last));

  @override
  Widget build(BuildContext context) {
    final board = solution ?? boards[index];
    final step = atEnd ? null : steps[index];

    final boardView = BoardView(
      board: board,
      givens: givens,
      showCandidates: solution == null,
      step: step,
      candidateFocus: allNotes ? null : step,
    );

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step != null)
          _StepPanel(step: step, number: index + 1, of: steps.length),
        if (atEnd)
          _EndPanel(
            solved: solved,
            revealed: solution != null,
            steps: steps,
            onReveal: _reveal,
          ),
        const SizedBox(height: 16),
        _Controls(index: index, last: steps.length, onChanged: _go),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to solve it'),
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
  });

  final bool solved;
  final bool revealed;
  final List<Step> steps;
  final VoidCallback onReveal;

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
    required this.onChanged,
  });

  final int index;
  final int last;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (last > 1)
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
                onPressed: index == last ? null : () => onChanged(index + 1),
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
