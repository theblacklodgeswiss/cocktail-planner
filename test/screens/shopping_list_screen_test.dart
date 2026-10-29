import 'package:cocktail_planer/models/cocktail_data.dart';
import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/recipe.dart';
import 'package:cocktail_planer/screens/shopping_list/shopping_list_screen.dart';
import 'package:cocktail_planer/state/app_state.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(
  Widget home, {
  ThemeData? theme,
  double textScale = 1,
  double keyboard = 0,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('de'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('de'),
    startLocale: const Locale('de'),
    child: Builder(
      builder: (context) => MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
}

Future<void> pumpApp(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

final _data = CocktailData(
  materials: const [
    MaterialItem(
      unit: 'Stk',
      name: 'Limetten (54 Stk.)',
      price: 14,
      currency: 'CHF',
      note: 'Prodega',
    ),
    MaterialItem(
      unit: '0.7L',
      name: 'Baileys',
      price: 14,
      currency: 'CHF',
      note: 'Kaufland',
    ),
  ],
  recipes: const [],
  fixedValues: const [
    MaterialItem(
      unit: 'Stk',
      name: 'BL Box',
      price: 10,
      currency: 'CHF',
      note: 'BlackLodge',
      category: 'bring',
    ),
  ],
);

const _setup = (
  orderName: 'Test',
  personCount: 50,
  drinkerType: 'normal',
  currency: 'CHF',
  distanceKm: 0,
  phoneNumber: null,
  address: null,
  eventDate: null,
  eventTime: null,
  serviceType: 'cocktail_barservice',
  barDrinks: <String>[],
  alcoholPurchase: <String>[],
  additionalServices: <String>[],
  remarks: null,
);

Widget screen({ThemeData? theme, double textScale = 1, double keyboard = 0}) =>
    app(
      ShoppingListScreen(loadData: () async => _data, orderSetup: _setup),
      theme: theme,
      textScale: textScale,
      keyboard: keyboard,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    appState.setSelectedRecipes(const [
      Recipe(
        id: 'mojito',
        name: 'Mojito - Classic',
        ingredients: ['Limetten (54 Stk.)'],
        type: 'cocktail',
      ),
    ]);
  });

  testWidgets('cocktail step shows the title, one card and next', (
    tester,
  ) async {
    await pumpApp(tester, screen());
    expect(find.text('Mojito - Classic'), findsOneWidget);
    expect(find.text('Limetten (54 Stk.)'), findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);
    expect(find.text('Zurück'), findsNothing);
  });

  testWidgets('plus changes the quantity and the running total', (
    tester,
  ) async {
    await pumpApp(tester, screen());
    await tester.tap(find.byKey(const Key('quantity-plus')).first);
    await tester.pump();
    expect(find.text('1'), findsWidgets);
    // 1 x 14.00 shown on the card and in the running total.
    expect(find.textContaining('14.00'), findsWidgets);
  });

  testWidgets('next walks to the summary where save is the main action', (
    tester,
  ) async {
    await pumpApp(tester, screen());
    await tester.tap(find.byKey(const Key('quantity-plus')).first);
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Weiter'));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('Zusammenfassung'), findsOneWidget);
    expect(find.text('Angebot speichern'), findsOneWidget);
    expect(find.text('Weiter'), findsNothing);
    expect(find.text('Limetten (54 Stk.)'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360x640, scale 1.3, keyboard (dark=$dark)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        screen(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          textScale: 1.3,
          keyboard: 300,
        ),
      );
      final field = find.byKey(const Key('quantity-field')).first;
      await tester.ensureVisible(field);
      await tester.pump();
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, '3');
      await tester.pump();
      // The focused field sits above the keyboard (640 - 300).
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(340));
      expect(tester.takeException(), isNull);
    });
  }
}
