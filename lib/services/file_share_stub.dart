import 'dart:typed_data';

import 'file_share.dart';

/// Non-web implementation: no Web Share API.
bool canShareFiles(String mimeType) => false;

Future<FileShareResult> shareFile(
  Uint8List bytes,
  String filename,
  String mimeType,
) async => FileShareResult.unsupported;
