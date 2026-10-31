import 'package:flutter/services.dart';

import '../../settings/settings.dart';
import '../solve_controller.dart';

/// Gives light haptic feedback for what the player's last action did.
class MoveFeedback {
  MoveFeedback({required this.controller, required this.settings}) {
    _remember();
  }

  final SolveController controller;
  final Settings settings;

  int _seenCompleted = 0;
  int _seenMistakes = 0;
  int _seenMoves = 0;

  void _remember() {
    _seenMistakes = controller.mistakes;
    _seenCompleted = controller.completedSerial;
    _seenMoves = controller.moveCount;
  }

  /// Call after every change to the game. Returns true when the last action
  /// completed a row, column or box and the board should flash.
  bool react() {
    var flash = false;
    if (controller.mistakes > _seenMistakes) {
      settings.haptic(HapticFeedback.heavyImpact);
    } else if (controller.completedSerial != _seenCompleted) {
      settings.haptic(HapticFeedback.mediumImpact);
      flash = !controller.solved;
    } else if (controller.moveCount > _seenMoves) {
      settings.haptic(HapticFeedback.selectionClick);
    }
    _remember();
    return flash;
  }
}
