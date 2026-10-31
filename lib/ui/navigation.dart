import 'package:flutter/material.dart';

/// Opens [builder]'s screen on top of the current one.
Future<void> pushScreen(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

/// Opens [builder]'s screen on [navigator], or swaps the current screen for
/// it with [replace]. Takes a navigator rather than a context so it can be
/// called after an `await`.
void openScreen(
  NavigatorState navigator,
  WidgetBuilder builder, {
  bool replace = false,
}) {
  final route = MaterialPageRoute<void>(builder: builder);
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
}
