import 'dart:typed_data';

import 'file_share_stub.dart'
    if (dart.library.js_interop) 'file_share_web.dart'
    as impl;

/// Outcome of [shareFile].
enum FileShareResult {
  /// The system share sheet was shown and the user picked a target.
  shared,

  /// The user closed the share sheet.
  cancelled,

  /// The browser refused because the tap was too long ago (Safari needs the
  /// share call right after a tap); tapping again works.
  needsGesture,

  /// This platform/browser cannot share files.
  unsupported,

  /// Any other failure.
  failed,
}

/// Whether the system share sheet can share a file of [mimeType] here
/// (Web Share API level 2; iOS/Android browsers, not most desktops).
bool canShareFiles({String mimeType = 'application/pdf'}) =>
    impl.canShareFiles(mimeType);

/// Opens the system share sheet with one file (e.g. to send a PDF via
/// WhatsApp). Call it straight from a tap handler: Safari rejects a share
/// that is not triggered by a recent user gesture.
Future<FileShareResult> shareFile({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'application/pdf',
}) => impl.shareFile(bytes, filename, mimeType);
