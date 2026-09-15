import '../models/additional_service.dart';
import 'currency.dart';

String _resolveOrderOptionLabel(
  String value,
  Map<String, String> germanLabels,
  Map<String, String> englishLabels, {
  required bool isEnglish,
}) {
  final labels = isEnglish ? englishLabels : germanLabels;
  return labels[value] ?? value;
}

const Map<String, String> _barDrinkLabelsDe = {
  'whiskey_mix': 'Whiskey & Mischgetränke',
  'vodka_mix': 'Vodka & Mischgetränke',
  'gin_mix': 'Gin & Mischgetränke',
  'shots': 'Shots',
  'other': 'Sonstiges',
};

const Map<String, String> _barDrinkLabelsEn = {
  'whiskey_mix': 'Whiskey & mixed drinks',
  'vodka_mix': 'Vodka & mixed drinks',
  'gin_mix': 'Gin & mixed drinks',
  'shots': 'Shots',
  'other': 'Other',
};

const Map<String, String> _alcoholLabelsDe = {
  'whiskey_chivas': 'Whiskey Chivas 0.7L - 35,-',
  'whiskey_black_label': 'Whiskey Black Label 0.7L - 35,-',
  'vodka_absolut': 'Vodka Absolut 0.7L - 25,-',
  'vodka_three_sixty': 'Vodka Three Sixty 0.7L - 25,-',
  'vodka_ciroc': 'Vodka Ciroc 0.7L - 40,-',
  'vodka_belvedere': 'Vodka Belvedere 0.7L - 45,-',
  'vodka_grey_goose': 'Vodka Grey Goose 0.7L - 45,-',
  'gin_bombay': 'Gin Bombay Sapphire 0.7L - 25,-',
  'gin_bulldog': 'Gin Bulldog 0.7L - 35,-',
};

const Map<String, String> _alcoholLabelsEn = {
  'whiskey_chivas': 'Whiskey Chivas 0.7L - 35,-',
  'whiskey_black_label': 'Whiskey Black Label 0.7L - 35,-',
  'vodka_absolut': 'Vodka Absolut 0.7L - 25,-',
  'vodka_three_sixty': 'Vodka Three Sixty 0.7L - 25,-',
  'vodka_ciroc': 'Vodka Ciroc 0.7L - 40,-',
  'vodka_belvedere': 'Vodka Belvedere 0.7L - 45,-',
  'vodka_grey_goose': 'Vodka Grey Goose 0.7L - 45,-',
  'gin_bombay': 'Gin Bombay Sapphire 0.7L - 25,-',
  'gin_bulldog': 'Gin Bulldog 0.7L - 35,-',
};

const Map<String, String> _additionalServiceLabelsDe = {
  'booth_360': 'BlackLodge - 360 Booth (600 {currency})',
  'photobox_print': 'BlackLodge - PhotoBox inkl. 300 Druck (500 {currency})',
  'photobox_qr': 'BlackLodge - PhotoBox Digital mit QR Code (300 {currency})',
  'bubble_waffles': 'BlackLodge - Bubble Waffles (250 {currency})',
  'catering': 'BlackLodge - Catering (Preis auf Anfrage)',
  'choreographer': 'Nirosi Singh - Choreographer (Preis auf Anfrage)',
  'dj': 'Extern - DJs (Preis auf Anfrage)',
  'led_screen': 'Extern - LED Screen (Preis auf Anfrage)',
  'security': 'Mudanca Security (min. 2 Securitys á 40 {currency}/H)',
  'entry_song': 'Entry Song mit Geige - Praveen (300 {currency})',
  'other_services': 'Sonstiges',
};

const Map<String, String> _additionalServiceLabelsEn = {
  'booth_360': 'BlackLodge - 360 Booth (600 {currency})',
  'photobox_print': 'BlackLodge - PhotoBox incl. 300 prints (500 {currency})',
  'photobox_qr': 'BlackLodge - PhotoBox digital with QR code (300 {currency})',
  'bubble_waffles': 'BlackLodge - Bubble Waffles (250 {currency})',
  'catering': 'BlackLodge - Catering (price on request)',
  'choreographer': 'Nirosi Singh - Choreographer (price on request)',
  'dj': 'External - DJs (price on request)',
  'led_screen': 'External - LED screen (price on request)',
  'security': 'Mudanca Security (min. 2 security staff at 40 {currency}/h)',
  'entry_song': 'Entry song with violin - Praveen (300 {currency})',
  'other_services': 'Other',
};

