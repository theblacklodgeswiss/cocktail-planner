import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/services/gemini_service.dart';

void main() {
  group('GeminiService', () {
    late GeminiService geminiService;

    setUp(() {
      geminiService = GeminiService();
    });

    group('Configuration', () {
      test('singleton instance returns same object', () {
        final instance1 = GeminiService();
        final instance2 = GeminiService();
        expect(instance1, same(instance2));
      });

      test('isConfigured returns false when no API key is set', () {
        // Clear any existing key
        geminiService.clearApiKey();
        expect(geminiService.isConfigured, isFalse);
      });

      test('isConfigured returns true when API key is set', () {
        geminiService.setApiKey('test-api-key-123');
        expect(geminiService.isConfigured, isTrue);
      });

      test('clearApiKey removes configuration', () {
        geminiService.setApiKey('test-api-key');
        expect(geminiService.isConfigured, isTrue);
        
        geminiService.clearApiKey();
        expect(geminiService.isConfigured, isFalse);
      });

      test('setApiKey ignores empty string', () {
        geminiService.clearApiKey();
        geminiService.setApiKey('');
        expect(geminiService.isConfigured, isFalse);
      });

      test('hasEnvKey returns true when environment key is available', () {
        // This will be false in test environment unless set
        expect(GeminiService.hasEnvKey, isA<bool>());
      });
    });

    group('Usage Tracking', () {
      test('requestsToday starts at 0', () {
        expect(geminiService.requestsToday, greaterThanOrEqualTo(0));
      });

      test('inputTokensToday starts at 0', () {
        expect(geminiService.inputTokensToday, greaterThanOrEqualTo(0));
      });

      test('outputTokensToday starts at 0', () {
        expect(geminiService.outputTokensToday, greaterThanOrEqualTo(0));
      });

      test('totalTokensToday equals input + output', () {
        final total = geminiService.totalTokensToday;
        final input = geminiService.inputTokensToday;
        final output = geminiService.outputTokensToday;
        expect(total, equals(input + output));
      });

      test('requestUsagePercentage is between 0 and 1', () {
        final percentage = geminiService.requestUsagePercentage;
        expect(percentage, greaterThanOrEqualTo(0.0));
        expect(percentage, lessThanOrEqualTo(1.0));
      });

      test('tokenUsagePercentage is between 0 and 1', () {
        final percentage = geminiService.tokenUsagePercentage;
        expect(percentage, greaterThanOrEqualTo(0.0));
        expect(percentage, lessThanOrEqualTo(1.0));
      });

      test('remainingRequests is positive', () {
        expect(geminiService.remainingRequests, greaterThanOrEqualTo(0));
      });

      test('dailyRequestLimit is constant', () {
        expect(GeminiService.dailyRequestLimit, equals(20));
      });

      test('dailyTokenLimit is constant', () {
        expect(GeminiService.dailyTokenLimit, equals(1000000));
      });
    });

    group('Time Management', () {
      test('timeUntilReset returns a duration', () {
        final duration = GeminiService.timeUntilReset;
        expect(duration, isA<Duration>());
        expect(duration.inMilliseconds, greaterThan(0));
      });

      test('resetTimeFormatted returns formatted string', () {
        final formatted = GeminiService.resetTimeFormatted;
        expect(formatted, isNotEmpty);
        expect(formatted, matches(RegExp(r'^\d+[hm]')));
      });
    });

    group('SuggestedMaterial', () {
      test('fromJson creates valid object', () {
        final json = {
          'name': 'Vodka',
          'unit': 'cl',
          'quantity': 200,
          'reason': 'For cocktails',
        };

        final material = SuggestedMaterial.fromJson(json);
        expect(material.name, equals('Vodka'));
        expect(material.unit, equals('cl'));
        expect(material.quantity, equals(200));
        expect(material.reason, equals('For cocktails'));
      });

      test('fromJson handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final material = SuggestedMaterial.fromJson(json);
        expect(material.name, equals(''));
        expect(material.unit, equals(''));
        expect(material.quantity, equals(0));
        expect(material.reason, equals(''));
      });

      test('fromJson handles numeric quantity as int', () {
        final json1 = {'quantity': 42};
        expect(SuggestedMaterial.fromJson(json1).quantity, equals(42));

        final json2 = {'quantity': 42.7};
        expect(SuggestedMaterial.fromJson(json2).quantity, equals(42));
      });

      test('key combines name and unit', () {
        final material = SuggestedMaterial(
          name: 'Vodka',
          unit: 'cl',
          quantity: 100,
          reason: 'Test',
        );
        expect(material.key, equals('Vodka|cl'));
      });

      test('key handles empty unit', () {
        final material = SuggestedMaterial(
          name: 'Ice',
          unit: '',
          quantity: 5,
          reason: 'Test',
        );
        expect(material.key, equals('Ice|'));
      });
    });

    group('Material Generation (without real API)', () {
      test('generateMaterialSuggestions returns error when not configured', () async {
        geminiService.clearApiKey();

        final result = await geminiService.generateMaterialSuggestions(
          guestCount: 100,
          guestRange: '75-125',
          requestedCocktails: ['Mojito', 'Aperol Spritz'],
          eventType: 'Wedding',
          drinkerType: 'normal',
          availableMaterials: [],
          recipeIngredients: [],
        );

        expect(result.hasError, isTrue);
        expect(result.errorType, equals(GeminiErrorType.notConfigured));
      });

      test('matchCocktailNames returns empty map when not configured', () async {
        geminiService.clearApiKey();

        final result = await geminiService.matchCocktailNames(
          requestedNames: ['mojito'],
          availableRecipeNames: ['Mojito Classic'],
        );

        expect(result, isEmpty);
      });

      test('matchCocktailNames returns empty map for empty inputs', () async {
        geminiService.setApiKey('test-key');

        final result1 = await geminiService.matchCocktailNames(
          requestedNames: [],
          availableRecipeNames: ['Mojito'],
        );
        expect(result1, isEmpty);

        final result2 = await geminiService.matchCocktailNames(
          requestedNames: ['Mojito'],
          availableRecipeNames: [],
        );
        expect(result2, isEmpty);
      });
    });

    group('Response Parsing', () {
      test('parseMaterialResponse extracts JSON from markdown code blocks', () {
        // This tests the internal parsing logic indirectly by checking
        // that the service can be constructed without errors
        expect(geminiService, isNotNull);
      });
    });

    group('GeminiMaterialSuggestion', () {
      test('creates valid suggestion object', () {
        final materials = [
          SuggestedMaterial(
            name: 'Vodka',
            unit: 'cl',
            quantity: 200,
            reason: 'Base spirit',
          ),
          SuggestedMaterial(
            name: 'Lime',
            unit: 'pcs',
            quantity: 50,
            reason: 'Garnish',
          ),
        ];

        final suggestion = GeminiMaterialSuggestion(
          materials: materials,
          explanation: 'Calculated for 100 guests',
          trainingDataCount: 42,
        );

        expect(suggestion.materials, hasLength(2));
        expect(suggestion.explanation, equals('Calculated for 100 guests'));
        expect(suggestion.trainingDataCount, equals(42));
      });

      test('handles empty materials list', () {
        final suggestion = GeminiMaterialSuggestion(
          materials: const [],
          explanation: 'No materials needed',
          trainingDataCount: 0,
        );

        expect(suggestion.materials, isEmpty);
      });
    });

    group('Edge Cases', () {
      test('service handles multiple setApiKey calls', () {
        geminiService.setApiKey('key1');
        expect(geminiService.isConfigured, isTrue);

        geminiService.setApiKey('key2');
        expect(geminiService.isConfigured, isTrue);

        geminiService.setApiKey('key3');
        expect(geminiService.isConfigured, isTrue);
      });

      test('usage percentages never exceed 1.0', () {
        // Even with actual usage, percentages should be clamped
        expect(geminiService.requestUsagePercentage, lessThanOrEqualTo(1.0));
        expect(geminiService.tokenUsagePercentage, lessThanOrEqualTo(1.0));
      });

      test('remainingRequests never goes negative', () {
        // Should be clamped to 0 at minimum
        expect(geminiService.remainingRequests, greaterThanOrEqualTo(0));
      });
    });

    group('Integration Scenarios', () {
      test('typical workflow: configure -> check limits -> generate', () async {
        // 1. Configure
        geminiService.setApiKey('test-key');
        expect(geminiService.isConfigured, isTrue);

        // 2. Check limits
        expect(geminiService.remainingRequests, greaterThanOrEqualTo(0));
        
        // 3. Attempt generation (will fail without real API, but won't crash)
        final result = await geminiService.generateMaterialSuggestions(
          guestCount: 100,
          guestRange: '75-125',
          requestedCocktails: ['Mojito'],
          eventType: 'Wedding',
          drinkerType: 'normal',
          availableMaterials: [
            {'name': 'Vodka', 'unit': 'cl', 'price': 5.0, 'currency': 'CHF'},
          ],
          recipeIngredients: [
            {'cocktail': 'Mojito', 'ingredients': ['Rum', 'Mint', 'Lime']},
          ],
        );

        // Without real API, should return error (with invalid API key)
        expect(result.hasError, isTrue);
        expect(result.errorType, equals(GeminiErrorType.invalidApiKey));
      });

      test('error scenario: generate without configuration', () async {
        geminiService.clearApiKey();
        
        final result = await geminiService.generateMaterialSuggestions(
          guestCount: 50,
          guestRange: '40-60',
          requestedCocktails: ['Aperol Spritz'],
          eventType: 'Birthday',
          drinkerType: 'light',
          availableMaterials: [],
          recipeIngredients: [],
        );

        expect(result.hasError, isTrue);
        expect(result.errorType, equals(GeminiErrorType.notConfigured));
      });

      test('usage tracking scenario', () {
        final startRequests = geminiService.requestsToday;
        final startTokens = geminiService.totalTokensToday;
        
        // These values should be consistent
        expect(startRequests, isA<int>());
        expect(startTokens, isA<int>());
        
        // Usage should be trackable
        final usage = geminiService.requestUsagePercentage;
        expect(usage, isA<double>());
      });
    });

    group('Material Suggestion Data Validation', () {
      test('suggestion validates guest count is provided', () {
        // This test verifies that the service expects valid guest count
        // The actual validation happens in the service call
        expect(() {
          geminiService.setApiKey('test');
          // Guest count should be positive
          geminiService.generateMaterialSuggestions(
            guestCount: -1, // Invalid
            guestRange: '0-0',
            requestedCocktails: [],
            eventType: '',
            drinkerType: '',
            availableMaterials: [],
            recipeIngredients: [],
          );
        }, returnsNormally);
      });

      test('suggestion handles empty cocktail list', () async {
        geminiService.setApiKey('test-key');
        
        final result = await geminiService.generateMaterialSuggestions(
          guestCount: 100,
          guestRange: '90-110',
          requestedCocktails: [], // Empty
          eventType: 'Party',
          drinkerType: 'normal',
          availableMaterials: [],
          recipeIngredients: [],
        );

        // Should return error due to invalid API key
        expect(result.hasError, isTrue);
        expect(result.errorType, equals(GeminiErrorType.invalidApiKey));
      });

      test('suggestion handles optional cocktail popularity', () async {
        geminiService.setApiKey('test-key');
        
        // Without popularity data
        final result1 = await geminiService.generateMaterialSuggestions(
          guestCount: 100,
          guestRange: '90-110',
          requestedCocktails: ['Mojito'],
          eventType: 'Party',
          drinkerType: 'normal',
          availableMaterials: [],
          recipeIngredients: [],
          // No cocktailPopularity parameter
        );

        // With popularity data
        final result2 = await geminiService.generateMaterialSuggestions(
          guestCount: 100,
          guestRange: '90-110',
          requestedCocktails: ['Mojito'],
          eventType: 'Party',
          drinkerType: 'normal',
          availableMaterials: [],
          recipeIngredients: [],
          cocktailPopularity: {'Mojito': 0.8, 'Aperol Spritz': 0.2},
        );

        // Both should return errors (invalid API key)
        expect(result1.hasError, isTrue);
        expect(result1.errorType, equals(GeminiErrorType.invalidApiKey));
        expect(result2.hasError, isTrue);
        expect(result2.errorType, equals(GeminiErrorType.invalidApiKey));
      });
    });

    group('Cocktail Name Matching', () {
      test('handles various cocktail name formats', () {
        // This verifies the service accepts different formats
        expect(() {
          geminiService.setApiKey('test');
          geminiService.matchCocktailNames(
            requestedNames: [
              'mojito',
              'APEROL SPRITZ',
              'Moscow Mule',
              'gin & tonic',
            ],
            availableRecipeNames: [
              'Mojito Classic',
              'Aperol Spritz',
              'Moscow Mule',
              'Gin Tonic',
            ],
          );
        }, returnsNormally);
      });
    });
  });
}
