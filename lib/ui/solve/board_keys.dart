import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../digit_keys.dart';
import '../solve_controller.dart';

/// How far each arrow key moves the selection, as (rows, columns).
final _arrowMoves = {
  LogicalKeyboardKey.arrowUp: (-1, 0),
  LogicalKeyboardKey.arrowDown: (1, 0),
  LogicalKeyboardKey.arrowLeft: (0, -1),
  LogicalKeyboardKey.arrowRight: (0, 1),
};

/// Lets the player play from a keyboard: digits enter, arrows move.
KeyEventResult handleSolveKey(SolveController controller, KeyEvent event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  final key = event.logicalKey;

  final digit = digitOfKey(key);
  if (digit != null) {
    controller.enter(digit);
    return KeyEventResult.handled;
  }
  final move = _arrowMoves[key];
  if (move == null) return KeyEventResult.ignored;
  controller.moveSelection(move.$1, move.$2);
  return KeyEventResult.handled;
}
