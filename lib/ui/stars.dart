import 'package:flutter/material.dart';

/// Up to three stars, filled for [count].
class Stars extends StatelessWidget {
  const Stars({super.key, required this.count, this.size = 18});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Semantics(
      label: '$count of 3 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
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
