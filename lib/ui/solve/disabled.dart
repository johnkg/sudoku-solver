import 'package:flutter/material.dart' hide Step;

import '../layout.dart';

/// Greys out and blocks [child] while [disabled].
class Disabled extends StatelessWidget {
  const Disabled({super.key, required this.disabled, required this.child});

  final bool disabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: disabled,
    child: Opacity(opacity: disabled ? disabledOpacity : 1, child: child),
  );
}
