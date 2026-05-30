import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/order_repository.dart';

/// Suggested material item for the shopping list from Claude AI.
class SuggestedMaterial {
  final String name;
  final String unit;
  final int quantity;
  final String reason;

  const SuggestedMaterial({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.reason,
  });

  factory SuggestedMaterial.fromJson(Map<String, dynamic> json) {
    return SuggestedMaterial(
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
    );
  }

  String get key => '$name|$unit';
}

/// Result from Claude material list generation.
class AiMaterialSuggestion {
  final List<SuggestedMaterial> materials;
  final String explanation;
  final int trainingDataCount;
  final List<String> usedCocktails;
  final String? errorMessage;
  final AiErrorType? errorType;

  const AiMaterialSuggestion({
    required this.materials,
    required this.explanation,
    required this.trainingDataCount,
    this.usedCocktails = const [],
    this.errorMessage,
    this.errorType,
  });

  bool get hasError => errorMessage != null;
  bool get isSuccess => !hasError && materials.isNotEmpty;

  factory AiMaterialSuggestion.error({
    required String message,
    required AiErrorType type,
    int trainingDataCount = 0,
  }) {
    return AiMaterialSuggestion(
      materials: const [],
      explanation: '',
      trainingDataCount: trainingDataCount,
      errorMessage: message,
      errorType: type,
    );
  }
}

enum AiErrorType {
  serviceUnavailable,
  rateLimitExceeded,
  invalidApiKey,
  notConfigured,
  networkError,
  invalidResponse,
  unknown,
}

class ClaudeService {
  static final ClaudeService _instance = ClaudeService._internal();
  factory ClaudeService() => _instance;
  ClaudeService._internal() {
    _initFromEnvironment();
  }

  static const String _envApiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const String _model = 'claude-sonnet-4-6';

  // Proxy URL to avoid CORS in the browser.
  // Set via --dart-define=CLAUDE_PROXY_URL=https://...
  // Falls back to Firebase Cloud Function URL per flavor.
  static const String _proxyUrl = String.fromEnvironment('CLAUDE_PROXY_URL', defaultValue: '');
  // Cloudflare Worker proxy — always available, API key lives server-side
  static const String _cloudflareProxy = 'https://cocktail-planer-claude-proxy.the-blacklodge.workers.dev';

  static String get _apiBase {
    if (_proxyUrl.isNotEmpty) return _proxyUrl;
    return _cloudflareProxy;
  }

  static bool get hasEnvKey => true; // proxy is always configured

  String? _apiKey;

  // Always configured — requests go through the Cloudflare proxy
  bool get isConfigured => true;

  void _initFromEnvironment() {
    if (_envApiKey.isNotEmpty) {
      setApiKey(_envApiKey);
      debugPrint('Claude API key loaded from environment');
    } else if (_proxyUrl.isNotEmpty) {
      debugPrint('Claude using proxy: $_proxyUrl');
    }
  }

  void setApiKey(String apiKey) {
    if (apiKey.isEmpty) return;
    _apiKey = apiKey;
    debugPrint('Claude API key configured');
  }

  void clearApiKey() {
    _apiKey = null;
  }

