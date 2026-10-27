import 'package:flutter/material.dart';

import 'layout.dart';

import 'levels.dart';

/// The heading of one level on the Learn and Practice tabs: a numbered badge,
/// the level's name, and a lock while it is closed. [blurb] says what the
/// level is about, or how to open it.
class LevelHeader extends StatelessWidget {
  const LevelHeader({
    super.key,
    required this.level,
    required this.unlocked,
    required this.blurb,
  });

  final int level;
  final bool unlocked;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: Space.wide, bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: avatarRadius * 2,
            height: avatarRadius * 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unlocked
                  ? scheme.primaryContainer
                  : scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(keyRadius),
            ),
            child: unlocked
                ? Text(
                    '$level',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Icon(
                    Icons.lock_outline,
                    size: iconSmall,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level $level · ${levelNames[level]}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Space.hair),
                Text(
                  blurb,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
