import 'package:flutter/material.dart' hide Step;

import '../layout.dart';
import '../solve_controller.dart';

/// Undo, pencil marks, candidate removal and hint, as big icon buttons.
class ToolBar extends StatelessWidget {
  const ToolBar({super.key, required this.controller});

  final SolveController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.solved) return const SizedBox.shrink();
    final notes = controller.mode == EntryMode.notes;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: ToolButton(
              tooltip: 'Undo',
              label: 'Undo',
              icon: Icons.undo,
              onPressed: controller.canUndo ? controller.undo : null,
            ),
          ),
          Expanded(
            child: ToolButton(
              tooltip: 'Erase',
              label: 'Erase',
              icon: Icons.backspace_outlined,
              onPressed: controller.erase,
            ),
          ),
          Expanded(
            child: ToolButton(
              tooltip: notes ? 'Switch to placing digits' : 'Edit notes',
              label: 'Notes',
              icon: Icons.edit_outlined,
              badge: notes ? 'ON' : 'OFF',
              onPressed: () =>
                  controller.setMode(notes ? EntryMode.place : EntryMode.notes),
            ),
          ),
          Expanded(
            child: ToolButton(
              tooltip: controller.notesFilled
                  ? 'Hide all notes'
                  : 'Show all notes',
              label: 'Auto',
              icon: Icons.auto_fix_high,
              badge: controller.notesFilled ? 'ON' : 'OFF',
              onPressed: controller.toggleAutoNotes,
            ),
          ),
          Expanded(
            child: ToolButton(
              tooltip: 'Get a hint',
              label: 'Hint',
              icon: Icons.lightbulb_outline,
              onPressed: controller.findNextStep,
            ),
          ),
        ],
      ),
    );
  }
}

class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// A small ON / OFF pill on the icon, for tools that stay switched.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final color = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurface.withValues(alpha: disabledOpacity);

    return Tooltip(
      message: tooltip,
      child: Ink(
        decoration: BoxDecoration(
          color: badge == 'ON' ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(keyRadius),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(keyRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: iconMedium, color: color),
                    if (badge != null)
                      Positioned(
                        left: 16,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: badge == 'ON'
                                ? scheme.primary
                                : scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(badgeRadius),
                          ),
                          child: Text(
                            badge!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: badgeFontSize,
                              fontWeight: FontWeight.w800,
                              color: badge == 'ON'
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
