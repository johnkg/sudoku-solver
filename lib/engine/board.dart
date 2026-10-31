import 'bits.dart';
import 'step.dart';

enum UnitKind { row, column, box }

/// A row, column, or box: nine cells that must hold each digit once.
class Unit {
  const Unit(this.kind, this.index, this.cells);

  final UnitKind kind;

  /// 0-8 within its kind.
  final int index;
  final List<int> cells;

  String get name => switch (kind) {
    UnitKind.row => 'Row ${index + 1}',
    UnitKind.column => 'Column ${index + 1}',
    UnitKind.box => 'Box ${index + 1}',
  };
}

/// A 9x9 grid with placed values and pencil-mark candidates.
///
/// Cells are indexed 0 to [cellCount] - 1, row by row. A value of 0 means empty.
class Board {
  Board._(this.values, this.candidates);

  /// Cells along a row or column, and in a unit. Equal to [maxDigit].
  static const size = maxDigit;

  /// A box is [boxSize] by [boxSize] cells.
  static const boxSize = 3;

  static const cellCount = size * size;

  /// The cell at [row] and [column], both counted from 0.
  static int cellAt(int row, int column) => row * size + column;

  /// Like [cellAt], but a [row] or [column] off the grid is moved to the
  /// nearest edge.
  static int clampedCellAt(int row, int column) =>
      cellAt(row.clamp(0, size - 1), column.clamp(0, size - 1));

  /// Parses [cellCount] (81) characters: `1`-`9` for givens, `0` or `.` for blanks.
  /// Whitespace is ignored. Throws [FormatException] on bad input or if the
  /// givens already break a rule.
  factory Board.parse(String text) {
    final chars = text.replaceAll(RegExp(r'\s'), '').split('');
    if (chars.length != cellCount) {
      throw FormatException('Expected $cellCount cells, got ${chars.length}');
    }
    final board = Board._(
      List.filled(cellCount, 0),
      List.filled(cellCount, allDigitsMask),
    );
    for (var cell = 0; cell < cellCount; cell++) {
      final ch = chars[cell];
      if (ch == '0' || ch == '.') continue;
      final digit = int.tryParse(ch);
      if (digit == null || digit < 1 || digit > maxDigit) {
        throw FormatException('Bad character "$ch" at cell $cell');
      }
      if (!hasDigit(board.candidates[cell], digit)) {
        throw FormatException('Given $digit at ${cellName(cell)} conflicts');
      }
      board.place(cell, digit);
    }
    return board;
  }

  /// Rebuilds a board from saved [values] and [candidates]. Throws
  /// [FormatException] if either list is the wrong size or holds impossible
  /// numbers.
  factory Board.fromState(List<int> values, List<int> candidates) {
    if (values.length != cellCount || candidates.length != cellCount) {
      throw const FormatException(
        'Expected $cellCount values and $cellCount candidate masks',
      );
    }
    for (var i = 0; i < cellCount; i++) {
      if (values[i] < 0 || values[i] > maxDigit) {
        throw FormatException('Bad value ${values[i]} at cell $i');
      }
      if (candidates[i] < 0 || candidates[i] > allDigitsMask) {
        throw FormatException('Bad candidates ${candidates[i]} at cell $i');
      }
      if (values[i] != 0 && candidates[i] != 0) {
        throw FormatException('Filled cell $i still has candidates');
      }
    }
    return Board._(List.of(values), List.of(candidates));
  }

  final List<int> values;

  /// Candidate bitmask per cell. 0 for filled cells.
  final List<int> candidates;

  static final List<Unit> units = _buildUnits();

  /// For each cell, the other cells sharing a row, column, or box (20 of them).
  static final List<List<int>> peers = _buildPeers();

  static int rowOf(int cell) => cell ~/ size;
  static int columnOf(int cell) => cell % size;
  static int boxOf(int cell) =>
      (rowOf(cell) ~/ boxSize) * boxSize + columnOf(cell) ~/ boxSize;

  /// Row [index], counted from 0.
  static Unit row(int index) => units[index];

  /// Column [index], counted from 0.
  static Unit column(int index) => units[size + index];

  /// Box [index], counted from 0, left to right and top to bottom.
  static Unit box(int index) => units[2 * size + index];

  static String cellName(int cell) =>
      'r${rowOf(cell) + 1}c${columnOf(cell) + 1}';

  /// The three units (row, column, box) containing [cell].
  static List<Unit> unitsOf(int cell) => [
    row(rowOf(cell)),
    column(columnOf(cell)),
    box(boxOf(cell)),
  ];

  Board copy() => Board._(List.of(values), List.of(candidates));

  bool get isSolved => !values.contains(0);

  /// True if some empty cell has no candidates left.
  bool get hasContradiction {
    for (var cell = 0; cell < cellCount; cell++) {
      if (values[cell] == 0 && candidates[cell] == 0) return true;
    }
    return false;
  }

  /// Fills [cell] with [digit] and removes [digit] from its peers.
  void place(int cell, int digit) {
    values[cell] = digit;
    candidates[cell] = 0;
    final bit = digitBit(digit);
    for (final peer in peers[cell]) {
      candidates[peer] &= ~bit;
    }
  }

  /// Removes [digit] as a candidate. Returns whether anything changed.
  bool eliminate(int cell, int digit) {
    final before = candidates[cell];
    candidates[cell] &= ~digitBit(digit);
    return candidates[cell] != before;
  }

  void applyStep(Step step) {
    for (final p in step.placements) {
      place(p.cell, p.digit);
    }
    for (final e in step.eliminations) {
      for (final d in e.digits) {
        eliminate(e.cell, d);
      }
    }
  }

  /// The 81-character form accepted by [Board.parse].
  String toLine() => values.map((v) => v == 0 ? '.' : '$v').join();

  /// Like [toLine], but with 0 for an empty cell. This is how puzzles are
  /// stored and saved.
  String toDigits() => values.join();

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var r = 0; r < size; r++) {
      if (r > 0 && r % boxSize == 0) buffer.writeln('------+-------+------');
      for (var c = 0; c < size; c++) {
        if (c > 0 && c % boxSize == 0) buffer.write('| ');
        final v = values[cellAt(r, c)];
        buffer.write(v == 0 ? '. ' : '$v ');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  static List<Unit> _buildUnits() => [
    for (var r = 0; r < size; r++)
      Unit(UnitKind.row, r, [for (var c = 0; c < size; c++) cellAt(r, c)]),
    for (var c = 0; c < size; c++)
      Unit(UnitKind.column, c, [for (var r = 0; r < size; r++) cellAt(r, c)]),
    for (var b = 0; b < size; b++)
      Unit(UnitKind.box, b, [
        for (var i = 0; i < size; i++)
          cellAt(
            (b ~/ boxSize) * boxSize + i ~/ boxSize,
            (b % boxSize) * boxSize + i % boxSize,
          ),
      ]),
  ];

  static List<List<int>> _buildPeers() => [
    for (var cell = 0; cell < cellCount; cell++)
      {for (final unit in unitsOf(cell)) ...unit.cells}
          .where((c) => c != cell)
          .toList(),
  ];
}
