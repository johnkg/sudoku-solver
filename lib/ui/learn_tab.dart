import 'package:flutter/material.dart';

import '../lessons/lessons.dart';
import '../progress/progress_scope.dart';
import '../progress/progress_store.dart';
import 'layout.dart';
import 'lesson_screen.dart';
import 'learn_progress.dart';
import 'level_header.dart';
import 'levels.dart';
import 'unlocking.dart';
import 'weak_spots.dart';

/// The list of technique lessons, grouped by level. A level opens once the
/// one below is solved.
class LearnTab extends StatelessWidget {
  const LearnTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ProgressScope.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.xxl,
          ),
          children: [
            _ProgressHeader(store: store),
            if (weakSpots(store).isNotEmpty)
              Card(
                key: const Key('revisit'),
                margin: const EdgeInsets.only(top: Space.md),
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Worth revisiting',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.sm,
                        children: [
                          for (final t in weakSpots(store))
                            ActionChip(
                              key: Key('revisit-${t.name}'),
                              label: Text(t.label),
                              onPressed: () =>
                                  openLesson(context, lessonFor(t)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            for (final level in levelNames.keys) ...[
              Builder(
                builder: (context) {
                  final unlocked = isLevelUnlocked(store, level);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LevelHeader(
                        level: level,
                        unlocked: unlocked,
                        blurb: unlocked
                            ? levelBlurbs[level]!
                            : unlockHint(level),
                        progress: _progressLabel(store, level),
                      ),
                      for (final lesson in lessons.where(
                        (l) => l.level == level,
                      ))
                        _LessonTile(lesson: lesson, unlocked: unlocked),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _progressLabel(ProgressStore store, int level) {
  final p = levelProgress(store, level);
  return '${p.done} / ${p.total}';
}

/// The top of the Learn tab: how much is practised overall, and a card that
/// opens the next lesson to work on.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overall = overallProgress(store);
    final fraction = overall.total == 0 ? 0.0 : overall.done / overall.total;
    final next = nextLesson(store);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Learn the techniques one at a time, from the simplest to the '
                'most advanced. Each lesson has a worked example.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: Space.lg),
            Semantics(
              label: '${overall.done} of ${overall.total} lessons practised',
              excludeSemantics: true,
              child: SizedBox(
                key: const Key('learn-ring'),
                width: progressRingSize,
                height: progressRingSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: progressRingStroke,
                      backgroundColor: scheme.surfaceContainer,
                    ),
                    Text(
                      '${(fraction * 100).round()}%',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (next != null)
          Card(
            key: const Key('continue-lesson'),
            margin: const EdgeInsets.only(top: Space.lg),
            color: scheme.onSurface,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT UP',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.surface.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    next.technique.label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.surface,
                    ),
                  ),
                  const SizedBox(height: Space.hair),
                  Text(
                    next.tagline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.surface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.tertiaryContainer,
                      foregroundColor: scheme.onTertiaryContainer,
                    ),
                    onPressed: () => openLesson(context, next),
                    child: const Text('Start lesson'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.unlocked});

  final Lesson lesson;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final practised = isPractised(store, lesson);

    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: ListTile(
        enabled: unlocked,
        title: Text(lesson.technique.label),
        subtitle: Text(lesson.tagline),
        trailing: !unlocked
            ? const Icon(Icons.lock_outline)
            : practised
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: 'Practised',
              )
            : const Icon(Icons.chevron_right),
        onTap: () => openLesson(context, lesson),
      ),
    );
  }
}

void openLesson(BuildContext context, Lesson lesson) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => LessonScreen(lesson: lesson)));
}
