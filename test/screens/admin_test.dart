import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/recipe.dart';
import 'package:cocktail_planer/screens/admin/admin_screen.dart'
    show AdminTab, AdminTabPills;
import 'package:cocktail_planer/screens/admin/material_edit_sheet.dart';
import 'package:cocktail_planer/screens/admin/material_logic.dart';
import 'package:cocktail_planer/screens/admin/materials_view.dart';
import 'package:cocktail_planer/screens/admin/recipe_edit_sheet.dart';
import 'package:cocktail_planer/screens/admin/recipes_view.dart';
import 'package:cocktail_planer/screens/settings/admin_settings_view.dart';
import 'package:cocktail_planer/screens/settings/settings_view.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_harness.dart';

AdminSettingsView settingsView({
  bool isGenerating = false,
  AdminStatus? generateStatus,
}) => AdminSettingsView(
  threshold: 400,
  claudeConfigured: true,
  microsoftLoggedIn: false,
  isImporting: false,
  onImport: () {},
  isEnriching: false,
  enrichStatus: null,
  onEnrich: () {},
  isGenerating: isGenerating,
  generateStatus: generateStatus,
  onGenerate: (_) {},
  onSave: (_) async {},
);

MaterialRecord rec(String id, String name) => (
  id: id,
  item: MaterialItem(
    unit: 'Stk',
    name: name,
    price: 1.5,
    currency: 'CHF',
    note: '',
  ),
);

MaterialsView materialsView({
  List<MaterialRecord>? items,
  Future<bool> Function(String?, MaterialEditResult)? onSave,
  Future<bool> Function(String)? onDelete,
  bool fixed = false,
}) => MaterialsView(
  title: 'Inventar verwalten',
  header: const Text('pills'),
  isFixedValue: fixed,
  items: items ?? [rec('1', 'Vodka'), rec('2', 'Rum')],
  loading: false,
  errorMessage: null,
  onRetry: () {},
  onSave: onSave ?? (_, _) async => true,
  onDelete: onDelete ?? (_) async => true,
  onReorder: (_) async {},
);

RecipesView recipesView({
  required Future<bool> Function(String?, RecipeEditResult) onSave,
}) => RecipesView(
  title: 'Inventar verwalten',
  header: const Text('pills'),
  items: [
    (
      id: 'm',
      item: const Recipe(
        id: 'm',
        name: 'Mojito',
        ingredients: ['Rum'],
        ingredientAmounts: {'Rum': '40ml'},
      ),
    ),
  ],
  loading: false,
  errorMessage: null,
  onRetry: () {},
  loadMaterials: () async => ['Rum', 'Minze'],
  onAddIngredient: (_) async => true,
  onSave: onSave,
  onDelete: (_) async => true,
);

