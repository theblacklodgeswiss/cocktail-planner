import 'package:cocktail_planer/services/speech_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stub is unsupported and listen fails with unsupported', () async {
    final input = createSpeechInput();
    expect(input.supported, isFalse);
    await expectLater(
      input.listen(),
      emitsError(const SpeechInputException('unsupported')),
    );
  });

  test('stop is safe when not listening', () async {
    await createSpeechInput().stop();
  });
}
