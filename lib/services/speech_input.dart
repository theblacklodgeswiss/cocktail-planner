import 'speech_input_stub.dart'
    if (dart.library.js_interop) 'speech_input_web.dart'
    as impl;

/// Error raised through the [SpeechInput.listen] stream.
///
/// [code] is 'unsupported' (no speech recognition in this browser),
/// 'not-allowed' (microphone denied) or the browser's own error string
/// (e.g. 'no-speech', 'audio-capture', 'network').
class SpeechInputException implements Exception {
  final String code;

  const SpeechInputException(this.code);

  @override
  String toString() => 'SpeechInputException($code)';

  @override
  bool operator ==(Object other) =>
      other is SpeechInputException && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Speech-to-text input. Text input is the fallback when unsupported.
abstract class SpeechInput {
  /// Whether this platform/browser offers speech recognition.
  bool get supported;

  /// Starts recognition and emits the transcript so far (interim results
  /// included). The stream closes when recognition ends; failures arrive as
  /// [SpeechInputException] errors.
  Stream<String> listen({String locale = 'de-DE'});

  /// Stops recognition. Safe to call when not listening.
  Future<void> stop();
}

/// Creates the speech input implementation for the current platform.
SpeechInput createSpeechInput() => impl.createPlatformSpeechInput();
