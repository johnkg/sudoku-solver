import 'package:flutter/material.dart';

import 'layout.dart';

/// A board with a panel of controls or text next to it on wide screens and
/// below it on narrow ones. The panel scrolls with the board on a narrow
/// screen, and by itself on a wide one.
class BoardWithPanel extends StatelessWidget {
  const BoardWithPanel({super.key, required this.board, required this.panel});

  final Widget board;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (useSideBySide(constraints)) {
          return Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  flex: boardFlex,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxHeight - boardVerticalMargin,
                      ),
                      child: board,
                    ),
                  ),
                ),
                const SizedBox(width: Space.xl),
                Expanded(
                  flex: panelFlex,
                  child: SingleChildScrollView(child: panel),
                ),
              ],
            ),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: boardScreenMaxWidth),
            child: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                board,
                const SizedBox(height: Space.lg),
                panel,
              ],
            ),
          ),
        );
      },
    );
  }
}
