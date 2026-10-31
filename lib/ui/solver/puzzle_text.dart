import '../../engine/engine.dart';

/// A whole grid's worth of characters: digits, and the markers for a blank.
final _gridCharacters = RegExp(r'^[0-9.\-_*]+$');

/// Turns text into 81 cells, or null if it is not a puzzle. Digits are
/// givens; `0`, `.`, `-`, `_` and `*` are blanks; whitespace is ignored.
List<int>? parsePuzzleText(String text) {
  final chars = text.replaceAll(RegExp(r'\s'), '');
  if (chars.length != Board.cellCount || !_gridCharacters.hasMatch(chars)) {
    return null;
  }
  return [for (final ch in chars.split('')) int.tryParse(ch) ?? 0];
}
