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
  'einem': 1,
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
  'dreißig': 30,
  'dreissig': 30,
  'vierzig': 40,
  'fünfzig': 50,
  'fuenfzig': 50,
  'halbe': 0.5,
  'halben': 0.5,
  'halb': 0.5,
  'anderthalb': 1.5,
  'eineinhalb': 1.5,
  'zweieinhalb': 2.5,
  'dreieinhalb': 3.5,
  'viereinhalb': 4.5,
  'fünfeinhalb': 5.5,
  'fuenfeinhalb': 5.5,
  'sechseinhalb': 6.5,
};

/// Spoken lead-in that is not part of the line ("ich hab noch ungefähr ...").
const _leadFillers = {
  'ich',
  'wir',
  'hab',
  'habe',
  'haben',
  'es',
  'sind',
  'da',
  'noch',
  'insgesamt',
  'ungefähr',
  'ungefaehr',
  'circa',
  'etwa',
  'so',
  'ca',
};

/// Unit words around the quantity that are not part of the article name.
/// "Liter"/"L" are deliberately absent ("Orangen Saft 1L").
const _unitWords = {
  'flasche',
  'flaschen',
  'fl',
  'packung',
  'packungen',
  'pack',
  'packs',
  'kiste',
  'kisten',
  'karton',
  'kartons',
  'stück',
  'stueck',
  'stk',
  'x',
  'mal',
};

// Split on , ; newline and "und", but not on a decimal comma ("2,8").
final _separator = RegExp(
  r'(?<!\d),|,(?!\d)|;|\n|\bund\b',
  caseSensitive: false,
);

final _plainNumber = RegExp(r'^\d+([.,]\d+)?$');
final _numberWithX = RegExp(r'^(\d+([.,]\d+)?)x$', caseSensitive: false);
final _edgePunctuation = RegExp('^[.,;:!?"\'“”„‚‘’()]+|[.,;:!?"\'“”„‚‘’()]+\$');

double? _parseNumber(String token) {
  final lower = token.toLowerCase();
  final word = _numberWords[lower];
  if (word != null) return word;
  // Plain non-negative decimals only: no sign, exponent, NaN or Infinity.
  if (!_plainNumber.hasMatch(lower)) return null;
  return double.tryParse(lower.replaceAll(',', '.'));
}

/// The result of [parseRestTextDetailed].
class ParseResult {
  const ParseResult({required this.lines, required this.unparsed});

  /// Fragments that became a line.
  final List<ParsedLine> lines;

  /// Fragments with content but without a usable quantity or name, as the
  /// text to pre-fill (the user adds the number).
  final List<String> unparsed;
}

/// Parses speech-recognition output into stock lines. Fragments without a
/// quantity or without a name are skipped instead of guessed.
List<ParsedLine> parseRestText(String text) =>
    parseRestTextDetailed(text).lines;

/// Like [parseRestText], but also reports the fragments that could not be
/// turned into a line, so none is dropped silently.
ParseResult parseRestTextDetailed(String text) {
  final lines = <ParsedLine>[];
  final unparsed = <String>[];
  for (final fragment in text.split(_separator)) {
    final (line, leftover) = _parseFragment(fragment);
    if (line != null) {
      lines.add(line);
    } else if (leftover != null) {
      unparsed.add(leftover);
    }
  }
  return ParseResult(lines: lines, unparsed: unparsed);
}

List<String> _tokenize(String fragment) {
  final tokens = <String>[];
  for (final raw in fragment.split(RegExp(r'\s+'))) {
    final t = raw.replaceAll(_edgePunctuation, '');
    if (t.isEmpty) continue;
    final x = _numberWithX.firstMatch(t);
    if (x != null) {
      tokens
        ..add(x.group(1)!)
        ..add('x');
    } else {
      tokens.add(t);
    }
  }
  return tokens;
}

// (line, unparsedText): at most one is set; both null = nothing to say.
(ParsedLine?, String?) _parseFragment(String fragment) {
  var tokens = _tokenize(fragment);
  if (tokens.isEmpty) return (null, null);
  final raw = tokens.join(' ');

  // "bei Mario" anywhere in the fragment is the location hint.
  String? location;
  final beiAt = tokens.indexWhere((t) => t.toLowerCase() == 'bei');
  if (beiAt >= 0 && beiAt + 1 < tokens.length) {
    location = tokens[beiAt + 1];
    tokens = [...tokens.sublist(0, beiAt), ...tokens.sublist(beiAt + 2)];
  }

  StockOrigin? origin;
  if (tokens.any((t) => t.toLowerCase() == 'investition')) {
    origin = StockOrigin.investment;
    tokens = tokens.where((t) => t.toLowerCase() != 'investition').toList();
  } else if (tokens.any((t) => t.toLowerCase() == 'auftrag')) {
    // An explicit "Auftrag" matters for a count (only that origin is set).
    origin = StockOrigin.order;
    tokens = tokens.where((t) => t.toLowerCase() != 'auftrag').toList();
  }

  var lead = 0;
  while (lead < tokens.length &&
      _leadFillers.contains(tokens[lead].toLowerCase())) {
    lead++;
  }
  tokens = tokens.sublist(lead);
  if (tokens.isEmpty) return (null, null);

  // The first standalone number token (digits or word) is the quantity.
  final numAt = tokens.indexWhere((t) => _parseNumber(t) != null);
  double? quantity;
  var rest = tokens;
  if (numAt >= 0) {
    quantity = _parseNumber(tokens[numAt]);
    var end = numAt + 1;
    // "zwei Komma acht": digits after "Komma" are the decimal places.
    if (end + 1 < tokens.length && tokens[end].toLowerCase() == 'komma') {
      final decimals = _parseNumber(tokens[end + 1]);
      if (quantity != null &&
          decimals != null &&
          decimals >= 0 &&
          decimals == decimals.truncate()) {
        quantity = double.parse(
          '${quantity.truncate()}.${decimals.truncate()}',
        );
        end += 2;
      }
    }
    rest = [...tokens.sublist(0, numAt), ...tokens.sublist(end)];
  }

  var nameTokens = rest
      .where((t) => !_unitWords.contains(t.toLowerCase()))
      .toList();
  if (nameTokens.isNotEmpty && nameTokens.first.toLowerCase() == 'von') {
    nameTokens = nameTokens.sublist(1);
  }
  final name = nameTokens.join(' ');
  if (quantity == null || name.isEmpty) {
    return (null, name.isEmpty ? raw : name);
  }
  return (
    ParsedLine(
      quantity: quantity,
      spokenName: name,
      locationHint: location,
      originHint: origin,
    ),
    null,
  );
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll('ß', 'ss')
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõ]'), 'o')
    .replaceAll(RegExp('[úùû]'), 'u')
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
