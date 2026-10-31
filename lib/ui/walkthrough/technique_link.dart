import 'package:flutter/material.dart' hide Step;

import '../../engine/engine.dart';
import '../../lessons/lessons.dart';
import '../layout.dart';
import '../learn_tab.dart';
import '../levels.dart';

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
        avatar: const Icon(Icons.school_outlined, size: iconSmall),
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
