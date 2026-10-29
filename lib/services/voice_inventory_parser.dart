import '../models/material_item.dart';
import '../models/stock.dart';

/// One spoken stock line, e.g. "bei Mario 3 Sprite".
class ParsedLine {
  const ParsedLine({
    required this.quantity,
    required this.spokenName,
    this.locationHint,
    this.originHint,
    this.quantityUnsure = false,
  });

  final double quantity;
  final String spokenName;
  final String? locationHint;
  final StockOrigin? originHint;

  /// The quantity is a trailing number that might be part of the name
  /// ("Stroh 80") and no catalog could tell.
  final bool quantityUnsure;
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

/// Dropped directly after the quantity besides unit words ("einen Rest
/// Bacardi").
const _afterQuantityFillers = {'rest', 'reste'};

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

double _bestScore(String name, List<(String, MaterialItem)> catalog) {
  if (name.isEmpty) return 0;
  final m = matchCatalog(name, catalog, max: 1);
  return m.isEmpty ? 0 : m.first.score;
}

/// Like [parseRestText], but also reports the fragments that could not be
/// turned into a line, so none is dropped silently.
///
/// With a [catalog], names that end in a number ("Stroh 80") or contain a
/// unit word ("Pack Eis") are kept when the catalog knows them.
ParseResult parseRestTextDetailed(
  String text, {
  List<(String id, MaterialItem item)>? catalog,
}) {
  final lines = <ParsedLine>[];
  final unparsed = <String>[];
  for (final fragment in text.split(_separator).expand(_splitAtQuantities)) {
    final (line, leftover) = _parseFragment(fragment, catalog);
    if (line != null) {
      lines.add(line);
    } else if (leftover != null) {
      unparsed.add(leftover);
    }
  }
  return ParseResult(lines: lines, unparsed: unparsed);
}

/// "drei Bacardi fünf Rohrzucker" is two items without an "und": a fragment
/// that starts with a quantity is split before a later quantity word that
/// starts a new item (it is followed by a name, or the first quantity also
/// had a unit: "zwei Flaschen Rum drei Flaschen Gin"). "zwei Komma acht" and
/// names ending in a number stay together.
Iterable<String> _splitAtQuantities(String fragment) {
  final tokens = _tokenize(fragment);
  var start = 0;
  while (start < tokens.length &&
      _leadFillers.contains(tokens[start].toLowerCase())) {
    start++;
  }
  bool isNumToken(int i) => _parseNumber(tokens[i]) != null;
  bool isUnitToken(int i) =>
      i < tokens.length && _unitWords.contains(tokens[i].toLowerCase());
  if (start >= tokens.length || !isNumToken(start)) return [fragment];
  final firstHadUnit = isUnitToken(start + 1);
  final parts = <String>[];
  var from = 0;
  for (var i = start + 2; i < tokens.length - 1; i++) {
    if (!isNumToken(i)) continue;
    final prev = tokens[i - 1].toLowerCase();
    final next = tokens[i + 1].toLowerCase();
    if (prev == 'komma' || next == 'komma') continue;
    if (isUnitToken(i + 1) && !firstHadUnit) continue;
    if (isNumToken(i + 1)) continue;
    parts.add(tokens.sublist(from, i).join(' '));
    from = i;
  }
  if (parts.isEmpty) return [fragment];
  parts.add(tokens.sublist(from).join(' '));
  return parts;
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
(ParsedLine?, String?) _parseFragment(
  String fragment,
  List<(String, MaterialItem)>? catalog,
) {
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

  // The origin word, with a leading "auf" ("auf Auftrag").
  StockOrigin? origin;
  for (final (word, o) in const [
    ('investition', StockOrigin.investment),
    ('auftrag', StockOrigin.order),
  ]) {
    final at = tokens.indexWhere((t) => t.toLowerCase() == word);
    if (at < 0) continue;
    origin = o;
    final from = at > 0 && tokens[at - 1].toLowerCase() == 'auf' ? at - 1 : at;
    tokens = [
      ...tokens.sublist(0, from),
      ...tokens.sublist(at + 1).where((t) => t.toLowerCase() != word),
    ];
    break;
  }

  var lead = 0;
  while (lead < tokens.length &&
      _leadFillers.contains(tokens[lead].toLowerCase())) {
    lead++;
  }
  tokens = tokens.sublist(lead);
  // A trailing "da" ("3 Bacardi da").
  while (tokens.isNotEmpty && tokens.last.toLowerCase() == 'da') {
    tokens = tokens.sublist(0, tokens.length - 1);
  }
  if (tokens.isEmpty) return (null, null);

  bool isNum(int i) => _parseNumber(tokens[i]) != null;
  bool isUnit(int i) =>
      i < tokens.length && _unitWords.contains(tokens[i].toLowerCase());

  // Which token is the quantity, by priority:
  // 1. a number at the start; 2. a number directly before a unit word;
  // 3. a number word anywhere; 4. a trailing number (unless the catalog
  // knows it as part of the name). Other digits belong to the name.
  var unsure = false;
  int? numAt;
  if (isNum(0)) {
    numAt = 0;
  } else {
    for (var i = 1; i < tokens.length && numAt == null; i++) {
      if (isNum(i) && isUnit(i + 1)) numAt = i;
    }
    for (var i = 1; i < tokens.length && numAt == null; i++) {
      if (_numberWords.containsKey(tokens[i].toLowerCase())) numAt = i;
    }
    final last = tokens.length - 1;
    if (numAt == null && last > 0 && isNum(last)) {
      final name = tokens.sublist(0, last).join(' ');
      final partOfName =
          catalog != null &&
          _bestScore(tokens.join(' '), catalog) >= 0.8 &&
          _bestScore(tokens.join(' '), catalog) > _bestScore(name, catalog);
      if (!partOfName) {
        numAt = last;
        unsure = catalog == null;
      }
    }
  }

  double? quantity;
  var nameTokens = tokens;
  var keptUnits = tokens;
  if (numAt != null) {
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
    keptUnits = [...tokens.sublist(0, numAt), ...tokens.sublist(end)];
    // Unit words (and "Rest") only directly after the quantity.
    var after = end;
    while (after < tokens.length &&
        (_unitWords.contains(tokens[after].toLowerCase()) ||
            _afterQuantityFillers.contains(tokens[after].toLowerCase()))) {
      after++;
    }
    nameTokens = [...tokens.sublist(0, numAt), ...tokens.sublist(after)];
  }

  String nameOf(List<String> t) {
    if (t.isNotEmpty && t.first.toLowerCase() == 'von') t = t.sublist(1);
    return t.join(' ');
  }

  var name = nameOf(nameTokens);
  if (catalog != null) {
    final full = nameOf(keptUnits);
    if (full != name &&
        _bestScore(full, catalog) > _bestScore(name, catalog)) {
      name = full;
    }
  }
  if (quantity == null || name.isEmpty) {
    return (null, name.isEmpty ? raw : name);
  }
  return (
    ParsedLine(
      quantity: quantity,
      spokenName: name,
      locationHint: location,
      originHint: origin,
      quantityUnsure: unsure,
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
