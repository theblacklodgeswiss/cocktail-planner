import 'package:cocktail_planer/services/speech_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('segments are joined with spaces', () {
    expect(
      mergeTranscripts(['drei Bacardi', 'fünf Rum']),
      'drei Bacardi fünf Rum',
    );
  });

  test('cumulative results replace instead of repeating', () {
    expect(
      mergeTranscripts(['drei', 'drei Bacardi', 'drei Bacardi ziehen']),
      'drei Bacardi ziehen',
    );
  });

  test('a repeated tail is skipped, empty parts ignored', () {
    expect(mergeTranscripts(['', 'drei Bacardi', 'Bacardi']), 'drei Bacardi');
  });
}
