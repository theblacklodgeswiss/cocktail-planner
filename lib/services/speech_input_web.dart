import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'speech_input.dart';

/// Browser SpeechRecognition (standard or webkit-prefixed).
extension type _Recognition(JSObject _) implements JSObject {
  external set lang(String value);
  external set interimResults(bool value);
  external set continuous(bool value);
  external set onresult(JSFunction? value);
  external set onerror(JSFunction? value);
  external set onend(JSFunction? value);
  external void start();
  external void stop();
  external void abort();
}

extension type _ResultEvent(JSObject _) implements JSObject {
  external JSObject get results;
}

extension type _ErrorEvent(JSObject _) implements JSObject {
  external String? get error;
}

JSFunction? _constructor() {
  for (final name in const ['SpeechRecognition', 'webkitSpeechRecognition']) {
    final ctor = globalContext[name];
    if (ctor.isA<JSFunction>()) return ctor as JSFunction;
  }
  return null;
}

class _WebSpeechInput implements SpeechInput {
  _Recognition? _active;

  @override
  bool get supported => _constructor() != null;

  @override
  Stream<String> listen({String locale = 'de-DE'}) {
    final ctor = _constructor();
    if (ctor == null) {
      return Stream<String>.error(const SpeechInputException('unsupported'));
    }
    // Only one session at a time.
    _active?.abort();

    final controller = StreamController<String>();
    late final _Recognition recognition;
    try {
      recognition = _Recognition(ctor.callAsConstructor<JSObject>());
    } catch (_) {
      return Stream<String>.error(const SpeechInputException('unsupported'));
    }
    _active = recognition;

    void finish() {
      if (identical(_active, recognition)) _active = null;
      if (!controller.isClosed) controller.close();
    }

    recognition
      ..lang = locale
      ..interimResults = true
      ..continuous = false
      ..onresult = ((JSObject raw) {
        if (controller.isClosed) return;
        final results = _ResultEvent(raw).results;
        final length = (results['length'] as JSNumber).toDartInt;
        final buffer = StringBuffer();
        for (var i = 0; i < length; i++) {
          final result = results[i.toString()] as JSObject;
          final alt = result['0'] as JSObject;
          buffer.write((alt['transcript'] as JSString).toDart);
        }
        controller.add(buffer.toString().trim());
      }).toJS
      ..onerror = ((JSObject raw) {
        if (controller.isClosed) return;
        final code = _ErrorEvent(raw).error ?? 'unknown';
        final mapped = code == 'service-not-allowed' ? 'not-allowed' : code;
        controller.addError(SpeechInputException(mapped));
      }).toJS
      ..onend = ((JSObject _) => finish()).toJS;

    controller.onCancel = () {
      if (identical(_active, recognition)) _active = null;
      try {
        recognition.abort();
      } catch (_) {}
    };

    try {
      recognition.start();
    } catch (_) {
      controller.addError(const SpeechInputException('start-failed'));
      finish();
    }
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    final active = _active;
    if (active == null) return;
    try {
      active.stop();
    } catch (_) {}
  }
}

SpeechInput createPlatformSpeechInput() => _WebSpeechInput();
