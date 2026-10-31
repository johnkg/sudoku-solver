import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/engine.dart';
import 'layout.dart';

/// A row of the digit buttons 1 to 9. Each button's key is
/// `Key('$keyPrefix$digit')`. They are disabled while [onDigit] is null.
class DigitKeyRow extends StatelessWidget {
  const DigitKeyRow({
    super.key,
    required this.keyPrefix,
    required this.onDigit,
  });

  final String keyPrefix;
  final ValueChanged<int>? onDigit;

  @override
  Widget build(BuildContext context) {
    final onDigit = this.onDigit;
    return Row(
      children: [
        for (var digit = 1; digit <= maxDigit; digit++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.hair),
              child: FilledButton.tonal(
                key: Key('$keyPrefix$digit'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, minTapHeight),
                ),
                onPressed: onDigit == null ? null : () => onDigit(digit),
                child: Text(
                  '$digit',
                  style: const TextStyle(fontSize: keypadFontSize),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The digit 1 to 9 typed by [key], or null for any other key.
int? digitOfKey(LogicalKeyboardKey key) {
  final digit = int.tryParse(key.keyLabel);
  return digit != null && digit >= 1 && digit <= maxDigit ? digit : null;
}
