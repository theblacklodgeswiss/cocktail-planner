import 'dart:convert';

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
  }

  /// API key from dart-define (compile-time)
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  
  /// Check if environment API key is available.
  static bool get hasEnvKey => _envApiKey.isNotEmpty;
  
  String? _apiKey;
  GenerativeModel? _model;

  /// Check if Gemini is configured (API key set).
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  
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
    try {
      // Get all orders with shopping lists (hasShoppingList = true)
      final ordersStream = orderRepository.watchOrders();
      final orders = await ordersStream.first;

      final trainingData = <Map<String, dynamic>>[];

      for (final order in orders) {
        // Only use orders that have a shopping list (items and total > 0)
        if (order.items.isEmpty || order.total <= 0) continue;

        trainingData.add({
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

      debugPrint('Collected ${trainingData.length} orders as training data');
      return trainingData;
    } catch (e) {
      debugPrint('Failed to get training data: $e');
      return [];
    }
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
- Trinkverhalten: $drinkerType (light = 2-3 Drinks pro Person, normal = 4-5 Drinks, heavy = 6+ Drinks)

REZEPT-ZUTATEN (welche Zutaten für welchen Cocktail):
$ingredientsJson

VERFÜGBARE MATERIALIEN (verwende NUR diese Namen und Einheiten exakt):
$materialsJson

HISTORISCHE DATEN VON FRÜHEREN EVENTS (für Lernzwecke):
$trainingDataJson

BERECHNUNGSREGELN:
1. Schätze Drinks pro Person basierend auf drinkerType:
   - light: 2-3 Drinks
   - normal: 4-5 Drinks
   - heavy: 6-7 Drinks
2. Verteile die Drinks gleichmässig auf die gewünschten Cocktails
3. Berechne Mengen basierend auf Standard-Rezepturen (pro Cocktail ca. 4cl Spirituosen, 2cl Likör, etc.)
4. Runde Mengen auf praktische Einkaufsmengen auf (ganze Flaschen à 0.7L, Kartons, etc.)
5. Berücksichtige Reserve (+10-15% Puffer)
6. Ignoriere Verbrauchsmaterialien wie Fahrtkosten, Personalkosten etc.

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
}

final geminiService = GeminiService();
