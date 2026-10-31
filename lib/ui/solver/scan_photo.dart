import 'package:flutter/material.dart';

import '../../scan/scan_result.dart';
import '../layout.dart';

/// Reads a puzzle from a photo with [scanner], showing a progress dialog
/// while the photo is read. Returns null if the player gave up on choosing a
/// photo. Throws [ScanFailure] if the photo could not be read.
Future<ScanResult?> scanPhotoWithDialog(
  BuildContext context,
  PhotoScanner scanner,
) async {
  final navigator = Navigator.of(context);
  var dialogShown = false;
  try {
    return await scanner(() {
      dialogShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: Space.roomy),
                Expanded(child: Text('Reading the photo…')),
              ],
            ),
          ),
        ),
      );
    });
  } finally {
    if (dialogShown) navigator.pop();
  }
}
