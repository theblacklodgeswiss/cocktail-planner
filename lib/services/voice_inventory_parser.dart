import '../models/material_item.dart';
import '../models/stock.dart';

/// One spoken stock line, e.g. "bei Mario 3 Sprite".
class ParsedLine {
  const ParsedLine({
    required this.quantity,
    required this.spokenName,
    this.locationHint,
    this.originHint,
  });

  final double quantity;
  final String spokenName;
  final String? locationHint;
  final StockOrigin? originHint;
}

class CatalogMatch {
  const CatalogMatch({
    required this.materialId,
    required this.name,
    required this.score,
  });

  final String materialId;
  final String name;
  final double score;
}

const _numberWords = <String, double>{
  'null': 0,
  'ein': 1,
  'eine': 1,
  'einen': 1,
  'eins': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fünf': 5,
  'fuenf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'elf': 11,
  'zwölf': 12,
  'zwoelf': 12,
  'dreizehn': 13,
  'vierzehn': 14,
  'fünfzehn': 15,
  'fuenfzehn': 15,
  'sechzehn': 16,
  'siebzehn': 17,
  'achtzehn': 18,
  'neunzehn': 19,
  'zwanzig': 20,
  'halbe': 0.5,
  'halben': 0.5,
  'halb': 0.5,
  'anderthalb': 1.5,
};

/// Words that sit between the number and the name but are not the name.
const _fillerWords = {'flasche', 'flaschen', 'x', 'mal', 'stück', 'stueck'};

// Split on , ; newline and "und", but not on a decimal comma ("2,8").
final _separator = RegExp(
  r'(?<!\d),|,(?!\d)|;|\n|\bund\b',
  caseSensitive: false,
);

final _plainNumber = RegExp(r'^\d+([.,]\d+)?$');

double? _parseNumber(String token) {
  final lower = token.toLowerCase();
  final word = _numberWords[lower];
  if (word != null) return word;
  // Plain non-negative decimals only: no sign, exponent, NaN or Infinity.
  if (!_plainNumber.hasMatch(lower)) return null;
  return double.tryParse(lower.replaceAll(',', '.'));
}

/// Parses speech-recognition output into stock lines. Fragments without a
/// quantity or without a name are skipped instead of guessed.
List<ParsedLine> parseRestText(String text) {
  final result = <ParsedLine>[];
  for (final fragment in text.split(_separator)) {
    final line = _parseFragment(fragment);
    if (line != null) result.add(line);
  }
  return result;
}

ParsedLine? _parseFragment(String fragment) {
  var tokens = fragment
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  String? location;
  if (tokens.length >= 2 && tokens.first.toLowerCase() == 'bei') {
    location = tokens[1];
    tokens = tokens.sublist(2);
  }

  StockOrigin? origin;
  if (tokens.any((t) => t.toLowerCase() == 'investition')) {
    origin = StockOrigin.investment;
    tokens = tokens.where((t) => t.toLowerCase() != 'investition').toList();
  }

  if (tokens.isEmpty) return null;
  var quantity = _parseNumber(tokens.first);
  if (quantity == null) return null;
  var i = 1;

  // "zwei Komma acht": digits after "Komma" are the decimal places.
  if (i + 1 < tokens.length && tokens[i].toLowerCase() == 'komma') {
    final decimals = _parseNumber(tokens[i + 1]);
    if (decimals != null && decimals >= 0 && decimals == decimals.truncate()) {
      quantity = double.parse('${quantity.truncate()}.${decimals.truncate()}');
      i += 2;
    }
  }

  final nameTokens = tokens
      .sublist(i)
      .where((t) => !_fillerWords.contains(t.toLowerCase()));
  final name = nameTokens.join(' ');
  if (name.isEmpty) return null;
  return ParsedLine(
    quantity: quantity,
    spokenName: name,
    locationHint: location,
    originHint: origin,
  );
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll('ß', 'ss')
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

double _scoreAgainst(String query, String candidate) {
  if (query.isEmpty || candidate.isEmpty) return 0;
  final q = query.replaceAll(' ', '');
  final c = candidate.replaceAll(' ', '');
  if (q == c) return 1.0;
  // Prefixes are only candidates for manual confirmation (< 0.8): "Gin" must
  // not auto-confirm "Ginger Ale", nor "Sprite" "Sprite Zero".
  if (candidate.startsWith('$query ')) return 0.75;
  if (candidate.split(' ').any((w) => w.startsWith(query))) return 0.7;
  if (c.contains(q)) return 0.6;
  // Spoken name is longer than the catalog name ("weisser rum bacardi").
  if (c.length >= 4 && q.contains(c)) return 0.7;
  return 0;
}

/// Ranks catalog items against a spoken name. The bracket addition
/// ("Weisser Rum (Bacardi)") is matched both separately and as part of the
/// whole name, so "Bacardi" and "Weisser Rum" each find the item.
List<CatalogMatch> matchCatalog(
  String spokenName,
  List<(String id, MaterialItem item)> catalog, {
  int max = 3,
}) {
  final query = _normalize(spokenName);
  final matches = <CatalogMatch>[];
  for (final (id, item) in catalog) {
    final bracket = RegExp(r'\(([^)]*)\)').firstMatch(item.name)?.group(1);
    final base = _normalize(item.name.replaceAll(RegExp(r'\([^)]*\)'), ''));
    final candidates = [
      base,
      if (bracket != null) _normalize(bracket),
      _normalize(item.name),
    ];
    var best = 0.0;
    for (final c in candidates) {
      final s = _scoreAgainst(query, c);
      if (s > best) best = s;
    }
    if (best > 0) {
      matches.add(CatalogMatch(materialId: id, name: item.name, score: best));
    }
  }
  matches.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.name.compareTo(b.name);
  });
  return matches.take(max).toList();
}

/// True only when the top match is unambiguous: exactly one hit >= 0.8, or the
/// best is at least 0.2 ahead of the second. A lone weak hit is not confident.
bool isConfident(List<CatalogMatch> matches) {
  if (matches.isEmpty) return false;
  if (matches.where((m) => m.score >= 0.8).length == 1) return true;
  if (matches.length < 2) return false;
  return matches[0].score - matches[1].score >= 0.2;
}
