import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';
import '../lessons/lessons.dart';
import 'board_view.dart';
import 'layout.dart';
import 'levels.dart';
import 'navigation.dart';
import 'link_legend.dart';
import 'puzzle_library.dart';
import 'quiz_screen.dart';
import 'solve_screen.dart';
import 'step_text.dart';

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
        const SizedBox(height: Space.md),
        BoardView(
          board: view == _View.before ? before : after,
          givens: {
            for (var i = 0; i < Board.cellCount; i++)
              if (before.values[i] != 0) i,
          },
          showCandidates: true,
          step: view == _View.before ? step : null,
          candidateFocus: step,
        ),
        const SizedBox(height: Space.md),
        Text(
          view == _View.before ? step.explanation : describeResult(step),
          style: theme.textTheme.bodyLarge,
        ),
        if (view == _View.before) LinkLegend(step: step),
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
        const SizedBox(height: Space.xs),
        Text(lesson.tagline, style: theme.textTheme.headlineSmall),
        const SizedBox(height: Space.lg),
        Text('The idea', style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.xs),
        Text(lesson.idea, style: theme.textTheme.bodyLarge),
        const SizedBox(height: Space.lg),
        Text('How to spot it', style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.xs),
        Text(lesson.spot, style: theme.textTheme.bodyLarge),
      ],
    );

    final practiceSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Practice', style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.sm),
        Card(
          margin: const EdgeInsets.only(bottom: Space.sm),
          child: ListTile(
            key: const Key('quiz-me'),
            leading: const Icon(Icons.quiz_outlined),
            title: const Text('Quiz me'),
            subtitle: Text('Spot the ${lesson.technique.label} on real boards'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pushScreen(
              context,
              (_) => QuizScreen(technique: lesson.technique),
            ),
          ),
        ),
        if (practice.isEmpty)
          Text(
            'There is no practice puzzle for this technique yet. It turns up '
            'in harder puzzles.',
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final puzzle in practice)
            Card(
              margin: const EdgeInsets.only(bottom: Space.sm),
              child: ListTile(
                title: Text(puzzle.title),
                subtitle: const Text('Solve it with the solver\'s help'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    pushScreen(context, (_) => SolveScreen(puzzle: puzzle)),
              ),
            ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(lesson.technique.label)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= wideLayoutMinWidth) {
              return Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: boardFlex,
                      child: SingleChildScrollView(child: example),
                    ),
                    const SizedBox(width: Space.xl),
                    Expanded(
                      flex: panelFlex,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            text,
                            const SizedBox(height: Space.xl),
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
              padding: const EdgeInsets.all(Space.lg),
              children: [
                text,
                const SizedBox(height: Space.xl),
                example,
                const SizedBox(height: Space.xl),
                practiceSection,
              ],
            );
          },
        ),
      ),
    );
  }
}
