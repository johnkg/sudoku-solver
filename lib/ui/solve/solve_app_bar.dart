import 'package:flutter/material.dart';

import '../solve_controller.dart';

/// The solve screen's title and its buttons: guide, pause, pencil marks and
/// start over.
class SolveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SolveAppBar({
    super.key,
    required this.title,
    required this.controller,
    required this.onOpenGuide,
  });

  final String title;
  final SolveController controller;
  final VoidCallback onOpenGuide;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: true,
      title: Text(title),
      actions: [
        if (!controller.solved) ...[
          IconButton(
            tooltip: 'Step-by-step guide',
            icon: const Icon(Icons.school_outlined),
            onPressed: onOpenGuide,
          ),
          IconButton(
            tooltip: controller.paused ? 'Resume' : 'Pause',
            icon: Icon(
              controller.paused
                  ? Icons.play_circle_outline
                  : Icons.pause_circle_outline,
            ),
            onPressed: controller.togglePause,
          ),
        ],
        IconButton(
          tooltip: controller.showCandidates
              ? 'Hide pencil marks'
              : 'Show pencil marks',
          icon: Icon(
            controller.showCandidates
                ? Icons.grid_view
                : Icons.grid_view_outlined,
          ),
          onPressed: controller.toggleCandidates,
        ),
        IconButton(
          tooltip: 'Start over',
          icon: const Icon(Icons.restart_alt),
          onPressed: controller.canUndo || controller.pending != null
              ? controller.restart
              : null,
        ),
      ],
    );
  }
}
