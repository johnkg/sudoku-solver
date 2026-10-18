import 'dart:ui' show VoidCallback;

/// What reading a photo of a puzzle produced.
class ScanResult {
  const ScanResult(this.text, this.uncertain);

  /// 81 characters, `0` for blanks.
  final String text;

  /// Cells whose digit the reader was unsure of or could not make out.
  final Set<int> uncertain;
}

/// The photo could not be read. [message] is fit to show the player.
class ScanFailure implements Exception {
  const ScanFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Asks for a photo and reads it. Calls [onPicked] once a photo is chosen,
/// before the slow part, and returns null if nothing was chosen.
typedef PhotoScanner = Future<ScanResult?> Function(VoidCallback onPicked);
