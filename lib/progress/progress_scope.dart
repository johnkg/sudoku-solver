import 'package:flutter/widgets.dart';

import 'progress_store.dart';

/// Makes the [ProgressStore] available to the whole app and rebuilds
/// dependents when it changes.
class ProgressScope extends InheritedNotifier<ProgressStore> {
  const ProgressScope({
    super.key,
    required ProgressStore store,
    required super.child,
  }) : super(notifier: store);

  /// The store, without rebuilding when it changes. Safe in `initState`.
  static ProgressStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'No ProgressScope above this widget');
    return scope!.notifier!;
  }

  /// The store, rebuilding the caller whenever it changes.
  static ProgressStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'No ProgressScope above this widget');
    return scope!.notifier!;
  }
}
