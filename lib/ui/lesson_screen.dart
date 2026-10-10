import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';
import '../lessons/lessons.dart';
import 'board_view.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'solve_screen.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

enum _View { before, after }

class _LessonScreenState extends State<LessonScreen> {
  late final Board before;
  late final Board after;
  late final Step step;
  _View view = _View.before;

  @override
  void initState() {
    super.initState();
    final example = widget.lesson.example();
    before = example.board;
    step = example.step;
    after = before.copy()..applyStep(step);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = widget.lesson;
    final practice = puzzleLibrary
        .where((p) => p.technique == lesson.technique)
        .toList();

    final example = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Worked example', style: theme.textTheme.titleMedium),
            ),
            SegmentedButton<_View>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _View.before, label: Text('Before')),
                ButtonSegment(value: _View.after, label: Text('After')),
              ],
              selected: {view},
              onSelectionChanged: (s) => setState(() => view = s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BoardView(
          board: view == _View.before ? before : after,
          givens: {
            for (var i = 0; i < 81; i++)
              if (before.values[i] != 0) i,
          },
          showCandidates: true,
          step: view == _View.before ? step : null,
          candidateFocus: step,
        ),
        const SizedBox(height: 12),
        Text(
          view == _View.before ? step.explanation : _result(step),
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Level ${lesson.level} · ${levelNames[lesson.level]}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(lesson.tagline, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text('The idea', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(lesson.idea, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        Text('How to spot it', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(lesson.spot, style: theme.textTheme.bodyLarge),
      ],
    );

    final practiceSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Practice', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (practice.isEmpty)
          Text(
            'There is no practice puzzle for this technique yet. It turns up '
            'in harder puzzles.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final puzzle in practice)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(puzzle.title),
                subtitle: const Text('Solve it with the solver\'s help'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SolveScreen(puzzle: puzzle),
                  ),
                ),
              ),
            ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(lesson.technique.label)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 840) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(child: example),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            text,
                            const SizedBox(height: 24),
                            practiceSection,
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
                text,
                const SizedBox(height: 24),
                example,
                const SizedBox(height: 24),
                practiceSection,
              ],
            );
          },
        ),
      ),
    );
  }

  /// A plain description of what the step changed.
  String _result(Step step) {
    final parts = [
      for (final p in step.placements)
        '${Board.cellName(p.cell)} is now ${p.digit}.',
      for (final e in step.eliminations)
        'Removed ${e.digits.join(', ')} from ${Board.cellName(e.cell)}.',
    ];
    return parts.join(' ');
  }
}
