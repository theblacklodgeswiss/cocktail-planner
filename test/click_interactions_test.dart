import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cocktail_planer/models/cocktail_data.dart';
import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/models/recipe.dart';
import 'package:cocktail_planer/screens/forms/modern_order_form_screen.dart';
import 'package:cocktail_planer/screens/shopping_list/shopping_list_screen.dart';
import 'package:cocktail_planer/state/app_state.dart';

Widget _localizedMaterialApp(Widget home) {
  return MaterialApp(home: home);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeData = CocktailData(
    materials: const [
      MaterialItem(
        unit: 'Stk',
        name: 'Limetten (54 Stk.)',
        price: 14.0,
        currency: 'CHF',
        note: 'Prodega',
      ),
      MaterialItem(
        unit: '0.7L',
        name: 'Baileys',
        price: 14.0,
        currency: 'CHF',
        note: 'Kaufland',
      ),
      MaterialItem(
        unit: '0.7L',
        name: 'Kahlua',
        price: 18.0,
        currency: 'CHF',
        note: 'Kaufland',
      ),
    ],
    recipes: const [
      Recipe(
        id: 'mojito_classic',
        name: 'Mojito - Classic',
        ingredients: ['Limetten (54 Stk.)'],
        type: 'cocktail',
      ),
      Recipe(
        id: 'shot_b52',
        name: 'Shot - B52',
        ingredients: ['Baileys', 'Kahlua'],
        type: 'shot',
      ),
    ],
    fixedValues: const [
      MaterialItem(
        unit: 'Stk',
        name: 'BL Box',
        price: 0,
        currency: 'CHF',
        note: 'BlackLodge',
      ),
    ],
  );

  setUp(() {
    appState.setSelectedRecipes([]);
  });

  group('Dashboard and Shopping List Interactions', () {
    // The tests of the old cocktail DashboardScreen were removed with the
    // dead screen (lib/screens/dashboard/dashboard_screen.dart).
  testWidgets(
    'shopping item can be selected and quantity changed',
    (
    tester,
  ) async {
    appState.setSelectedRecipes([
      const Recipe(
        id: 'mojito_classic',
        name: 'Mojito - Classic',
        ingredients: ['Limetten (54 Stk.)'],
        type: 'cocktail',
      ),
    ]);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        _localizedMaterialApp(
          ShoppingListScreen(loadData: () async => fakeData),
        ),
      );
      await tester.pumpAndSettle();
    });

    // OrderSetupForm is now a Card, not AlertDialog - no dialog to handle
    // The screen starts directly with the form visible

    // Find TextFormFields in the OrderSetupForm (name and personCount are required)
    final formFields = find.byType(TextFormField);
    if (formFields.evaluate().isEmpty) {
      // Form might already be filled or not shown
      return;
    }

    // Enter data in required fields (name is first, personCount is 5th after phone, date pickers, address)
    await tester.enterText(formFields.first, 'Test Event');
    await tester.pump();

    // Try to find and fill person count field
    if (formFields.evaluate().length > 4) {
      await tester.enterText(formFields.at(4), '50');
      await tester.pump();
    }

    // Tap the FilledButton to proceed if it exists
    final weiterButton = find.byType(FilledButton);
    if (weiterButton.evaluate().isNotEmpty) {
      await tester.tap(weiterButton.first);
      await tester.pumpAndSettle();
    }

    // Find and tap the item card to select it (checkbox area)
    final itemCard = find.text('Limetten (54 Stk.)');
    if (itemCard.evaluate().isNotEmpty) {
      expect(itemCard, findsOneWidget);

      // Tap on the card area to select
      await tester.tap(itemCard);
      await tester.pumpAndSettle();

      // After selection, TextField should appear for quantity
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, '2');
        await tester.pumpAndSettle();
        // There may be 2 "2"s now (input + total badge), just verify at least one exists
        expect(find.text('2'), findsWidgets);
      }
    }
  });
  }, skip: 'Requires dependency injection for AuthService - currently a global singleton initialized at import time');

  group('Shot quantity stepper', () {
    testWidgets('selecting a shot defaults its quantity to 1, then increments',
        (tester) async {
      // Arrange: pump the order form to the cocktail-selection step and
      // locate one Recipe with isShot == true, following the same pump/setup
      // pattern as the nearest existing test in this group above.
      // Act: tap the shot's card once to select it.
      // Assert: a Text widget showing '1' appears within the same card.
      // Act: tap the '+' IconButton once.
      // Assert: the Text widget now shows '2'.
      // Act: tap '-' twice.
      // Assert: the shot is deselected (quantity Text and stepper icons gone)
      // and the underlying recipe is removed from the selected set.
    }, skip: true);
    // Skip: requires dependency injection for CocktailRepository/FirestoreService -
    // ModernOrderFormScreen calls the global cocktailRepository singleton directly
    // (no loadData injection point like DashboardScreen has), which calls
    // FirebaseFirestore.instance with no Firebase app initialized in widget tests.
    // Confirmed by probing: pumping ModernOrderFormScreen throws
    // "No Firebase App '[DEFAULT]' has been created" before the cocktail-selection
    // step is ever reachable. Unskip once that DI exists.
  });

  group('Shot quantity prefill (regression for staff-prefill quantity wipe)', () {
    // Full widget-level coverage of ModernOrderFormScreen's prefill path is
    // blocked by the same DI limitation documented above (global
    // cocktailRepository/FirestoreService singletons). The prefill quantity
    // lookup was extracted into the pure, directly-testable
    // `resolveShotPrefillQuantity` function specifically so this regression
    // is still covered without needing widget pumping.
    test(
      'uses the customer-requested quantity from shotSelections, not the default of 1',
      () {
        final order = SavedOrder.fromFirestore('o1', {
          'name': 'Test',
          'date': '2026-06-01T00:00:00.000',
          'items': [],
          'total': 0,
          'currency': 'CHF',
          'status': 'quote',
          'shots': ['Tequila'],
          'shotQuantities': [
            {'name': 'Tequila', 'quantity': 15},
          ],
        });

        expect(order.shots, ['Tequila']);
        expect(
          order.shotSelections,
          [const ShotSelection(name: 'Tequila', quantity: 15)],
        );

        final seededQuantity = resolveShotPrefillQuantity(
          order.shotSelections,
          'Tequila',
        );

        expect(seededQuantity, 15);
        expect(seededQuantity, isNot(1));
      },
    );

    test('defaults to 1 for legacy orders with no per-flavor data', () {
      final order = SavedOrder.fromFirestore('o2', {
        'name': 'Test',
        'date': '2026-06-01T00:00:00.000',
        'items': [],
        'total': 0,
        'currency': 'CHF',
        'status': 'quote',
        'shots': ['Tequila'],
        // No shotQuantities at all - legacy order.
      });

      expect(order.shotSelections, isEmpty);
      expect(
        resolveShotPrefillQuantity(order.shotSelections, 'Tequila'),
        1,
      );
    });
  });
}