String _injectCurrency(String label, String currencyCode) {
  return label.replaceAll('{currency}', currencyCode);
}

String formatOrderBarDrinkLabel(String value, {bool isEnglish = false}) {
  return _resolveOrderOptionLabel(
    value,
    _barDrinkLabelsDe,
    _barDrinkLabelsEn,
    isEnglish: isEnglish,
  );
}

List<String> formatOrderBarDrinkLabels(
  Iterable<String> values, {
  bool isEnglish = false,
}) {
  return values
      .map((value) => formatOrderBarDrinkLabel(value, isEnglish: isEnglish))
      .toList(growable: false);
}

String formatOrderAlcoholLabel(String value, {bool isEnglish = false}) {
  return _resolveOrderOptionLabel(
    value,
    _alcoholLabelsDe,
    _alcoholLabelsEn,
    isEnglish: isEnglish,
  );
}

List<String> formatOrderAlcoholLabels(
  Iterable<String> values, {
  bool isEnglish = false,
}) {
  return values
      .map((value) => formatOrderAlcoholLabel(value, isEnglish: isEnglish))
      .toList(growable: false);
}

String formatOrderAdditionalServiceLabel(
  String value, {
  bool isEnglish = false,
  String? currencyCode,
}) {
  final effectiveCurrencyCode = currencyCode ?? defaultCurrency.code;
  final label = _resolveOrderOptionLabel(
    value,
    _additionalServiceLabelsDe,
    _additionalServiceLabelsEn,
    isEnglish: isEnglish,
  );
  return _injectCurrency(label, effectiveCurrencyCode);
}

List<String> formatOrderAdditionalServiceLabels(
  Iterable<String> values, {
  bool isEnglish = false,
  String? currencyCode,
}) {
  return values
      .map(
        (value) => formatOrderAdditionalServiceLabel(
          value,
          isEnglish: isEnglish,
          currencyCode: currencyCode,
        ),
      )
      .toList(growable: false);
}

/// Resolves an `order.additionalServices` entry's display label,
/// backward-compatibly.
///
/// New-style entries are composite `"serviceId:variantId"` strings produced
/// by the customer-facing tile grid (see
/// `modern_order_form_screen.dart`): if [value] contains `':'`, this looks
/// up the service and variant in [catalog] and returns
/// `"${service.name} - ${variant.name} (...)"`, mirroring the visual format
/// of the legacy static map.
///
/// Legacy flat IDs (`'booth_360'`, `'dj'`, ...) - and any composite ID whose
/// service/variant was since deleted from the catalog - fall back to the
/// existing [formatOrderAdditionalServiceLabel], unchanged, so every value
/// already stored on an order keeps resolving exactly as it does today.
String resolveAdditionalServiceLabel(
  String value, {
  required List<AdditionalService> catalog,
  bool isEnglish = false,
  String? currencyCode,
}) {
  final separatorIndex = value.indexOf(':');
  if (separatorIndex > 0) {
    final serviceId = value.substring(0, separatorIndex);
    final variantId = value.substring(separatorIndex + 1);
    for (final service in catalog) {
      if (service.id != serviceId) continue;
      final variant = service.variantById(variantId);
      if (variant == null) break;
      final priceLabel = variant.price != null
          ? '${variant.price!.toStringAsFixed(0)} ${currencyCode ?? defaultCurrency.code}'
          : (isEnglish ? 'price on request' : 'Preis auf Anfrage');
      return '${service.name} - ${variant.name} ($priceLabel)';
    }
  }
  return formatOrderAdditionalServiceLabel(
    value,
    isEnglish: isEnglish,
    currencyCode: currencyCode,
  );
}

/// Resolves the price to seed on an auto-generated offer position for an
/// `order.additionalServices` entry: the matching catalog variant's price
/// when [value] is a resolvable composite `"serviceId:variantId"` string,
/// otherwise `null` (legacy bare IDs and unresolved/"Preis auf Anfrage"
/// variants have no price to seed - callers keep defaulting to `0`).
double? resolveAdditionalServicePrice(
  String value, {
  required List<AdditionalService> catalog,
}) {
  final separatorIndex = value.indexOf(':');
  if (separatorIndex <= 0) return null;
  final serviceId = value.substring(0, separatorIndex);
  final variantId = value.substring(separatorIndex + 1);
  for (final service in catalog) {
    if (service.id != serviceId) continue;
    return service.variantById(variantId)?.price;
  }
  return null;
}

bool isUsageBasedAlcoholOption(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('chivas') ||
      normalized.contains('vodka') ||
      normalized.contains('wodka');
}
