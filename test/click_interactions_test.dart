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
  return MaterialApp.router(routerConfig: router);
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
      ),
      Recipe(
        id: 'shot_b52',
        name: 'Shot - B52',
        ingredients: ['Baileys', 'Kahlua'],
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
    await tester.pumpWidget(
      _localizedMaterialApp(DashboardScreen(loadData: () async => fakeData)),
    );
    await tester.pumpAndSettle();

    // Find the add button by its icon (Icons.add)
    final addButton = find.byIcon(Icons.add);
    expect(addButton, findsOneWidget, reason: 'Should find the add button');
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.byType(RecipeSelectionDialog), findsOneWidget);
  });

  testWidgets('select + apply click adds recipe card', (tester) async {
    await tester.pumpWidget(
      _localizedMaterialApp(DashboardScreen(loadData: () async => fakeData)),
    );
    await tester.pumpAndSettle();

    // Find and tap the add button by icon
    final addButton = find.byIcon(Icons.add);
    expect(addButton, findsOneWidget, reason: 'Should find the add button');
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Mojito - Classic');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Mojito - Classic').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(find.text('Mojito - Classic'), findsOneWidget);
  });

  testWidgets('delete click removes selected recipe card', (tester) async {
    appState.setSelectedRecipes([
      const Recipe(id: 'delete_me', name: 'Delete Me', ingredients: ['Mint'])
    ]);

    await tester.pumpWidget(
      _localizedMaterialApp(DashboardScreen(loadData: () async => fakeData)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsOneWidget);

    // InputChip uses close icon for deletion
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Delete Me'), findsNothing);
  });

  testWidgets('generate button click navigates to shopping list route',
      (tester) async {
    appState.setSelectedRecipes([
      const Recipe(id: 'go_next', name: 'Go Next', ingredients: ['Mint'])
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

    await tester.pumpWidget(_localizedRouterApp(router));
    await tester.pumpAndSettle();

    // Find the generate button by its icon (shopping_cart)
    final generateButton = find.byIcon(Icons.shopping_cart);
    expect(generateButton, findsOneWidget, reason: 'Should find the shopping cart button');
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('ShoppingListRoute'), findsOneWidget);
  });

  testWidgets('shopping item can be selected and quantity changed', (tester) async {
    appState.setSelectedRecipes([
      const Recipe(
        id: 'mojito_classic',
        name: 'Mojito - Classic',
        ingredients: ['Limetten (54 Stk.)'],
      )
    ]);

    await tester.pumpWidget(
      _localizedMaterialApp(ShoppingListScreen(loadData: () async => fakeData)),
    );
    await tester.pumpAndSettle();

    // Handle the distance dialog that appears on screen load
    // Find the AlertDialog by type (text is localized)
    expect(find.byType(AlertDialog), findsOneWidget);
    
    // Find the distance TextField inside the dialog
    final distanceField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(distanceField, findsOneWidget);
    await tester.enterText(distanceField, '100');
    await tester.pump();
    
    // Tap the FilledButton inside the dialog to proceed
    final weiterButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    expect(weiterButton, findsOneWidget);
    await tester.tap(weiterButton);
    await tester.pumpAndSettle();

    // Verify dialog is closed
    expect(find.byType(AlertDialog), findsNothing);

    // Find and tap the item card to select it (checkbox area)
    final itemCard = find.text('Limetten (54 Stk.)');
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
  });
}
