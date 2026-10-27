import 'package:flutter/material.dart';

import 'layout.dart';

/// The heading above a group of cards on a long screen.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.roomy, bottom: Space.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// An icon on a small rounded tile. With [highlight] the tile takes the
/// marker colour; otherwise it is the soft primary tint.
class IconChip extends StatelessWidget {
  const IconChip(
    this.icon, {
    super.key,
    this.highlight = false,
    this.muted = false,
  });

  final IconData icon;
  final bool highlight;

  /// A greyed tile, for something not earned or not open yet.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = highlight
        ? scheme.tertiaryContainer
        : muted
        ? scheme.surfaceContainer
        : scheme.primaryContainer;
    final foreground = highlight
        ? scheme.onTertiaryContainer
        : muted
        ? scheme.onSurfaceVariant
        : scheme.primary;

    return Container(
      width: avatarRadius * 2,
      height: avatarRadius * 2,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(keyRadius),
      ),
      child: Icon(icon, size: iconSmall + Space.xs, color: foreground),
    );
  }
}

/// A row of short bars, one per step, with the steps up to [done] filled.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Container(
              height: Space.xs,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : Space.xs),
              decoration: BoxDecoration(
                color: i < done ? scheme.primary : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(barRadius),
              ),
            ),
          ),
      ],
    );
  }
}
