import '../../engine/engine.dart';

/// What a solver step says to draw on the board: the cells it is about, the
/// digits it places and the candidates it removes.
class StepMarkup {
  StepMarkup(this.step, Step? candidateFocus)
    : highlighted = {...?step?.highlightCells},
      placed = {
        for (final p in step?.placements ?? <Placement>[]) p.cell: p.digit,
      },
      removed = {
        for (final e in step?.eliminations ?? <Elimination>[]) e.cell: e.digits,
      },
      _focusCells = candidateFocus == null ? null : _cellsOf(candidateFocus),
      _focusDigits = candidateFocus == null ? null : _digitsOf(candidateFocus);

  final Step? step;

  /// Cells the step's pattern is made of.
  final Set<int> highlighted;

  /// Digits the step places, by cell.
  final Map<int, int> placed;

  /// Candidates the step removes, by cell.
  final Map<int, List<int>> removed;

  final Set<int>? _focusCells;
  final Set<int>? _focusDigits;

  /// Links of the step's pattern.
  List<ChainLink> get links => step?.links ?? const [];

  /// Whether the pencil mark for [digit] in [cell] is worth drawing. With no
  /// candidate focus every mark is; with one, only those the focus step
  /// involves, so a worked example is not buried in noise.
  bool showsNote(int cell, int digit) =>
      _focusCells == null ||
      (_focusCells.contains(cell) && _focusDigits!.contains(digit));

  /// Whether [digit] in [cell] is part of the step's pattern.
  bool inPattern(int cell, int digit) =>
      highlighted.contains(cell) &&
      (step?.highlightDigits.contains(digit) ?? false);

  static Set<int> _cellsOf(Step step) => {
    ...step.highlightCells,
    ...step.placements.map((p) => p.cell),
    ...step.eliminations.map((e) => e.cell),
  };

  static Set<int> _digitsOf(Step step) => {
    ...step.highlightDigits,
    for (final e in step.eliminations) ...e.digits,
  };
}
