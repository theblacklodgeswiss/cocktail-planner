import '../models/offer.dart';

/// DE <-> EN pairs for the standard offer position names. Custom names are
/// never touched: only exact matches (case-insensitive) are swapped.
const _namePairs = <(String de, String en)>[
  ('Cocktail- & Barservice', 'Cocktail & Bar Service'),
  ('Nur Cocktailservice', 'Cocktail Service only'),
  ('Nur Mocktailservice', 'Mocktail Service only'),
  ('Nur Barservice', 'Bar Service only'),
  ('Reisekosten', 'Travel Costs'),
  ('Extrastunden', 'Extra hours'),
  ('Theke', 'Bar Counter'),
  ('Bargetränke', 'Bar Drinks'),
];

String _translateName(String name, bool toEn) {
  final key = name.trim().toLowerCase();
  for (final (de, en) in _namePairs) {
    if (key == (toEn ? de : en).toLowerCase()) return toEn ? en : de;
  }
  return name;
}

String _translateRemark(String remark, bool toEn) {
  var r = remark;
  if (toEn) {
    r = r
        .replaceAllMapped(
          RegExp(r'^(\d+ \w+)/Barkeeper/Std\. extra$'),
          (m) => '${m[1]}/Barkeeper/h extra',
        )
        .replaceAllMapped(
          RegExp(r'^Reisekosten von Allschwil CH nach (.*)$'),
          (m) => 'Travel from Allschwil CH to ${m[1]}',
        )
        .replaceAll('Mobile Theke wird gestellt', 'Mobile bar counter provided')
        .replaceAll('Nach Verbrauch abgerechnet', 'Usage-based billing')
        .replaceAll('ausgeschenkt in 0.3L Hartplastikbechern',
            'served in 0.3L hard plastic cups')
        .replaceAll('Cocktail- & Barservice', 'Cocktail & Bar Service')
        .replaceAll('Nur Cocktailservice', 'Cocktail Service only')
        .replaceAll('Nur Mocktailservice', 'Mocktail Service only')
        .replaceAll('Nur Barservice', 'Bar Service only')
        .replaceAll('- Inkl. ', '- Incl. ')
        .replaceAllMapped(
          RegExp(r'^- (\d+) Barkeeper$', multiLine: true),
          (m) => '- ${m[1]} Barkeepers',
        );
  } else {
    r = r
        .replaceAllMapped(
          RegExp(r'^(\d+ \w+)/Barkeeper/h extra$'),
          (m) => '${m[1]}/Barkeeper/Std. extra',
        )
        .replaceAllMapped(
          RegExp(r'^Travel from Allschwil CH to (.*)$'),
          (m) => 'Reisekosten von Allschwil CH nach ${m[1]}',
        )
        .replaceAll('Mobile bar counter provided', 'Mobile Theke wird gestellt')
        .replaceAll('Usage-based billing', 'Nach Verbrauch abgerechnet')
        .replaceAll('served in 0.3L hard plastic cups',
            'ausgeschenkt in 0.3L Hartplastikbechern')
        .replaceAll('Cocktail & Bar Service', 'Cocktail- & Barservice')
        .replaceAll('Cocktail Service only', 'Nur Cocktailservice')
        .replaceAll('Mocktail Service only', 'Nur Mocktailservice')
        .replaceAll('Bar Service only', 'Nur Barservice')
        .replaceAll('- Incl. ', '- Inkl. ')
        .replaceAllMapped(
          RegExp(r'^- (\d+) Barkeepers$', multiLine: true),
          (m) => '- ${m[1]} Barkeeper',
        );
  }
  return r;
}

/// Returns [position] with its standard name/remark texts switched to the
/// target language; anything custom stays as typed.
ExtraPosition translateStandardPosition(ExtraPosition position, String lang) {
  final toEn = lang == 'en';
  return ExtraPosition(
    name: _translateName(position.name, toEn),
    price: position.price,
    quantity: position.quantity,
    remark: _translateRemark(position.remark, toEn),
    date: position.date,
  );
}
