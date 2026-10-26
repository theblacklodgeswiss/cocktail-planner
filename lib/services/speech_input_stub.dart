import 'speech_input.dart';

/// Non-web implementation: speech recognition is not available.
class _StubSpeechInput implements SpeechInput {
  @override
  bool get supported => false;

  @override
  Stream<String> listen({String locale = 'de-DE'}) =>
      Stream<String>.error(const SpeechInputException('unsupported'));

  @override
  Future<void> stop() async {}
}

SpeechInput createPlatformSpeechInput() => _StubSpeechInput();
