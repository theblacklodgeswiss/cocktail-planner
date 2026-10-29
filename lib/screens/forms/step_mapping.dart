/// Step structure of the order wizard and the translation of old `?step=n`
/// links (nine steps before the redesign) to the current five steps.
library;

/// Number of wizard steps.
///
/// | new | content                                                     |
/// |-----|-------------------------------------------------------------|
/// | 0   | Anlass und Art: service type, event type, drinker type      |
/// | 1   | Termin/Ort/Gäste: date, time, address, distance, guests,    |
/// |     | currency                                                    |
/// | 2   | Kontakt: name, phone, remarks                               |
/// | 3   | Getränke: cocktails/shots, popularity (optional, collapsed),|
/// |     | bar drinks and alcohol purchase                             |
/// | 4   | Zusatzleistungen und Übersicht: additional services,        |
/// |     | summary, submit                                             |
const int kFormSteps = 5;

/// Old (nine-step) index -> new (five-step) index.
///
/// | old | old content                                   | new |
/// |-----|-----------------------------------------------|-----|
/// | 0   | service type                                  | 0   |
/// | 1   | contact (name, phone)                         | 2   |
/// | 2   | event (date, time, address)                   | 1   |
/// | 3   | preferences (guests, distance, currency,      | 0   |
/// |     | drinker type, event type)                     |     |
/// | 4   | bar drinks and alcohol purchase               | 3   |
/// | 5   | cocktails and shots                           | 3   |
/// | 6   | popularity                                    | 3   |
/// | 7   | additional services and remarks               | 4   |
/// | 8   | overview                                      | 4   |
///
/// Old step 3 was split; it maps to new step 0 because that is where its
/// only required field (the event type) lives now. Throws a [RangeError]
/// for indices outside 0..8.
int mapLegacyStep(int oldIndex) {
  const table = [0, 2, 1, 0, 3, 3, 3, 4, 4];
  RangeError.checkValueInInterval(oldIndex, 0, table.length - 1, 'oldIndex');
  return table[oldIndex];
}

/// Reads a `?step=` value: 0..4 are new indices, 5..8 can only be old ones
/// and go through [mapLegacyStep]; anything else (missing, not a number,
/// out of range) is null.
///
/// Accepted ambiguity: an old bookmark with 0..4 cannot be told apart from a
/// new link and is read as a new index (e.g. old `?step=1`, contact, now
/// opens step 1, date and place). Links stay simple, without a version flag.
int? resolveStepParam(String? raw) {
  final value = raw == null ? null : int.tryParse(raw);
  if (value == null || value < 0) return null;
  if (value < kFormSteps) return value;
  if (value <= 8) return mapLegacyStep(value);
  return null;
}
