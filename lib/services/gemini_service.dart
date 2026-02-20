import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../data/order_repository.dart';

/// Suggested item for the shopping list from Gemini.
class SuggestedItem {
  final String name;
  final String unit;
  final int quantity;
  final String reason;

  const SuggestedItem({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.reason,
  });

  factory SuggestedItem.fromJson(Map<String, dynamic> json) {
    return SuggestedItem(
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'reason': reason,
      };
}

/// Result from Gemini shopping list generation.
class GeminiSuggestion {
  final List<SuggestedItem> items;
  final List<String> suggestedCocktails;
  final String explanation;
  final int trainingDataCount;

  const GeminiSuggestion({
    required this.items,
    required this.suggestedCocktails,
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

  /// Generate shopping list suggestions using Gemini AI.
  Future<GeminiSuggestion?> generateSuggestions({
    required int guestCount,
    required String guestRange,
    required List<String> requestedCocktails,
    required String eventType,
    required String drinkerType,
    required List<Map<String, dynamic>> availableMaterials,
    required List<String> availableCocktails,
  }) async {
    if (!isConfigured || _model == null) {
      debugPrint('Gemini not configured');
      return null;
    }

    try {
      // Get training data from existing orders
      final trainingData = await _getTrainingData();

      // Build the prompt
      final prompt = _buildPrompt(
        guestCount: guestCount,
        guestRange: guestRange,
        requestedCocktails: requestedCocktails,
        eventType: eventType,
        drinkerType: drinkerType,
        availableMaterials: availableMaterials,
        availableCocktails: availableCocktails,
        trainingData: trainingData,
      );

      debugPrint('Sending prompt to Gemini...');

      // Generate content
      final response = await _model!.generateContent([Content.text(prompt)]);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        debugPrint('Empty response from Gemini');
        return null;
      }

      debugPrint('Gemini response received');

      // Parse the JSON response
      return _parseResponse(responseText, trainingData.length);
    } catch (e) {
      debugPrint('Gemini generation failed: $e');
      return null;
    }
  }

  String _buildPrompt({
    required int guestCount,
    required String guestRange,
    required List<String> requestedCocktails,
    required String eventType,
    required String drinkerType,
    required List<Map<String, dynamic>> availableMaterials,
    required List<String> availableCocktails,
    required List<Map<String, dynamic>> trainingData,
  }) {
    final cocktailsList = availableCocktails.join(', ');

    final trainingDataJson = trainingData.isNotEmpty
        ? jsonEncode(trainingData)
        : 'Keine vorherigen Bestellungen verfügbar';

    return '''
Du bist ein Experte für Cocktail-Catering und Eventplanung in der Schweiz.

AUFGABE:
Schlage passende Cocktails für das Event vor.

EVENT-DETAILS:
- Gästeanzahl: $guestCount (Bereich: $guestRange)
- Angefragte Cocktails: ${requestedCocktails.isNotEmpty ? requestedCocktails.join(', ') : 'Nicht spezifiziert'}
- Event-Typ: $eventType
- Trinkverhalten: $drinkerType (light/normal/heavy)

VERFÜGBARE COCKTAILS (verwende NUR diese Namen exakt):
$cocktailsList

HISTORISCHE DATEN VON FRÜHEREN EVENTS (für Lernzwecke):
$trainingDataJson

REGELN:
1. Wähle 4-8 passende Cocktails aus der Liste VERFÜGBARE COCKTAILS
2. Berücksichtige Event-Typ und Gästezahl
3. Bei Hochzeiten: elegante, klassische Cocktails
4. Bei Geburtstagen: bunte, fruchtige Cocktails
5. Mische alkoholische mit alkoholfreien Optionen
6. Wenn Cocktails angefragt wurden, inkludiere diese (wenn verfügbar)

WICHTIG: Antworte NUR mit validem JSON im folgenden Format:
{
  "suggestedCocktails": ["Cocktailname1", "Cocktailname2", "Cocktailname3"],
  "explanation": "Kurze Erklärung warum diese Cocktails gewählt wurden"
}

Die Namen in "suggestedCocktails" MÜSSEN exakt aus der Liste VERFÜGBARE COCKTAILS stammen!
''';
  }

  GeminiSuggestion? _parseResponse(String responseText, int trainingCount) {
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

      final itemsList = (json['items'] as List<dynamic>?)
              ?.map((item) => SuggestedItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      final cocktails = (json['suggestedCocktails'] as List<dynamic>?)
              ?.cast<String>() ??
          [];

      final explanation = json['explanation'] as String? ?? '';

      return GeminiSuggestion(
        items: itemsList,
        suggestedCocktails: cocktails,
        explanation: explanation,
        trainingDataCount: trainingCount,
      );
    } catch (e) {
      debugPrint('Failed to parse Gemini response: $e');
      debugPrint('Raw response: $responseText');
      return null;
    }
  }
}

final geminiService = GeminiService();
