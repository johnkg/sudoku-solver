import 'package:flutter/material.dart';

import '../layout.dart';

/// Arranges the parts of the solve screen for the space available.
class SolveLayout extends StatelessWidget {
  const SolveLayout({
    super.key,
    required this.stats,
    required this.board,
    required this.status,
    required this.tools,
    required this.pad,
    required this.panel,
  });

  final Widget stats;
  final Widget board;
  final Widget status;
  final Widget tools;
  final Widget pad;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side on wide screens and on phones turned sideways, where
        // a full-width board would not fit the height.
        if (useSideBySide(constraints)) return _sideBySide();
        return _stacked();
      },
    );
  }

  Widget _sideBySide() {
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: boardFlex, child: board),
          const SizedBox(width: Space.xl),
          Expanded(
            flex: panelFlex,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stats,
                  const SizedBox(height: Space.sm),
                  status,
                  tools,
                  pad,
                  const SizedBox(height: Space.lg),
                  panel,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The board and the hint panel scroll, while the tools and digits stay
  /// within thumb reach at the bottom.
  Widget _stacked() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.md),
            children: [
              stats,
              board,
              status,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: panel,
              ),
            ],
          ),
        ),
        tools,
        pad,
        const SizedBox(height: Space.sm),
      ],
    );
  }
}
