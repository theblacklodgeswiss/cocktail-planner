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
  bool _stopRequested = false;

  @override
  bool get supported => _constructor() != null;

  /// Keeps listening until [stop] is called: browsers end a session after a
  /// pause (or a few seconds on iOS), so a new session starts right away and
  /// the transcripts of finished sessions are kept in front of the live one.
  @override
  Stream<String> listen({String locale = 'de-DE'}) {
    final ctor = _constructor();
    if (ctor == null) {
      return Stream<String>.error(const SpeechInputException('unsupported'));
    }
    // Only one session at a time.
    _active?.abort();
    _stopRequested = false;

    final controller = StreamController<String>();
    var committed = '';
    var current = '';
    var restarts = 0;

    void emit() {
      if (controller.isClosed) return;
      controller.add([committed, current].where((t) => t.isNotEmpty).join(' '));
    }

    void finish() {
      _active = null;
      if (!controller.isClosed) controller.close();
    }

    void begin() {
      final _Recognition recognition;
      try {
        recognition = _Recognition(ctor.callAsConstructor<JSObject>());
      } catch (_) {
        if (!controller.isClosed) {
          controller.addError(const SpeechInputException('unsupported'));
          finish();
        }
        return;
      }
      _active = recognition;
      var failed = false;
      current = '';

      recognition
        ..lang = locale
        ..interimResults = true
        ..continuous = true
        ..onresult = ((JSObject raw) {
          if (controller.isClosed || !identical(_active, recognition)) return;
          final results = _ResultEvent(raw).results;
          final length = (results['length'] as JSNumber).toDartInt;
          final parts = <String>[];
          for (var i = 0; i < length; i++) {
            final result = results[i.toString()] as JSObject;
            final alt = result['0'] as JSObject;
            parts.add((alt['transcript'] as JSString).toDart);
          }
          current = mergeTranscripts(parts);
          restarts = 0;
          emit();
        }).toJS
        ..onerror = ((JSObject raw) {
          if (controller.isClosed || !identical(_active, recognition)) return;
          final code = _ErrorEvent(raw).error ?? 'unknown';
          // Silence or a browser-side abort just ends this session; the
          // restart below continues. Anything else is a real failure.
          if (code == 'no-speech' || code == 'aborted') return;
          failed = true;
          // A refused restart (no user gesture) keeps what was heard.
          if (restarts > 0 && committed.isNotEmpty) return;
          final mapped = code == 'service-not-allowed' ? 'not-allowed' : code;
          controller.addError(SpeechInputException(mapped));
        }).toJS
        ..onend = ((JSObject _) {
          if (!identical(_active, recognition)) return;
          committed = [committed, current].where((t) => t.isNotEmpty).join(' ');
          current = '';
          // Restart unless the user stopped, an error ended it, or sessions
          // keep ending without any speech.
          if (_stopRequested ||
              failed ||
              controller.isClosed ||
              restarts >= 3) {
            finish();
            return;
          }
          restarts++;
          begin();
        }).toJS;

      try {
        recognition.start();
      } catch (_) {
        if (restarts == 0 || committed.isEmpty) {
          controller.addError(const SpeechInputException('start-failed'));
        }
        finish();
      }
    }

    controller.onCancel = () {
      _stopRequested = true;
      final active = _active;
      _active = null;
      try {
        active?.abort();
      } catch (_) {}
    };

    begin();
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    _stopRequested = true;
    final active = _active;
    if (active == null) return;
    try {
      active.stop();
    } catch (_) {}
  }
}

SpeechInput createPlatformSpeechInput() => _WebSpeechInput();
