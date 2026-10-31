import 'package:flutter/material.dart';

import '../layout.dart';

/// Switches between watching the solver and finding its moves yourself.
class WalkthroughModeToggle extends StatelessWidget {
  const WalkthroughModeToggle({
    super.key,
    required this.play,
    required this.onChanged,
  });

  final bool play;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Watch', key: Key('mode-watch')),
          icon: Icon(Icons.visibility_outlined),
        ),
        ButtonSegment(
          value: true,
          label: Text('Your turn', key: Key('mode-play')),
          icon: Icon(Icons.touch_app_outlined),
        ),
      ],
      selected: {play},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Back and next buttons, with a slider to jump to any step.
class WalkthroughControls extends StatelessWidget {
  const WalkthroughControls({
    super.key,
    required this.index,
    required this.last,
    required this.canAdvance,
    required this.showSlider,
    required this.onChanged,
  });

  /// The step shown, from 0 to [last]. [last] is the end, after every step.
  final int index;
  final int last;

  /// False while the player still has to find the move.
  final bool canAdvance;
  final bool showSlider;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (last > 1 && showSlider)
          Slider(
            value: index.toDouble(),
            max: last.toDouble(),
            divisions: last,
            label: index == last ? 'Done' : 'Step ${index + 1}',
            onChanged: (v) => onChanged(v.round()),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('prev-step'),
                onPressed: index == 0 ? null : () => onChanged(index - 1),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: FilledButton.icon(
                key: const Key('next-step'),
                onPressed: index == last || !canAdvance
                    ? null
                    : () => onChanged(index + 1),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
