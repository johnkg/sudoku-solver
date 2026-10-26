import 'package:flutter/material.dart';

import '../lessons/lessons.dart';
import '../progress/progress_scope.dart';
import 'layout.dart';
import 'lesson_screen.dart';
import 'level_header.dart';
import 'levels.dart';
import 'puzzle_library.dart';
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
            Text(
              'Learn the techniques one at a time, from the simplest to the '
              'most advanced. Each lesson has a worked example.',
              style: theme.textTheme.bodyLarge,
            ),
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

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.unlocked});

  final Lesson lesson;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final store = ProgressScope.of(context);
    final practised = puzzleLibrary.any(
      (p) => p.technique == lesson.technique && store.isSolved(p.id),
    );

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
