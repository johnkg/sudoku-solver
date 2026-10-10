import '../engine/engine.dart';

/// The hint ladder shows a solver step in three stages, each giving away more:
///
/// 1. a nudge: where to look, without naming the technique,
/// 2. the technique and the pattern's cells,
/// 3. the full move, with what it changes.
///
/// These helpers build the first two stages from a real step.

/// The row, column, or box where [step] does its work, if there is one:
/// the unit holding every cell the step touches. A box is preferred over a
/// row, and a row over a column, when several qualify.
Unit? hintUnit(Step step) {
  Unit? commonUnit(Set<int> cells) {
    if (cells.isEmpty) return null;
    final order = [
      ...Board.units.where((u) => u.kind == UnitKind.box),
      ...Board.units.where((u) => u.kind == UnitKind.row),
      ...Board.units.where((u) => u.kind == UnitKind.column),
    ];
    for (final unit in order) {
      if (cells.every(unit.cells.contains)) return unit;
    }
    return null;
  }

  final involved = {
    ...step.highlightCells,
    ...step.placements.map((p) => p.cell),
    ...step.eliminations.map((e) => e.cell),
  };
  return commonUnit(involved) ?? commonUnit({...step.highlightCells});
}

/// Techniques whose highlighted digit is the answer itself, so a nudge must
/// not name it.
const _digitIsAnswer = {Technique.fullHouse, Technique.nakedSingle};

String _digitList(List<int> digits) {
  if (digits.length == 1) return '${digits.first}';
  final head = digits.sublist(0, digits.length - 1).join(', ');
  return '$head and ${digits.last}';
}

/// Stage 1 text: where to look.
String nudgeText(Step step) {
  final unit = hintUnit(step);
  final digits = _digitIsAnswer.contains(step.technique)
      ? const <int>[]
      : step.highlightDigits;

  if (unit != null) {
    if (digits.length == 1) {
      return 'Look at ${unit.name}. Focus on the digit ${digits.first}.';
    }
    if (digits.length > 1) {
      return 'Look at ${unit.name}. The digits ${_digitList(digits)} matter '
          'here.';
    }
    return 'Look at ${unit.name}.';
  }
  if (digits.length == 1) {
    return 'Focus on the digit ${digits.first}. Look at where it can go '
        'across several rows and columns.';
  }
  if (digits.length > 1) {
    return 'Look for a pattern that uses the digits ${_digitList(digits)}.';
  }
  return 'Look carefully at the pencil marks.';
}

/// Stage 1 board view: the unit tinted, nothing else.
Step nudgeView(Step step) {
  final unit = hintUnit(step);
  return Step(
    technique: step.technique,
    explanation: nudgeText(step),
    highlightCells: unit?.cells ?? const [],
  );
}

/// Stage 2 board view: the pattern's cells and digits, but not what the move
/// changes.
Step patternView(Step step) => Step(
  technique: step.technique,
  explanation: '',
  highlightCells: step.highlightCells,
  highlightDigits: step.highlightDigits,
);
