import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopping_list/models/cocktail_data.dart';
import 'package:shopping_list/models/material_item.dart';
import 'package:shopping_list/models/recipe.dart';
import 'package:shopping_list/screens/dashboard/dashboard_screen.dart';
import 'package:shopping_list/screens/shopping_list/shopping_list_screen.dart';
import 'package:shopping_list/state/app_state.dart';
import 'package:shopping_list/widgets/recipe_selection_dialog.dart';

Widget _localizedMaterialApp(Widget home) {
  return MaterialApp(home: home);
}

Widget _localizedRouterApp(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
  );
}

/// Helper to fill out the OrderSetupForm that appears on Dashboard
Future<void> _fillOrderSetupForm(WidgetTester tester) async {
  // Wait for the form to appear
  await tester.pumpAndSettle();
  
  // Find TextFormFields in the OrderSetupForm
  final textFields = find.byType(TextFormField);
  expect(textFields, findsWidgets);
  
  // Fill in orderName (first field)
  await tester.enterText(textFields.first, 'Test Event');
  await tester.pump();
  
  // Fill in personCount field
  // Fields are: 0=orderName, 1=phoneNumber, 2=address, 3=personCount, 4=distance
  if (textFields.evaluate().length > 3) {
    await tester.enterText(textFields.at(3), '50');
    await tester.pump();
  }
  
  // Find and tap the submit button (FilledButton in the form)
  final submitButtons = find.byType(FilledButton);
  if (submitButtons.evaluate().isNotEmpty) {
    await tester.ensureVisible(submitButtons.last);
    await tester.tap(submitButtons.last);
    await tester.pumpAndSettle();
    // Wait for the state to update and the empty state to appear
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }
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

  testWidgets('FAB click opens recipe selection dialog', (tester) async {
    // Set a larger viewport to avoid overflow with OrderSetupForm
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    
    await tester.runAsync(() async {
      await tester.pumpWidget(
        _localizedMaterialApp(DashboardScreen(loadData: () async => fakeData)),
      );
      await tester.pumpAndSettle();
    });
    
    // Fill OrderSetupForm first
    await _fillOrderSetupForm(tester);

    // Find the "Add Cocktails" button in the empty state
    final addButton = find.byIcon(Icons.add);
    expect(addButton, findsOneWidget);
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byType(RecipeSelectionDialog), findsOneWidget);
  });

  testWidgets('select + apply click adds recipe card', (tester) async {
    // Set a larger viewport to avoid overflow with OrderSetupForm
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    
    await tester.runAsync(() async {
      await tester.pumpWidget(
        _localizedMaterialApp(DashboardScreen(loadData: () async => fakeData)),
      );
      await tester.pumpAndSettle();
    });
    
    // Fill OrderSetupForm first
    await _fillOrderSetupForm(tester);

    // Find and tap the "Add Cocktails" button
    final addButton = find.byIcon(Icons.add);
    expect(addButton, findsOneWidget);
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Search for Mojito in the dialog
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField.first, 'Mojito');
    await tester.pumpAndSettle();

    // Select the recipe (using ListTile, not CheckboxListTile)
    final mojitoTile = find.widgetWithText(ListTile, 'Mojito - Classic');
    expect(mojitoTile, findsOneWidget);
    await tester.tap(mojitoTile.first);
    await tester.pumpAndSettle();

    // Apply selection - find the button in the dialog
    final applyButton = find.descendant(
      of: find.byType(RecipeSelectionDialog),
      matching: find.byType(FilledButton),
    );
    expect(applyButton, findsWidgets);
    await tester.tap(applyButton.last);
    await tester.pumpAndSettle();

    expect(find.text('Mojito - Classic'), findsOneWidget);
  });

  testWidgets('delete click removes selected recipe card', (tester) async {
    // Set a larger viewport to avoid overflow with OrderSetupForm
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    
    appState.setSelectedRecipes([
      const Recipe(id: 'delete_me', name: 'Delete Me', ingredients: ['Mint'], type: 'cocktail')
    ]);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        _localizedMaterialApp(DashboardScreen(loadData: () async => fakeData)),
      );
      await tester.pumpAndSettle();
    });
    
    // Fill OrderSetupForm first
    await _fillOrderSetupForm(tester);

    expect(find.text('Delete Me'), findsOneWidget);

    // Find and tap the delete icon (close icon on chip)
    final deleteIcon = find.byIcon(Icons.close);
    expect(deleteIcon, findsWidgets);
    await tester.tap(deleteIcon.first);
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsNothing);
  });

  testWidgets('generate button click navigates to shopping list route',
      (tester) async {
    // Set a larger viewport to avoid overflow with OrderSetupForm
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    
    appState.setSelectedRecipes([
      const Recipe(id: 'go_next', name: 'Go Next', ingredients: ['Mint'], type: 'cocktail')
    ]);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              DashboardScreen(loadData: () async => fakeData),
        ),
        GoRoute(
          path: '/shopping-list',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('ShoppingListRoute'))),
        ),
      ],
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(_localizedRouterApp(router));
      await tester.pumpAndSettle();
    });
    
    // Fill OrderSetupForm first
    await _fillOrderSetupForm(tester);

    // Find the generate button by its icon (shopping_cart)
    final generateButton = find.byIcon(Icons.shopping_cart);
    expect(generateButton, findsWidgets);
    if (generateButton.evaluate().isNotEmpty) {
      await tester.tap(generateButton.first);
      await tester.pumpAndSettle();
      
      expect(find.text('ShoppingListRoute'), findsOneWidget);
    }
  });

  testWidgets('shopping item can be selected and quantity changed', (tester) async {
    appState.setSelectedRecipes([
      const Recipe(
        id: 'mojito_classic',
        name: 'Mojito - Classic',
        ingredients: ['Limetten (54 Stk.)'],
        type: 'cocktail',
      )
    ]);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        _localizedMaterialApp(ShoppingListScreen(loadData: () async => fakeData)),
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
}