  /// Send a message to Claude and return the text response.
  Future<String?> _sendMessage(
    String prompt, {
    List<Map<String, dynamic>>? additionalContent,
    int maxTokens = 4096,
    String operationName = 'request',
    int maxRetries = 3,
  }) async {
    if (!isConfigured) return null;

    final content = additionalContent != null
        ? [{'type': 'text', 'text': prompt}, ...additionalContent]
        : [{'type': 'text', 'text': prompt}];

    int attempt = 0;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxRetries) {
      try {
        final response = await http.post(
          Uri.parse(_apiBase),
          headers: {
            if (_apiKey != null && _apiKey!.isNotEmpty) 'x-api-key': _apiKey!,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': maxTokens,
            'messages': [
              {'role': 'user', 'content': content},
            ],
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final contentList = data['content'] as List<dynamic>;
          final text = (contentList.first as Map<String, dynamic>)['text'] as String?;
          debugPrint('Claude $operationName succeeded');
          return text;
        }

        final isRetryable = response.statusCode == 503 || response.statusCode == 529;
        attempt++;

        if (!isRetryable || attempt >= maxRetries) {
          debugPrint('Claude $operationName failed: ${response.statusCode} ${response.body}');
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }

        debugPrint('Claude $operationName attempt $attempt failed (${response.statusCode}), retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        debugPrint('Claude $operationName attempt $attempt error: $e, retrying...');
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    return null;
  }



  /// For each recipe, ask Claude for standard bartender amounts per ingredient.
  /// Processes in batches of 5 to avoid token limits.
  Future<Map<String, Map<String, String>>> enrichRecipeAmounts(
    List<({String id, dynamic item})> recipes,
  ) async {
    const batchSize = 5;
    final result = <String, Map<String, String>>{};
    for (var i = 0; i < recipes.length; i += batchSize) {
      final batch = recipes.skip(i).take(batchSize).toList();
      final batchResult = await _enrichBatch(batch);
      result.addAll(batchResult);
    }
    return result;
  }

  Future<Map<String, Map<String, String>>> _enrichBatch(
    List<({String id, dynamic item})> batch,
  ) async {
    final recipeList = batch.map((r) {
      final recipe = r.item;
      return '- ${recipe.name}: ${(recipe.ingredients as List).join(', ')}';
    }).join('\n');

    final prompt = '''
Du bist ein erfahrener Barkeeper. Gib für jedes Cocktail-Rezept die Standard-Mengen pro Drink zurück.

REZEPTE:
$recipeList

Antworte NUR mit JSON. Format:
{"Rezeptname":{"Zutat1":"50ml","Zutat2":"30ml"}}

Regeln:
- Mengen in ml für Flüssigkeiten, Stück/Scheiben für Früchte/Deko
- Kein Markdown, nur reines JSON
''';

    try {
      final response = await _sendMessage(
        prompt,
        maxTokens: 1024,
        operationName: 'enrichBatch',
      );
      if (response == null) return {};

      final cleaned = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return parsed.map((recipeName, amounts) => MapEntry(
            recipeName,
            (amounts as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, v.toString())),
          ));
    } catch (e) {
      debugPrint('_enrichBatch failed: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOrderTrainingData() async {
    try {
      final orders = await orderRepository.watchOrders().first;
      final relevant = orders.where((o) => o.items.isNotEmpty && o.total > 0).toList();
      // Keep all for now — caller will filter to most relevant
      final limited = relevant;
      return limited.map((order) => {
        'id': order.id,
        'source': 'firestore_order',
        'guests': order.personCount,
        'guestRange': order.guestCountRange,
        'cocktails': order.cocktails,
        'cocktailCount': order.cocktails.length,
        'drinkerType': order.drinkerType,
        'items': order.items.map((item) => {
          'name': item['name'],
          'unit': item['unit'],
          'quantity': item['quantity'],
        }).toList(),
      }).toList();
    } catch (e) {
      debugPrint('Failed to get order training data: $e');
      return [];
    }
  }



  Future<AiMaterialSuggestion> generateMaterialSuggestions({
    required int guestCount,
    required String guestRange,
    required List<String> requestedCocktails,
    required String eventType,
    required String drinkerType,
    required List<Map<String, dynamic>> availableMaterials,
    required List<Map<String, dynamic>> recipeIngredients,
    Map<String, double>? cocktailPopularity,
    String? excludeOrderId,
  }) async {
    if (!isConfigured) {
      return AiMaterialSuggestion.error(
        message: 'Claude API ist nicht konfiguriert.',
        type: AiErrorType.notConfigured,
      );
    }

    try {
      final allOrders = await _fetchOrderTrainingData();
      final rawOrders = excludeOrderId != null
          ? allOrders.where((o) => o['id'] != excludeOrderId).toList()
          : allOrders;
      final materialNames = availableMaterials.map((m) => (m['name'] as String).toLowerCase()).toSet();

      // Filter items to only ingredients (no service items)
      final withIngredients = rawOrders.map((order) {
        final filteredItems = (order['items'] as List).where((item) {
          final name = (item['name'] as String).toLowerCase();
          return materialNames.any((m) => name.contains(m) || m.contains(name));
        }).toList();
        return {...order, 'items': filteredItems};
      }).where((o) => (o['items'] as List).isNotEmpty).toList();

      // Pick 5 most relevant: prefer same cocktails, then similar guest count
      final currentCocktailSet = requestedCocktails.map((c) => c.toLowerCase()).toSet();
      withIngredients.sort((a, b) {
        final aCocktails = (a['cocktails'] as List).map((c) => c.toString().toLowerCase()).toSet();
        final bCocktails = (b['cocktails'] as List).map((c) => c.toString().toLowerCase()).toSet();
        final aOverlap = aCocktails.intersection(currentCocktailSet).length;
        final bOverlap = bCocktails.intersection(currentCocktailSet).length;
        if (aOverlap != bOverlap) return bOverlap.compareTo(aOverlap);
        final aDiff = ((a['guests'] as int) - guestCount).abs();
        final bDiff = ((b['guests'] as int) - guestCount).abs();
        return aDiff.compareTo(bDiff);
      });
      final orderTraining = withIngredients.take(5).toList();

      final prompt = _buildMaterialPrompt(
        guestCount: guestCount,
        guestRange: guestRange,
        requestedCocktails: requestedCocktails,
        eventType: eventType,
        drinkerType: drinkerType,
        availableMaterials: availableMaterials,
        recipeIngredients: recipeIngredients,
        cocktailPopularity: cocktailPopularity ?? {},
        orderTraining: orderTraining,
      );

      debugPrint('=== CLAUDE PROMPT ===\n$prompt\n=== END PROMPT ===');
      final responseText = await _sendMessage(prompt, maxTokens: 4096, operationName: 'material suggestions');

      if (responseText == null || responseText.isEmpty) {
        return AiMaterialSuggestion.error(
          message: 'Keine Antwort von Claude erhalten.',
          type: AiErrorType.networkError,
          trainingDataCount: 0,
        );
      }

      final result = _parseMaterialResponse(responseText, 0);
      if (result == null) {
        return AiMaterialSuggestion.error(
          message: 'Antwort von Claude konnte nicht verarbeitet werden.',
          type: AiErrorType.invalidResponse,
          trainingDataCount: 0,
        );
      }
      return result;
    } catch (e) {
      debugPrint('Claude generation failed: $e');
      final errorString = e.toString();
      AiErrorType errorType = AiErrorType.unknown;
      String userMessage = 'Ein unbekannter Fehler ist aufgetreten.';

      if (errorString.contains('503') || errorString.contains('529')) {
        errorType = AiErrorType.serviceUnavailable;
        userMessage = 'Claude ist derzeit überlastet. Bitte versuchen Sie es in ein paar Minuten erneut.';
      } else if (errorString.contains('429')) {
        errorType = AiErrorType.rateLimitExceeded;
        userMessage = 'Rate Limit erreicht. Bitte versuchen Sie es später erneut.';
      } else if (errorString.contains('401') || errorString.contains('invalid')) {
        errorType = AiErrorType.invalidApiKey;
        userMessage = 'Ungültiger API-Key. Bitte prüfen Sie die Einstellungen.';
      } else if (errorString.contains('network') || errorString.contains('Failed host lookup')) {
        errorType = AiErrorType.networkError;
        userMessage = 'Keine Internetverbindung.';
      } else {
        userMessage = 'Fehler: ${errorString.length > 200 ? "${errorString.substring(0, 200)}..." : errorString}';
      }

      return AiMaterialSuggestion.error(message: userMessage, type: errorType);
    }
  }

  String _buildMaterialPrompt({
    required int guestCount,
    required String guestRange,
    required List<String> requestedCocktails,
    required String eventType,
    required String drinkerType,
    required List<Map<String, dynamic>> availableMaterials,
    required List<Map<String, dynamic>> recipeIngredients,
    required Map<String, double> cocktailPopularity,
    required List<Map<String, dynamic>> orderTraining,
  }) {
    // Strip unused fields to keep prompt small and fast
    final materialsJson = jsonEncode(availableMaterials.map((m) => {
      'name': m['name'],
      'unit': m['unit'],
    }).toList());
    final ingredientsJson = jsonEncode(recipeIngredients.map((r) => {
      'cocktail': r['cocktail'],
      'ingredients': r['ingredients'],
      if ((r['amounts'] as Map?)?.isNotEmpty == true) 'amounts': r['amounts'],
    }).toList());

    final popularityInfo = cocktailPopularity.isNotEmpty
        ? cocktailPopularity.entries
            .map((e) => '  - ${e.key}: ${e.value.round()}% Wahrscheinlichkeit')
            .join('\n')
        : 'Keine Wahrscheinlichkeits-Informationen verfügbar (verwende Standardverteilung)';

    return '''
Du bist ein Experte für Cocktail-Catering und Eventplanung in der Schweiz.

AUFGABE:
Erstelle eine Materialliste (Einkaufsliste) für das Event basierend auf den gewünschten Cocktails und der Gästezahl.

EVENT-DETAILS:
- Gästeanzahl: $guestCount (Bereich: $guestRange)
- Gewünschte Cocktails: ${requestedCocktails.isNotEmpty ? requestedCocktails.join(', ') : 'Nicht spezifiziert'}
- Event-Typ: $eventType
- Trinkverhalten: $drinkerType

COCKTAIL-POPULARITÄT (wie wahrscheinlich wird jeder Cocktail getrunken):
$popularityInfo

REZEPT-ZUTATEN (welche Zutaten für welchen Cocktail, inkl. Mengen pro Drink falls bekannt):
$ingredientsJson

WICHTIG: Falls "amounts" im Rezept vorhanden sind, nutze diese Mengenangaben pro Drink für die Berechnung!
Beispiel: amounts: {"Cranberry Saft": "50ml"} → 117 Drinks × 50ml ÷ 1000ml pro Flasche = 6 Flaschen

VERFÜGBARE MATERIALIEN (verwende NUR diese Namen und Einheiten exakt):
$materialsJson

WICHTIGE EINHEITEN-ERKLÄRUNG:
- "Limetten (54 Stk.)" mit Einheit "Stk" = 1 Kiste mit ~54 Limetten. Berechne: Anzahl Drinks die Limetten brauchen × 0.5 Limetten pro Drink ÷ 54. NICHT 1 Kiste pro Cocktail-Sorte! Faustregel: Bei unter 400 Gästen reicht erfahrungsgemäss 1 Kiste Limetten.
- "6x1.5L" = 1 Paket = 9L total
- "12x1L" = 1 Paket = 12L total
- "24er Pack" = 1 Paket mit 24 Einheiten

BERECHNUNGSPRINZIP FÜR GETEILTE ZUTATEN:
Wenn eine Zutat (z.B. Limetten, Rum) in mehreren Cocktails vorkommt, berechne die Gesamtmenge basierend auf den TOTAL DRINKS aller Cocktails die diese Zutat brauchen — NICHT Menge × Anzahl Cocktailsorten!

BERECHNUNGSREGELN:
⚠️ WICHTIG: Nicht alle Gäste trinken Cocktails! Erfahrungsgemäss bestellen nur ca. 20-30% der Gäste einen Cocktail.

1. TOTAL DRINKS BERECHNUNG:
   - normal-Event: $guestCount Gäste × 1.1 = ${(guestCount * 1.1).round()} Drinks TOTAL über ALLE Cocktails
   - Diese ${(guestCount * 1.1).round()} Drinks verteilen sich auf ${requestedCocktails.length} Cocktails = ~${(guestCount * 1.1 / requestedCocktails.length).round()} Drinks PRO Cocktail

2. Für Zutaten die in X Cocktails vorkommen: X × ${(guestCount * 1.1 / requestedCocktails.length).round()} Drinks = Basis für Mengenkalkulation
   Beispiel Limetten (54 Stk.): Anzahl Cocktails mit Limetten × ${(guestCount * 1.1 / requestedCocktails.length).round()} Drinks × 0.5 Limetten pro Drink ÷ 54 = Kisten

3. Berechne Mengen basierend auf den REZEPT-ZUTATEN (Primärquelle!)
4. Runde Mengen auf sinnvolle Packungsmengen auf
5. Berücksichtige Reserve (+15% Puffer)
6. Ignoriere Fixkosten wie Fahrtkosten, Personalkosten etc.

${orderTraining.isNotEmpty ? '''
ECHTE FRÜHERE AUFTRÄGE (nur Zutaten, gefiltert):
${jsonEncode(orderTraining)}

⚠️ WICHTIG beim Skalieren: Jeder Auftrag enthält "cocktails" und "cocktailCount". Wenn z.B. ein Auftrag 2 Mojito-Varianten hatte, aber der aktuelle Auftrag nur 1 hat, halbiere die Minze/Zucker-Mengen entsprechend. Skaliere Zutaten immer relativ zur Anzahl der Cocktails die sie benötigen, NICHT nur zur Gästezahl.
''' : ''}
WICHTIG: Antworte NUR mit validem JSON. "reason" maximal 60 Zeichen!
{
  "cocktails": ["Cocktailname1", "Cocktailname2"],
  "materials": [
    {"name": "Materialname", "unit": "Einheit", "quantity": 10, "reason": "Max 60 Zeichen"}
  ],
  "explanation": "Kurze Zusammenfassung"
}

REGELN FÜR DAS "cocktails" FELD (PFLICHTFELD!):
- Liste ALLE Cocktails die du für die Berechnung verwendet hast
- Cocktailnamen MÜSSEN EXAKT aus den REZEPT-ZUTATEN stammen
- Niemals ein leeres Array zurückgeben wenn Cocktails berechnet wurden!

PFLICHTARTIKEL (immer hinzufügen, exakt diese Namen und Einheiten):
- {"name": "Strohhalme", "unit": "500er Packung", "quantity": <Gästeanzahl × 1.5 ÷ 500, aufgerundet>, "reason": "Strohhalme: $guestCount Gäste × 1.5"}
- {"name": "Hartplastikbecher 0.3L", "unit": "30er Packung", "quantity": ${(guestCount * 1.5 / 30).ceil()}, "reason": "0.3L Becher: $guestCount Gäste × 1.5 ÷ 30"}
- {"name": "Hartplastikbecher 0.2L", "unit": "40er Packung", "quantity": ${(guestCount * 1.0 / 40).ceil()}, "reason": "0.2L Becher: $guestCount Gäste × 1.0 ÷ 40"}
- Falls Mojito oder Mango-Cocktail dabei: {"name": "Marshmallow", "unit": "Packung", "quantity": 1}
- {"name": "Servietten", "unit": "250er Packung", "quantity": <Gästeanzahl ÷ 250, aufgerundet>}
- {"name": "Schwarze Handschuhe", "unit": "100er Packung", "quantity": 1}
- {"name": "Küchenpapier", "unit": "4er Packung", "quantity": 1}

Diese Pflichtartikel kommen ZUSÄTZLICH zu den Cocktailzutaten aus VERFÜGBARE MATERIALIEN. Für Pflichtartikel darfst du auch Namen verwenden die nicht in VERFÜGBARE MATERIALIEN stehen.

Die Cocktailzutaten in "materials" MÜSSEN exakt aus der Liste VERFÜGBARE MATERIALIEN stammen!
''';
  }

  AiMaterialSuggestion? _parseMaterialResponse(String responseText, int trainingCount) {
    try {
      var jsonStr = responseText;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final materials = (json['materials'] as List<dynamic>?)
              ?.map((item) => SuggestedMaterial.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];
      final explanation = json['explanation'] as String? ?? '';
      final usedCocktails = (json['cocktails'] as List<dynamic>?)?.cast<String>() ?? [];

      return AiMaterialSuggestion(
        materials: materials,
        explanation: explanation,
        trainingDataCount: trainingCount,
        usedCocktails: usedCocktails,
      );
    } catch (e) {
      debugPrint('Failed to parse Claude material response: $e');
      debugPrint('Raw response: $responseText');
      return null;
    }
  }

  Future<Map<String, String?>> matchCocktailNames({
    required List<String> requestedNames,
    required List<String> availableRecipeNames,
  }) async {
    if (!isConfigured || requestedNames.isEmpty || availableRecipeNames.isEmpty) return {};

    try {
      final prompt = '''
Du bist ein Experte für Cocktails. Matche die angeforderten Cocktail-Namen zu den verfügbaren Rezeptnamen.

ANGEFORDERTE COCKTAILS (aus Kundenformular):
${requestedNames.map((n) => '- "$n"').join('\n')}

VERFÜGBARE REZEPTE IN UNSERER DATENBANK:
${availableRecipeNames.map((n) => '- "$n"').join('\n')}

AUFGABE:
Finde für jeden angeforderten Cocktail das passende Rezept. Beachte:
- Namen können unterschiedliche Schreibweisen haben (z.B. "classic mojito" = "Mojito Classic")
- Ignoriere Gross-/Kleinschreibung und Wortstellung
- Wenn kein passendes Rezept gefunden wird, setze null

Antworte NUR mit validem JSON:
{
  "matches": {
    "angeforderter_name_1": "passender_rezeptname_oder_null",
    "angeforderter_name_2": "passender_rezeptname_oder_null"
  }
}
''';

      final responseText = await _sendMessage(prompt, operationName: 'cocktail matching');
      if (responseText == null || responseText.isEmpty) return {};

      var jsonStr = responseText;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final matches = json['matches'] as Map<String, dynamic>? ?? {};
      return {for (final e in matches.entries) e.key: e.value as String?};
    } catch (e) {
      debugPrint('Claude cocktail matching failed: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>?> parseShoppingListImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (!isConfigured) return null;

    try {
      final base64Image = base64Encode(imageBytes);
      final lowerName = fileName.toLowerCase();
      String mediaType = 'image/png';
      if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
        mediaType = 'image/jpeg';
      }

      const prompt = '''
Du siehst eine Einkaufsliste für ein Cocktail-Catering-Event.

AUFGABE:
Extrahiere NUR die Einkaufsartikel/Zutaten aus diesem Dokument.

Antworte NUR mit validem JSON im folgenden Format:
{
  "items": [
    {"name": "Artikelname", "quantity": 10, "unit": "Stück/Liter/etc"}
  ],
  "totalPrice": 1234.50
}

Falls ein Wert nicht erkennbar ist, setze null.
''';

      final responseText = await _sendMessage(
        prompt,
        additionalContent: [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mediaType,
              'data': base64Image,
            },
          },
        ],
        operationName: 'image parsing',
      );
      if (responseText == null || responseText.isEmpty) return null;

      var jsonStr = responseText;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Claude image parsing failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> parseAuftragDocument({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (!isConfigured) return null;

    try {
      final base64Image = base64Encode(imageBytes);
      final lowerName = fileName.toLowerCase();
      String mediaType = 'image/png';
      if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
        mediaType = 'image/jpeg';
      }

      const prompt = '''
Du siehst einen Auftrag/Bestellformular für ein Cocktail-Catering-Event.

AUFGABE:
Extrahiere die Event-Metadaten aus diesem Dokument.

Antworte NUR mit validem JSON im folgenden Format:
{
  "eventName": "Name des Events oder Kundenname",
  "guestCount": 100,
  "eventDate": "2025-04-15",
  "cocktails": ["Cocktail Name 1", "Cocktail Name 2"],
  "notes": "Weitere relevante Infos (Ort, Uhrzeit, etc.)"
}

Falls ein Wert nicht erkennbar ist, setze null.
Für cocktails: Liste alle bestellten Cocktails auf die du im Dokument findest.
''';

      final responseText = await _sendMessage(
        prompt,
        additionalContent: [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mediaType,
              'data': base64Image,
            },
          },
        ],
        operationName: 'auftrag parsing',
      );
      if (responseText == null || responseText.isEmpty) return null;

      var jsonStr = responseText;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Claude auftrag parsing failed: $e');
      return null;
    }
  }

  Future<int> importHistoricalShoppingLists({
    required Future<List<Map<String, String?>>> Function() findEventPairs,
    required Future<Uint8List?> Function(String path) downloadFile,
  }) async {
    int imported = 0;
    try {
      final pairs = await findEventPairs();
      for (final pair in pairs) {
        try {
          final folder = pair['folder'] ?? '';
          final auftragFile = pair['auftragFile'];
          final einkaufslisteFile = pair['einkaufslisteFile'];

          Map<String, dynamic>? auftragData;
          Map<String, dynamic>? einkaufslisteData;

          if (auftragFile != null) {
            final bytes = await downloadFile(auftragFile);
            if (bytes != null) {
              auftragData = await parseAuftragDocument(
                imageBytes: bytes,
                fileName: auftragFile.split('/').last,
              );
            }
          }

          if (einkaufslisteFile != null) {
            final bytes = await downloadFile(einkaufslisteFile);
            if (bytes != null) {
              einkaufslisteData = await parseShoppingListImage(
                imageBytes: bytes,
                fileName: einkaufslisteFile.split('/').last,
              );
            }
          }

          if (auftragData == null && einkaufslisteData == null) continue;

          await FirebaseFirestore.instance
              .collection('historical_shopping_lists')
              .add({
            'folder': folder,
            'auftragFile': auftragFile,
            'einkaufslisteFile': einkaufslisteFile,
            'eventName': auftragData?['eventName'],
            'guestCount': auftragData?['guestCount'],
            'eventDate': auftragData?['eventDate'],
            'cocktails': auftragData?['cocktails'],
            'notes': auftragData?['notes'],
            'items': einkaufslisteData?['items'],
            'totalPrice': einkaufslisteData?['totalPrice'],
            'importedAt': FieldValue.serverTimestamp(),
          });
          imported++;
        } catch (e) {
          debugPrint('Failed to import pair: $e');
        }
      }
    } catch (e) {
      debugPrint('Import failed: $e');
    }
    return imported;
  }

  Future<String?> generateEventPlan({
    required String eventName,
    required int guestCount,
    required List<String> cocktails,
    required List<String> shots,
    required String drinkerType,
    required String? eventTime,
    required DateTime? eventDate,
    required String? location,
  }) async {
    if (!isConfigured) return null;

    final dateStr = eventDate != null
        ? '${eventDate.day}.${eventDate.month}.${eventDate.year}'
        : 'Nicht spezifiziert';

    final prompt = '''
Du bist der Chef-Planer von "Black Lodge", einem Premium Cocktail-Catering aus der Schweiz.
Erstelle einen detaillierten Ablauf- und Einsatzplan für das folgende Event.

EVENT-INFOS:
- Name: $eventName
- Datum: $dateStr
- Zeit: ${eventTime ?? 'Nicht spezifiziert'} (Service-Dauer: 5 Stunden ab Startzeit)
- Ort: ${location ?? 'Nicht spezifiziert'}
- Gäste: $guestCount Personen
- Trinkverhalten: $drinkerType
- Cocktails: ${cocktails.join(', ')}
- Shots: ${shots.isNotEmpty ? shots.join(', ') : 'Keine'}

STRUKTUR DES PLANS (in Markdown):

1. **Übersicht**: Kurze Zusammenfassung des Events.
2. **Zeitplan (Timeline)**:
   - Vorbereitung im Lager (Material laden)
   - Anfahrt (berücksichtige Distanz falls Ort bekannt)
   - Aufbau vor Ort (mind. 1.5h vor Service-Start)
   - Service-Phase (5 Stunden)
   - Abbau (ca. 45-60 Min)
   - Rückfahrt & Ausladen
3. **Personalplanung**:
   - Wie viele Barkeeper werden benötigt? (Empfehlung: ca. 1 Barkeeper pro 40-50 Gäste)
   - Rollenverteilung (z.B. Supervisor, Barkeeper, Runner)
4. **Vorbereitung & Mise-en-Place**:
   - Spezifische To-Dos für die gewählten Cocktails
   - Benötigtes Equipment (Theke, Mixer, etc.)
5. **Wichtige Hinweise**:
   - Besonderheiten des Event-Typs oder Trinkverhaltens.
   - Fokus-Punkte für exzellenten Service.

Schreibe den Plan professionell, motivierend und auf Deutsch. Verwende Markdown-Formatierung.
''';

    return await _sendMessage(prompt, maxTokens: 2048, operationName: 'event plan');
  }

  Future<String?> generateOfferShareMessage({
    required List<String> originalCocktails,
    required List<String> selectedCocktails,
    required List<String> allAvailableCocktails,
  }) async {
    if (!isConfigured || selectedCocktails.isEmpty) return null;

    try {
      final swaps = <Map<String, String>>[];
      for (int i = 0; i < originalCocktails.length && i < selectedCocktails.length; i++) {
        if (originalCocktails[i] != selectedCocktails[i]) {
          swaps.add({'original': originalCocktails[i], 'vorschlag': selectedCocktails[i]});
        }
      }

      final swapLines = swaps.isEmpty
          ? ''
          : '\n\nUNSERE TAUSCH-VORSCHLÄGE (der Kunde hat diese noch NICHT bestätigt):\n'
              '${swaps.map((s) => '  - ORIGINAL: "${s['original']}"\n    VORSCHLAG: "${s['vorschlag']}"').join('\n')}';

      final swapRule = swaps.isEmpty
          ? '- Kommentiere nur die aktuelle Auswahl des Kunden'
          : '''- Kommentiere kurz die aktuelle Kundenauswahl
- Formuliere dann für JEDEN Tausch-Vorschlag eine freundliche Empfehlung
- ⚠️ Der Tausch ist NOCH NICHT vollzogen. Schreibe IMMER als Vorschlag/Frage, NIE als Vollzug.''';

      final prompt = '''
Du bist ein freundlicher Berater des Premium Cocktail-Catering-Services "Black Lodge" aus der Schweiz.

AUFGABE:
Schreibe einen kurzen, natürlichen Kommentar zur Cocktail-Auswahl des Kunden für eine WhatsApp-Nachricht.

KUNDENAUSWAHL:
${originalCocktails.map((c) => '- $c').join('\n')}$swapLines

ALLE VERFÜGBAREN COCKTAILS IM REPERTOIRE:
${allAvailableCocktails.map((c) => '- $c').join('\n')}

REGELN:
- Schreibe 2-4 Sätze insgesamt
- Bewerte kurz die Harmonie der Kundenauswahl
$swapRule
- Schreibe locker und persönlich, wie ein Barkeeper-Tipp, nicht werblich
- Auf Deutsch
- KEINE Anrede – die kommt separat
- KEIN Abschlussgruss – der kommt separat
- Maximal 1-2 Emojis wenn es natürlich wirkt

Antworte NUR mit dem Kommentar-Text, kein JSON, kein Markdown.
''';

      return await _sendMessage(prompt, maxTokens: 512, operationName: 'offer share message');
    } catch (e) {
      debugPrint('Claude offer message generation failed: $e');
      return null;
    }
  }
}

final claudeService = ClaudeService();
