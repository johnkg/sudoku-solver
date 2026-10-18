import 'dart:ui' show VoidCallback;

import 'scan_result.dart';

/// Reading photos needs the browser, so only the web build offers it.
const photoScanSupported = false;

Future<ScanResult?> scanPuzzlePhoto(VoidCallback onPicked) async => null;
