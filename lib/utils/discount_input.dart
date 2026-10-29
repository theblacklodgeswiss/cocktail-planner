/// Parses the discount field ("10", "7,5", "12.50"); null when it is not a
/// number.
double? parseDiscountInput(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Translation key of the discount field's error, or null (empty is fine):
/// not a number / negative, or more than 100 % in percent mode.
String? discountInputErrorKey(String? value, {required bool isPercent}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = parseDiscountInput(text);
  if (parsed == null || parsed < 0) return 'offer.invalid_number';
  if (isPercent && parsed > 100) return 'discount.percent_too_high';
  return null;
}
