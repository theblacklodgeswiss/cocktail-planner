import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../data/order_repository.dart';

/// Suggested material item for the shopping list from Gemini.
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

  /// Key for app state storage (name|unit).
  String get key => '$name|$unit';
}

/// Result from Gemini material list generation.
class GeminiMaterialSuggestion {
  final List<SuggestedMaterial> materials;
  final String explanation;
  final int trainingDataCount;

  const GeminiMaterialSuggestion({
    required this.materials,
    required this.explanation,
    required this.trainingDataCount,
  });
}

/// Service for generating shopping lists using Gemini AI.
/// Learns from existing orders to improve predictions over time.
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal() {
    // Auto-initialize from dart-define environment variable
    _initFromEnvironment();
    // Load usage from Firestore
    _loadUsageFromFirestore();
  }

  /// API key from dart-define (compile-time)
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  
  /// Check if environment API key is available.
  static bool get hasEnvKey => _envApiKey.isNotEmpty;
  
  /// Free tier daily limits for gemini-2.5-flash
  static const int dailyRequestLimit = 500; // RPD (Requests Per Day)
  static const int dailyTokenLimit = 1000000; // TPD (Tokens Per Day)
  
  String? _apiKey;
  GenerativeModel? _model;
  bool _usageLoaded = false;
  
  /// Usage tracking (from actual API responses, persisted in Firestore)
  int _requestsToday = 0;
  int _inputTokensToday = 0;
  int _outputTokensToday = 0;
  DateTime _lastResetDate = DateTime.now();

  /// Check if Gemini is configured (API key set).
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  
  /// Get today's date key for Firestore.
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  /// Get number of requests made today.
  int get requestsToday {
    _checkDayReset();
    return _requestsToday;
  }
  
  /// Get total input tokens used today.
  int get inputTokensToday {
    _checkDayReset();
    return _inputTokensToday;
  }
  
  /// Get total output tokens used today.
  int get outputTokensToday {
    _checkDayReset();
    return _outputTokensToday;
  }
  
  /// Get total tokens used today.
  int get totalTokensToday => inputTokensToday + outputTokensToday;
  
  /// Get request usage percentage (0.0 - 1.0).
  double get requestUsagePercentage {
    _checkDayReset();
    return (_requestsToday / dailyRequestLimit).clamp(0.0, 1.0);
  }
  
  /// Get token usage percentage (0.0 - 1.0).
  double get tokenUsagePercentage {
    _checkDayReset();
    return (totalTokensToday / dailyTokenLimit).clamp(0.0, 1.0);
  }
  
  /// Get remaining requests today.
  int get remainingRequests {
    _checkDayReset();
    return (dailyRequestLimit - _requestsToday).clamp(0, dailyRequestLimit);
  }
  
  /// Check if we need to reset daily counters.
  void _checkDayReset() {
    final now = DateTime.now();
    if (now.day != _lastResetDate.day || 
        now.month != _lastResetDate.month || 
        now.year != _lastResetDate.year) {
      _requestsToday = 0;
      _inputTokensToday = 0;
      _outputTokensToday = 0;
      _lastResetDate = now;
    }
  }
  
  /// Load usage data from Firestore.
  Future<void> _loadUsageFromFirestore() async {
    if (_usageLoaded) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('gemini_usage')
          .doc(_todayKey)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _requestsToday = data['requests'] as int? ?? 0;
        _inputTokensToday = data['inputTokens'] as int? ?? 0;
        _outputTokensToday = data['outputTokens'] as int? ?? 0;
        debugPrint('Loaded Gemini usage from Firestore: $_requestsToday requests, $totalTokensToday tokens');
      }
      _usageLoaded = true;
    } catch (e) {
      debugPrint('Failed to load Gemini usage: $e');
    }
  }
  
  /// Save usage data to Firestore.
  Future<void> _saveUsageToFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('gemini_usage')
          .doc(_todayKey)
          .set({
        'requests': _requestsToday,
        'inputTokens': _inputTokensToday,
        'outputTokens': _outputTokensToday,
        'date': _todayKey,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to save Gemini usage: $e');
    }
  }
  
  /// Track usage from API response.
  void _trackUsage(GenerateContentResponse response) {
    _checkDayReset();
    _requestsToday++;
    
    final usage = response.usageMetadata;
    if (usage != null) {
      _inputTokensToday += usage.promptTokenCount ?? 0;
      _outputTokensToday += usage.candidatesTokenCount ?? 0;
      debugPrint('Gemini usage: ${usage.promptTokenCount} input + ${usage.candidatesTokenCount} output = ${usage.totalTokenCount} tokens');
    }
    
    // Persist to Firestore
    _saveUsageToFirestore();
  }
  
  /// Reload usage data from Firestore (for UI refresh).
  Future<void> reloadUsage() async {
    _usageLoaded = false;
    await _loadUsageFromFirestore();
  }
  
  /// Initialize from environment variable if available.
  void _initFromEnvironment() {
    if (_envApiKey.isNotEmpty && _apiKey == null) {
      setApiKey(_envApiKey);
      debugPrint('Gemini API key loaded from environment');
    }
  }

  /// Set the Gemini API key (override from Firestore settings).
  void setApiKey(String apiKey) {
    if (apiKey.isEmpty) return;
    _apiKey = apiKey;
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
    debugPrint('Gemini API key configured');
  }

  /// Clear the API key.
  void clearApiKey() {
    _apiKey = null;
    _model = null;
  }

  /// Get training data from existing orders with shopping lists.
  Future<List<Map<String, dynamic>>> _getTrainingData() async {
    final trainingData = <Map<String, dynamic>>[];
    
    try {
      // Get orders from Firestore
      final ordersStream = orderRepository.watchOrders();
      final orders = await ordersStream.first;

      for (final order in orders) {
        // Only use orders that have a shopping list (items and total > 0)
        if (order.items.isEmpty || order.total <= 0) continue;

        trainingData.add({
          'source': 'firestore_order',
          'guests': order.personCount,
          'guestRange': order.guestCountRange,
          'cocktails': order.cocktails,
          'shots': order.shots,
          'requestedCocktails': order.requestedCocktails,
          'drinkerType': order.drinkerType,
          'eventType': order.eventType,
          'items': order.items.map((item) => {
            'name': item['name'],
            'unit': item['unit'],
            'quantity': item['quantity'],
            'total': item['total'],
          }).toList(),
          'total': order.total,
          'distanceKm': order.distanceKm,
        });
      }
    } catch (e) {
      debugPrint('Failed to get order training data: $e');
    }

    // Also get historical data imported from OneDrive
    try {
      final historicalDocs = await FirebaseFirestore.instance
          .collection('historical_shopping_lists')
          .get();
      
      for (final doc in historicalDocs.docs) {
        final data = doc.data();
        trainingData.add({
          'source': 'historical_import',
          'guests': data['guestCount'],
          'eventName': data['eventName'],
          'cocktails': data['cocktails'],
          'items': data['items'],
          'total': data['totalPrice'],
          'eventDate': data['eventDate'],
        });
      }
      debugPrint('Loaded ${historicalDocs.docs.length} historical shopping lists');
    } catch (e) {
      debugPrint('Failed to get historical training data: $e');
    }

    debugPrint('Total training data: ${trainingData.length} records');
    return trainingData;
  }

  /// Generate material list suggestions using Gemini AI.
  Future<GeminiMaterialSuggestion?> generateMaterialSuggestions({
    required int guestCount,
    required String guestRange,
    required List<String> requestedCocktails,
    required String eventType,
    required String drinkerType,
    required List<Map<String, dynamic>> availableMaterials,
    required List<Map<String, dynamic>> recipeIngredients,
  }) async {
    if (!isConfigured || _model == null) {
      debugPrint('Gemini not configured');
      return null;
    }

    try {
      // Get training data from existing orders
      final trainingData = await _getTrainingData();

      // Build the prompt for material suggestions
      final prompt = _buildMaterialPrompt(
        guestCount: guestCount,
        guestRange: guestRange,
        requestedCocktails: requestedCocktails,
        eventType: eventType,
        drinkerType: drinkerType,
        availableMaterials: availableMaterials,
        recipeIngredients: recipeIngredients,
        trainingData: trainingData,
      );

      debugPrint('Sending material prompt to Gemini...');

      // Generate content
      final response = await _model!.generateContent([Content.text(prompt)]);
      _trackUsage(response);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        debugPrint('Empty response from Gemini');
        return null;
      }

      debugPrint('Gemini response received');

      // Parse the JSON response
      return _parseMaterialResponse(responseText, trainingData.length);
    } catch (e) {
      debugPrint('Gemini generation failed: $e');
      return null;
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
    required List<Map<String, dynamic>> trainingData,
  }) {
    final materialsJson = jsonEncode(availableMaterials);
    final ingredientsJson = jsonEncode(recipeIngredients);
    final trainingDataJson = trainingData.isNotEmpty
        ? jsonEncode(trainingData)
        : 'Keine vorherigen Bestellungen verfügbar';

    return '''
Du bist ein Experte für Cocktail-Catering und Eventplanung in der Schweiz.

AUFGABE:
Erstelle eine Materialliste (Einkaufsliste) für das Event basierend auf den gewünschten Cocktails und der Gästezahl.

EVENT-DETAILS:
- Gästeanzahl: $guestCount (Bereich: $guestRange)
- Gewünschte Cocktails: ${requestedCocktails.isNotEmpty ? requestedCocktails.join(', ') : 'Nicht spezifiziert'}
- Event-Typ: $eventType
- Trinkverhalten: $drinkerType

REZEPT-ZUTATEN (welche Zutaten für welchen Cocktail):
$ingredientsJson

VERFÜGBARE MATERIALIEN (verwende NUR diese Namen und Einheiten exakt):
$materialsJson

HISTORISCHE DATEN VON FRÜHEREN EVENTS (für Lernzwecke - WICHTIG: orientiere dich an diesen echten Bestellmengen!):
$trainingDataJson

KRITISCHE BERECHNUNGSREGELN:
⚠️ WICHTIG: Nicht alle Gäste trinken Cocktails! Erfahrungsgemäss bestellen nur ca. 20-30% der Gäste einen Cocktail.

1. TOTAL DRINKS BERECHNUNG (NICHT pro Person!):
   - light-Event: ca. 0.8-1.0 Drinks pro Gast total
   - normal-Event: ca. 1.0-1.2 Drinks pro Gast total  
   - heavy-Event: ca. 1.3-1.5 Drinks pro Gast total
   
   Beispiel: 500 Gäste "normal" = 500-600 Drinks TOTAL (nicht 2500!)

2. Verteile die Drinks gleichmässig auf die gewünschten Cocktails
3. Berechne Mengen basierend auf unseren Rezepturen:
   - Pro Cocktail: ca. 2cl Spirituosen, 2cl Likör/Sirup, 6-12cl Filler/Saft
4. Runde Mengen auf die nächsthöhere verfügbare Packungsgrösse
5. Berücksichtige Reserve (+15% Puffer)
6. Ignoriere Fixkosten wie Fahrtkosten, Personalkosten etc.

FALLS historische Daten verfügbar sind, orientiere dich STARK an deren Mengen pro Gast!

WICHTIG: Antworte NUR mit validem JSON im folgenden Format:
{
  "materials": [
    {"name": "Materialname", "unit": "Einheit", "quantity": 10, "reason": "Kurze Begründung"}
  ],
  "explanation": "Zusammenfassung der Berechnung"
}

Die Namen und Einheiten in "materials" MÜSSEN exakt aus der Liste VERFÜGBARE MATERIALIEN stammen!
''';
  }

  GeminiMaterialSuggestion? _parseMaterialResponse(String responseText, int trainingCount) {
    try {
      // Extract JSON from response (might be wrapped in markdown code blocks)
      var jsonStr = responseText;
      
      // Remove markdown code blocks if present
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

      return GeminiMaterialSuggestion(
        materials: materials,
        explanation: explanation,
        trainingDataCount: trainingCount,
      );
    } catch (e) {
      debugPrint('Failed to parse Gimini material response: $e');
      debugPrint('Raw response: $responseText');
      return null;
    }
  }

  /// Match requested cocktail names to available recipe names using AI.
  /// Returns a map of requested name -> matched recipe name (or null if no match).
  Future<Map<String, String?>> matchCocktailNames({
    required List<String> requestedNames,
    required List<String> availableRecipeNames,
  }) async {
    if (!isConfigured || _model == null) {
      debugPrint('Gemini not configured for cocktail matching');
      return {};
    }

    if (requestedNames.isEmpty || availableRecipeNames.isEmpty) {
      return {};
    }

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

      debugPrint('Sending cocktail matching prompt to Gemini...');
      final response = await _model!.generateContent([Content.text(prompt)]);
      _trackUsage(response);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        debugPrint('Empty response from Gemini for cocktail matching');
        return {};
      }

      // Parse JSON response
      var jsonStr = responseText;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final matches = json['matches'] as Map<String, dynamic>? ?? {};

      final result = <String, String?>{};
      for (final entry in matches.entries) {
        result[entry.key] = entry.value as String?;
      }

      debugPrint('Cocktail matching result: $result');
      return result;
    } catch (e) {
      debugPrint('Gemini cocktail matching failed: $e');
      return {};
    }
  }

  /// Parse a shopping list image and extract structured data.
  /// Returns extracted data or null on failure.
  Future<Map<String, dynamic>?> parseShoppingListImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (!isConfigured || _model == null) {
      debugPrint('Gemini not configured for image parsing');
      return null;
    }

    try {
      // Determine MIME type from file name
      String mimeType = 'image/png';
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (lowerName.endsWith('.pdf')) {
        mimeType = 'application/pdf';
      }

      final prompt = '''
Du siehst eine Einkaufsliste für ein Cocktail-Catering-Event.

AUFGABE:
Extrahiere alle relevanten Daten aus diesem Dokument.

Antworte NUR mit validem JSON im folgenden Format:
{
  "eventName": "Name des Events/Kunden (falls erkennbar)",
  "guestCount": 100,
  "eventDate": "2025-04-15",
  "cocktails": ["Cocktail Name 1", "Cocktail Name 2"],
  "items": [
    {"name": "Artikelname", "quantity": 10, "unit": "Stück/Liter/etc"}
  ],
  "totalPrice": 1234.50,
  "notes": "Weitere relevante Infos"
}

Falls ein Wert nicht erkennbar ist, setze null.
''';

      debugPrint('Parsing shopping list image: $fileName');
      
      final response = await _model!.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ]),
      ]);
      _trackUsage(response);

      final responseText = response.text;
      if (responseText == null || responseText.isEmpty) {
        debugPrint('Empty response from Gemini for image parsing');
        return null;
      }

      // Parse JSON response
      var jsonStr = responseText;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      debugPrint('Parsed shopping list: ${data['eventName']}');
      return data;
    } catch (e) {
      debugPrint('Gemini image parsing failed: $e');
      return null;
    }
  }

  /// Import historical shopping lists from OneDrive and save to Firestore.
  /// Returns number of successfully imported lists.
  Future<int> importHistoricalShoppingLists({
    required Future<List<String>> Function() findFiles,
    required Future<Uint8List?> Function(String path) downloadFile,
  }) async {
    int imported = 0;

    try {
      final files = await findFiles();
      debugPrint('Found ${files.length} historical shopping list files');

      for (final filePath in files) {
        try {
          final bytes = await downloadFile(filePath);
          if (bytes == null) {
            debugPrint('Could not download: $filePath');
            continue;
          }

          final fileName = filePath.split('/').last;
          final data = await parseShoppingListImage(
            imageBytes: bytes,
            fileName: fileName,
          );

          if (data == null) {
            debugPrint('Could not parse: $filePath');
            continue;
          }

          // Save to Firestore as training data
          await FirebaseFirestore.instance
              .collection('historical_shopping_lists')
              .add({
            'filePath': filePath,
            'eventName': data['eventName'],
            'guestCount': data['guestCount'],
            'eventDate': data['eventDate'],
            'cocktails': data['cocktails'],
            'items': data['items'],
            'totalPrice': data['totalPrice'],
            'notes': data['notes'],
            'importedAt': FieldValue.serverTimestamp(),
          });

          imported++;
          debugPrint('Imported: $filePath');
        } catch (e) {
          debugPrint('Failed to import $filePath: $e');
        }
      }

      debugPrint('Successfully imported $imported shopping lists');
      return imported;
    } catch (e) {
      debugPrint('Import failed: $e');
      return imported;
    }
  }
}

final geminiService = GeminiService();