void main() {
  setUpAll(initAdminTest);

  group('AI recipe input', () {
    Future<ValueNotifier<AdminSettingsView>> pumpView(
      WidgetTester tester,
    ) async {
      phone(tester, h: 3000);
      final view = ValueNotifier(settingsView());
      addTearDown(view.dispose);
      await pumpAdmin(
        tester,
        adminApp(
          ValueListenableBuilder<AdminSettingsView>(
            valueListenable: view,
            builder: (_, v, _) => v,
          ),
        ),
      );
      return view;
    }

    testWidgets('is cleared after a successful generate and save', (
      tester,
    ) async {
      final view = await pumpView(tester);
      final field = find.byType(TextField).last;
      await tester.enterText(field, 'Aperol Spritz');
      view.value = settingsView(isGenerating: true);
      await tester.pump();
      view.value = settingsView(generateStatus: const AdminStatus('ok', false));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    });

    testWidgets('is kept after an error so it can be retried', (tester) async {
      final view = await pumpView(tester);
      final field = find.byType(TextField).last;
      await tester.enterText(field, 'Aperol Spritz');
      view.value = settingsView(isGenerating: true);
      await tester.pump();
      view.value = settingsView(
        generateStatus: const AdminStatus('boom', true),
      );
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'Aperol Spritz');
    });
  });

  group('materials', () {
    testWidgets('search filters the list', (tester) async {
      phone(tester);
      await pumpAdmin(tester, adminApp(materialsView()));
      expect(find.text('Vodka'), findsOneWidget);
      expect(find.text('Rum'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'vod');
      await tester.pump();
      expect(find.text('Vodka'), findsOneWidget);
      expect(find.text('Rum'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Keine Artikel gefunden'), findsOneWidget);
    });

    testWidgets('add via FAB saves through onSave with a null docId', (
      tester,
    ) async {
      phone(tester);
      String? gotId = 'unset';
      MaterialEditResult? got;
      await pumpAdmin(
        tester,
        adminApp(
          materialsView(
            onSave: (id, r) async {
              gotId = id;
              got = r;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Neuer Artikel'));
      await settleAdmin(tester);
      await tester.enterText(find.byKey(const Key('material-name')), 'Gin');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Speichern'));
      await settleAdmin(tester);
      expect(gotId, isNull);
      expect(got!.name, 'Gin');
      expect(got!.currency, 'CHF');
      expect(find.text('Gespeichert!'), findsOneWidget);
    });

    testWidgets('empty name is not saved', (tester) async {
      phone(tester);
      var calls = 0;
      await pumpAdmin(
        tester,
        adminApp(
          materialsView(
            onSave: (_, _) async {
              calls++;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Neuer Artikel'));
      await settleAdmin(tester);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Speichern'));
      await settleAdmin(tester);
      expect(calls, 0);
    });

    for (final dark in [false, true]) {
      testWidgets('edit sheet has no overflow with keyboard 300, text 1.3 '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        phone(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await pumpAdmin(
          tester,
          adminApp(
            materialsView(),
            textScale: 1.3,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
          ),
        );
        await tester.tap(find.text('Vodka'));
        await settleAdmin(tester);
        await tester.tap(find.byKey(const Key('material-name')));
        await settleAdmin(tester);
        expect(tester.takeException(), isNull);
        final button = find.widgetWithText(PrimaryButton, 'Speichern');
        expect(button, findsOneWidget);
        final rect = tester.getRect(button);
        expect(rect.bottom, lessThanOrEqualTo(640 - 300));
        expect(rect.top, greaterThanOrEqualTo(0));
      });
    }

    testWidgets('delete asks first and calls onDelete only on confirm', (
      tester,
    ) async {
      phone(tester);
      final deleted = <String>[];
      await pumpAdmin(
        tester,
        adminApp(
          materialsView(
            items: [rec('1', 'Vodka')],
            onDelete: (id) async {
              deleted.add(id);
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Löschen'));
      await settleAdmin(tester);
      expect(deleted, isEmpty);
      expect(find.text('Artikel löschen?'), findsOneWidget);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Löschen'));
      await settleAdmin(tester);
      expect(deleted, ['1']);
    });

    testWidgets('a failed delete keeps the sheet open with an error and '
        'a retry', (tester) async {
      phone(tester);
      var calls = 0;
      await pumpAdmin(
        tester,
        adminApp(
          materialsView(
            items: [rec('1', 'Vodka')],
            onDelete: (id) async => ++calls > 1,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Löschen'));
      await settleAdmin(tester);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Löschen'));
      await settleAdmin(tester);
      expect(calls, 1);
      expect(find.text('Artikel löschen?'), findsOneWidget);
      expect(find.text('Fehler beim Löschen'), findsOneWidget);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Erneut versuchen'));
      await settleAdmin(tester);
      expect(calls, 2);
      expect(find.text('Artikel löschen?'), findsNothing);
    });

    testWidgets('fixed values render reorderable', (tester) async {
      phone(tester);
      await pumpAdmin(tester, adminApp(materialsView(fixed: true)));
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    });
  });

  group('recipes', () {
    testWidgets('two steps: name then ingredients with amounts', (
      tester,
    ) async {
      phone(tester);
      String? gotId = 'unset';
      RecipeEditResult? got;
      await pumpAdmin(
        tester,
        adminApp(
          recipesView(
            onSave: (id, r) async {
              gotId = id;
              got = r;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Neues Rezept'));
      await settleAdmin(tester);
      expect(find.text('1 von 2'), findsOneWidget);
      // Empty name: stays on step 1 with a hint.
      await tester.tap(find.widgetWithText(PrimaryButton, 'Weiter'));
      await settleAdmin(tester);
      expect(find.text('Bitte einen Namen eingeben'), findsOneWidget);
      expect(find.text('1 von 2'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('recipe-name')), 'Daiquiri');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Weiter'));
      await settleAdmin(tester);
      expect(find.text('2 von 2'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(RecipeEditForm),
          matching: find.text('Rum'),
        ),
      );
      await settleAdmin(tester);
      await tester.enterText(find.byType(TextField).last, '50ml');
      await tester.tap(find.widgetWithText(PrimaryButton, 'Speichern'));
      await settleAdmin(tester);
      expect(gotId, isNull);
      expect(got!.name, 'Daiquiri');
      expect(got!.ingredients, ['Rum']);
      expect(got!.amounts, {'Rum': '50ml'});
    });

    for (final dark in [false, true]) {
      testWidgets('step 2 has no overflow with keyboard 300, text 1.3 '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        phone(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await pumpAdmin(
          tester,
          adminApp(
            recipesView(onSave: (_, _) async => true),
            textScale: 1.3,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
          ),
        );
        await tester.tap(find.text('Mojito'));
        await settleAdmin(tester);
        await tester.tap(find.widgetWithText(PrimaryButton, 'Weiter'));
        await settleAdmin(tester);
        await tester.tap(find.byType(TextField).last);
        await settleAdmin(tester);
        expect(tester.takeException(), isNull);
        expect(find.widgetWithText(PrimaryButton, 'Speichern'), findsOneWidget);
      });
    }
  });

  group('tabs and gates', () {
    testWidgets('tab pills report the tapped tab', (tester) async {
      phone(tester);
      AdminTab? got;
      await pumpAdmin(
        tester,
        adminApp(
          Scaffold(
            body: AdminTabPills(
              current: AdminTab.materials,
              onChanged: (t) => got = t,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rezepte'));
      expect(got, AdminTab.recipes);
    });

    testWidgets('non-admin sees no admin entry in settings', (tester) async {
      phone(tester, h: 3000);
      await pumpAdmin(
        tester,
        adminApp(
          SettingsView(
            appVersion: '1',
            buildNumber: '1',
            userId: 'u',
            isAdmin: false,
            canManageUsers: false,
            themeMode: ThemeMode.system,
            onThemeMode: (_) {},
            onEditCompany: () {},
          ),
        ),
      );
      expect(find.text('Mitarbeiter verwalten'), findsNothing);
      expect(find.text('Benutzer verwalten'), findsNothing);
    });
  });
}
