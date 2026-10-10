import 'package:flutter/material.dart';

import '../lessons/lessons.dart';
import '../progress/progress_scope.dart';
import 'lesson_screen.dart';
import 'levels.dart';
import 'puzzle_library.dart';
import 'unlocking.dart';

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
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Learn the techniques one at a time, from the simplest to the '
              'most advanced. Each lesson has a worked example.',
              style: theme.textTheme.bodyLarge,
            ),
            for (final level in levelNames.keys) ...[
              Builder(
                builder: (context) {
                  final unlocked = isLevelUnlocked(store, level);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              'Level $level · ${levelNames[level]}',
                              style: theme.textTheme.titleMedium,
                            ),
                            if (!unlocked) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.lock_outline, size: 18),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        unlocked ? levelBlurbs[level]! : unlockHint(level),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(bottom: 8),
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
