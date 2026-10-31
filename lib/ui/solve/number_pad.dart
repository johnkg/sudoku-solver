import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import '../../engine/engine.dart';
import '../../settings/settings.dart';
import '../layout.dart';
import '../solve_controller.dart';

/// A single row of big digits. A digit that is already placed nine times is
/// dimmed.
class NumberPad extends StatelessWidget {
  const NumberPad({super.key, required this.controller});

  final SolveController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.solved) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final values = controller.board.values;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
      child: Row(
        children: [
          for (var digit = 1; digit <= maxDigit; digit++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final done =
                      values.where((v) => v == digit).length >= Board.size;
                  return InkWell(
                    key: Key('digit-$digit'),
                    borderRadius: BorderRadius.circular(keyRadius),
                    onTap: done
                        ? null
                        : () => controller.armed == null
                              ? controller.enter(digit)
                              : controller.toggleArmed(digit),
                    onLongPress: done
                        ? null
                        : () {
                            SettingsScope.read(context)
                                .haptic(HapticFeedback.selectionClick);
                            controller.toggleArmed(digit);
                          },
                    child: Container(
                      margin: const EdgeInsets.all(Space.hair),
                      decoration: BoxDecoration(
                        color: controller.armed == digit
                            ? scheme.primary
                            : scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(keyRadius),
                        border: Border.all(
                          color: controller.armed == digit
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: Space.snug),
                      child: Text(
                        '$digit',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: done
                              ? scheme.onSurface.withValues(
                                  alpha: usedUpOpacity,
                                )
                              : controller.armed == digit
                              ? scheme.onPrimary
                              : scheme.primary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
