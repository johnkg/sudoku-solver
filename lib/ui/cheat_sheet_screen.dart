import 'package:flutter/material.dart';

import '../lessons/lessons.dart';
import 'layout.dart';
import 'learn_tab.dart' show openLesson;
import 'levels.dart';
import 'section.dart';

/// Whether [lesson] matches what the player typed: any of its words appear in
/// the technique name, tagline, idea or spotting tip.
bool lessonMatches(Lesson lesson, String query) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final text = [
    lesson.technique.label,
    lesson.tagline,
    lesson.idea,
    lesson.spot,
  ].join(' ').toLowerCase();
  return words.every(text.contains);
}

/// Every technique on one searchable page: what it is, how to spot it, and a
/// link to its lesson. For looking something up mid-puzzle.
class CheatSheetScreen extends StatefulWidget {
  const CheatSheetScreen({super.key});

  @override
  State<CheatSheetScreen> createState() => _CheatSheetScreenState();
}

class _CheatSheetScreenState extends State<CheatSheetScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = [
      for (final l in lessons)
        if (lessonMatches(l, query)) l,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Technique cheat sheet')),
      body: Center(
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
              TextField(
                key: const Key('cheat-search'),
                onChanged: (v) => setState(() => query = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search techniques',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(cardRadius),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xl),
                  child: Text(
                    'No technique matches "$query".',
                    key: const Key('cheat-empty'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              for (final level in levelNames.keys)
                if (shown.any((l) => l.level == level)) ...[
                  SectionTitle('Level $level · ${levelNames[level]}'),
                  for (final lesson in shown.where((l) => l.level == level))
                    _CheatCard(lesson: lesson),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheatCard extends StatelessWidget {
  const _CheatCard({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget part(String heading, String text) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(text, style: theme.textTheme.bodyMedium),
      ],
    );

    return Card(
      key: Key('cheat-${lesson.technique.name}'),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(lesson.technique.label, style: theme.textTheme.titleSmall),
        subtitle: Text(lesson.tagline),
        childrenPadding: const EdgeInsets.fromLTRB(
          Space.lg,
          0,
          Space.lg,
          Space.lg,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          part('The idea', lesson.idea),
          const SizedBox(height: Space.md),
          part('How to spot it', lesson.spot),
          const SizedBox(height: Space.md),
          OutlinedButton(
            onPressed: () => openLesson(context, lesson),
            child: const Text('Open the lesson'),
          ),
        ],
      ),
    );
  }
}
