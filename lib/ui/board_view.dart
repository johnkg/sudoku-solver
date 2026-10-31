import 'package:flutter/material.dart' hide Step;

import '../engine/engine.dart';
import '../settings/settings.dart';
import 'board/board_painter.dart';

/// Draws the grid, digits, pencil marks, and the highlights for [step].
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.givens,
    required this.showCandidates,
    this.step,
    this.candidateFocus,
    this.selected,
    this.wrong = const {},
    this.marks,
    this.flash = const {},
    this.flashProgress = 1,
    this.marked = const {},
    this.onCellTap,
  });

  final Board board;
  final Set<int> givens;
  final bool showCandidates;
  final Step? step;

  /// When set, pencil marks are drawn only for the cells and digits this step
  /// involves, so a worked example is not buried in noise.
  final Step? candidateFocus;

  /// The cell the player has selected, if any.
  final int? selected;

  /// Wrong digits the player typed, drawn in red.
  final Map<int, int> wrong;

  /// The player's own notes, a digit bit mask per cell. When set they are
  /// drawn instead of the board's candidates, except in cells a hint is
  /// about, which show the real candidates.
  final List<int>? marks;

  /// Cells to flash, and how far the flash has faded: 0 just started, 1 gone.
  final Set<int> flash;
  final double flashProgress;

  /// Cells the player has picked out, tinted like the selected cell.
  final Set<int> marked;

  /// Called with a cell index when the player taps the board.
  final ValueChanged<int>? onCellTap;

  @override
  Widget build(BuildContext context) {
    final patterns =
        context
            .dependOnInheritedWidgetOfExactType<SettingsScope>()
            ?.notifier
            ?.patterns ??
        false;

    return Semantics(
      container: true,
      label: 'Sudoku board',
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            onTapUp: onCellTap == null
                ? null
                : (details) {
                    final cell = constraints.maxWidth / Board.size;
                    onCellTap!(
                      Board.clampedCellAt(
                        (details.localPosition.dy / cell).floor(),
                        (details.localPosition.dx / cell).floor(),
                      ),
                    );
                  },
            child: CustomPaint(
              painter: BoardPainter(
                board: board,
                givens: givens,
                showCandidates: showCandidates,
                step: step,
                candidateFocus: candidateFocus,
                selected: selected,
                wrong: wrong,
                marks: marks,
                flash: flash,
                flashProgress: flashProgress,
                marked: marked,
                patterns: patterns,
                onTap: onCellTap,
                scheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
