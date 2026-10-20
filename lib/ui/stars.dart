import 'package:flutter/material.dart';

import '../progress/progress_store.dart' show PuzzleRecord;

/// Up to [PuzzleRecord.maxStars] stars, filled for [count].
class Stars extends StatelessWidget {
  const Stars({super.key, required this.count, this.size = defaultSize});

  static const defaultSize = 18.0;

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Semantics(
      label: '$count of ${PuzzleRecord.maxStars} stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < PuzzleRecord.maxStars; i++)
              Icon(
                i < count ? Icons.star : Icons.star_border,
                size: size,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}
