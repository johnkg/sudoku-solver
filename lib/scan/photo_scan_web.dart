import 'dart:js_interop';
import 'dart:ui' show VoidCallback;

import 'scan_result.dart';

/// The web build reads photos with `web/scan/scan.js`.
const photoScanSupported = true;

@JS('sudokuScan.pickFile')
external JSPromise<JSObject?> _pickFile();

@JS('sudokuScan.readFile')
external JSPromise<_JsScan> _readFile(JSObject file);

extension type _JsScan._(JSObject _) implements JSObject {
  external String get text;
  external JSArray<JSNumber> get uncertain;
}

Future<ScanResult?> scanPuzzlePhoto(VoidCallback onPicked) async {
  try {
    final file = await _pickFile().toDart;
    if (file == null) return null;
    onPicked();
    final scan = await _readFile(file).toDart;
    return ScanResult(scan.text, {
      for (final n in scan.uncertain.toDart) n.toDartInt,
    });
  } catch (e) {
    final text = '$e';
    final known = RegExp(r'I could not [^.]*\.').firstMatch(text);
    throw ScanFailure(
      known?.group(0) ??
          'I could not read that photo. Try a sharper, well-lit picture with '
              'the whole grid in view.',
    );
  }
}
