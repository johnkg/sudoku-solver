import 'package:flutter/material.dart';

import '../progress/progress_scope.dart';
import 'layout.dart';
import 'navigation.dart';
import 'quiz_screen.dart';
import 'review.dart';

/// A card on the Practice tab: the techniques due for a refresher today, each
/// with a button that starts a quiz on it. Techniques come back sooner when
/// missed and later each time they go right. Shows nothing until something is
/// due.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ProgressScope.of(context);
    final due = dueForReview(store);
    if (due.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('review-card'),
      margin: const EdgeInsets.only(top: Space.lg),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review today', style: theme.textTheme.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              'A quick refresher keeps a technique fresh. Each right answer '
              'pushes the next review further away.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final technique in due)
              ListTile(
                key: Key('review-${technique.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(technique.label),
                subtitle: Text(
                  _overdueText(
                    daysOverdue(
                      store.techniqueStats[technique.name]!,
                      store.today,
                    ),
                  ),
                ),
                trailing: FilledButton.tonal(
                  onPressed: () => pushScreen(
                    context,
                    (_) => QuizScreen(technique: technique),
                  ),
                  child: const Text('Quiz'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _overdueText(int days) => switch (days) {
  <= 0 => 'Due today',
  1 => '1 day overdue',
  _ => '$days days overdue',
};
