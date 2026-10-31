import 'package:flutter/material.dart';

import '../digit_keys.dart';
import '../layout.dart';

/// Everything under the grid on the Solver tab: a status line, the digit
/// keys, and buttons to edit the grid, share it, and start solving it.
class PuzzleEntryControls extends StatelessWidget {
  const PuzzleEntryControls({
    super.key,
    required this.status,
    required this.statusIsError,
    required this.hasSelection,
    required this.hasDigits,
    required this.canCopyLink,
    required this.canScan,
    required this.onDigit,
    required this.onPaste,
    required this.onClear,
    required this.onScan,
    required this.onCopyLink,
    required this.onTeach,
    required this.onPlay,
  });

  final String status;
  final bool statusIsError;
  final bool hasSelection;
  final bool hasDigits;
  final bool canCopyLink;
  final bool canScan;

  /// Called with 0 to erase the selected cell.
  final ValueChanged<int> onDigit;
  final VoidCallback onPaste;
  final VoidCallback onClear;
  final VoidCallback onScan;
  final VoidCallback onCopyLink;
  final VoidCallback onTeach;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          status,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: statusIsError ? theme.colorScheme.error : null,
          ),
        ),
        const SizedBox(height: Space.md),
        DigitKeyRow(
          keyPrefix: 'entry-',
          onDigit: hasSelection ? onDigit : null,
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('erase-entry'),
                onPressed: hasSelection ? () => onDigit(0) : null,
                icon: const Icon(Icons.backspace_outlined),
                label: const Text('Erase'),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('import'),
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('clear-grid'),
                onPressed: hasDigits ? onClear : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
        if (canScan) ...[
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            key: const Key('scan-photo'),
            onPressed: onScan,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Scan from a photo'),
          ),
        ],
        const SizedBox(height: Space.sm),
        OutlinedButton.icon(
          key: const Key('copy-link'),
          onPressed: canCopyLink ? onCopyLink : null,
          icon: const Icon(Icons.link),
          label: const Text('Copy a link to this puzzle'),
        ),
        const SizedBox(height: Space.md),
        FilledButton.icon(
          key: const Key('teach-me'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, largeButtonHeight),
          ),
          onPressed: onTeach,
          icon: const Icon(Icons.school),
          label: const Text('Teach me how to solve it'),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton.icon(
          key: const Key('play-it'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, largeButtonHeight),
          ),
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play this puzzle myself'),
        ),
      ],
    );
  }
}
