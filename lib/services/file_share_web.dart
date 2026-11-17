import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'file_share.dart';

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator(JSObject _) implements JSObject {
  external bool canShare(_ShareData data);
  external JSPromise<JSAny?> share(_ShareData data);
}

@JS('File')
extension type _File._(JSObject _) implements JSObject {
  external factory _File(
    JSArray<JSAny> parts,
    String name,
    _FileOptions options,
  );
}

extension type _FileOptions._(JSObject _) implements JSObject {
  external factory _FileOptions({required String type});
}

extension type _ShareData._(JSObject _) implements JSObject {
  external factory _ShareData({required JSArray<JSAny> files});
}

bool _hasApi() {
  final nav = globalContext['navigator'];
  if (nav == null || !nav.isA<JSObject>()) return false;
  final n = nav as JSObject;
  return n.has('share') && n.has('canShare');
}

_ShareData _data(Uint8List bytes, String filename, String mimeType) {
  final file = _File(
    <JSAny>[bytes.toJS].toJS,
    filename,
    _FileOptions(type: mimeType),
  );
  return _ShareData(files: <JSAny>[file].toJS);
}

bool canShareFiles(String mimeType) {
  if (!_hasApi()) return false;
  try {
    return _navigator.canShare(_data(Uint8List(1), 'probe.pdf', mimeType));
  } catch (_) {
    return false;
  }
}

Future<FileShareResult> shareFile(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  if (!_hasApi()) return FileShareResult.unsupported;
  final data = _data(bytes, filename, mimeType);
  try {
    if (!_navigator.canShare(data)) return FileShareResult.unsupported;
    await _navigator.share(data).toDart;
    return FileShareResult.shared;
  } catch (e) {
    final s = e.toString();
    if (s.contains('AbortError')) return FileShareResult.cancelled;
    if (s.contains('NotAllowedError')) return FileShareResult.needsGesture;
    return FileShareResult.failed;
  }
}
