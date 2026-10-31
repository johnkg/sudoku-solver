import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout.dart';
import 'puzzle_text.dart';

/// Asks for the 81 characters of a puzzle. Pops with the text once it parses
/// as a puzzle.
class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final controller = TextEditingController();
  bool bad = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (parsePuzzleText(controller.text) == null) {
      setState(() => bad = true);
    } else {
      Navigator.pop(context, controller.text);
    }
  }

  Future<void> _useClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    controller.text = data!.text!;
    setState(() => bad = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste a puzzle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste the 81 characters of a puzzle, row by row. Use 0 or . for '
            'blanks.',
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('import-field'),
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: bad ? 'That is not 81 digits and blanks.' : null,
            ),
            onChanged: (_) {
              if (bad) setState(() => bad = false);
            },
          ),
          TextButton.icon(
            onPressed: _useClipboard,
            icon: const Icon(Icons.content_paste_go),
            label: const Text('Use clipboard'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('import-confirm'),
          onPressed: _submit,
          child: const Text('Use puzzle'),
        ),
      ],
    );
  }
}
