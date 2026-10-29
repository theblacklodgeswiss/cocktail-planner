import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/inventory_article_editor.dart';
import 'package:cocktail_planer/screens/inventory/inventory_rows.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/app_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = StorageLocation(id: 'a', name: 'Biri');
const _b = StorageLocation(id: 'b', name: 'Mario');
const _c = StorageLocation(id: 'c', name: 'Lager Ost mit langem Namen');

InventoryRow _row() => buildInventoryRows(
  const [
    StockEntry(
      id: 'm1|a|order',
      materialId: 'm1',
      materialName: 'Bacardi',
      locationId: 'a',
      origin: StockOrigin.order,
      quantity: 3,
    ),
    StockEntry(
      id: 'm1|b|investment',
      materialId: 'm1',
      materialName: 'Bacardi',
      locationId: 'b',
      origin: StockOrigin.investment,
      quantity: 1.5,
      note: 'angebrochen',
    ),
  ],
  [_a, _b, _c],
).single;

String _label(StockOrigin o) =>
    o == StockOrigin.order ? 'Auftrag' : 'Investition';

Widget _app(Widget Function(BuildContext) opener, {bool dark = false}) =>
    EasyLocalization(
      supportedLocales: const [Locale('de'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('de'),
      startLocale: const Locale('de'),
      child: Builder(
        builder: (context) => MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showAppSheet<void>(
                    context,
                    builder: (_) => opener(context),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(String location, StockOrigin o) => find.descendant(
  of: find.byKey(ValueKey('stepper $location ${o.name}')),
  matching: find.byType(TextField),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('changedQuantities lists only differing cells', () {
    final row = _row();
    expect(
      changedQuantities(row.perLocation, {
        'a': {StockOrigin.order: 3, StockOrigin.investment: 0},
        'b': {StockOrigin.order: 0, StockOrigin.investment: 2},
      }),
      [(locationId: 'b', origin: StockOrigin.investment, quantity: 2.0)],
    );
  });

  for (final dark in [false, true]) {
    testWidgets('saving reports only the changed values (dark: $dark)', (
      tester,
    ) async {
      final saved = <QuantityChange>[];
      String? savedNote;
      await _open(
        tester,
        _app(
          (_) => InventoryArticleEditor(
            row: _row(),
            locations: const [_a, _b, _c],
            originLabel: _label,
            saveQuantity: (c) async => saved.add(c),
            saveNote: (note) async => savedNote = note,
            onHistory: () {},
            onTake: () {},
          ),
          dark: dark,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Bacardi'), findsOneWidget);
      expect(find.text('Mario'), findsOneWidget);

      // Typed with a comma, and a step with "+".
      await tester.ensureVisible(_field('b', StockOrigin.investment));
      await tester.enterText(_field('b', StockOrigin.investment), '2,5');
      final plus = find.descendant(
        of: find.byKey(const ValueKey('stepper a order')),
        matching: find.bySemanticsLabel('Auftrag erhöhen'),
      );
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(_field('a', StockOrigin.order))
            .controller!
            .text,
        '4',
      );
      // Every stepper button is a 44 px target.
      expect(tester.getSize(plus).height, greaterThanOrEqualTo(44));

      final save = find.text('Speichern');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved, [
        (locationId: 'a', origin: StockOrigin.order, quantity: 4.0),
        (locationId: 'b', origin: StockOrigin.investment, quantity: 2.5),
      ]);
      expect(savedNote, isNull, reason: 'note unchanged');
      expect(find.text('Speichern'), findsNothing, reason: 'sheet closed');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('invalid quantity disables saving; "−" stops at 0', (
    tester,
  ) async {
    var saves = 0;
    await _open(
      tester,
      _app(
        (_) => InventoryArticleEditor(
          row: _row(),
          locations: const [_a],
          originLabel: _label,
          saveQuantity: (_) async => saves++,
          saveNote: (_) async => saves++,
          onHistory: () {},
          onTake: () {},
        ),
      ),
    );
    final minus = find.descendant(
      of: find.byKey(const ValueKey('stepper a investment')),
      matching: find.bySemanticsLabel('Investition verringern'),
    );
    await tester.tap(minus);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(_field('a', StockOrigin.investment))
          .controller!
          .text,
      '0',
    );
    await tester.enterText(_field('a', StockOrigin.order), 'abc');
    await tester.pump();
    final save = find.text('Speichern');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('Speichern'), findsOneWidget);
  });

  testWidgets('note change is reported; "Verlauf" closes and opens history', (
    tester,
  ) async {
    String? savedNote;
    var history = 0;
    await _open(
      tester,
      _app(
        (_) => InventoryArticleEditor(
          row: _row(),
          locations: const [_a, _b],
          originLabel: _label,
          saveQuantity: (_) async {},
          saveNote: (note) async => savedNote = note,
          onHistory: () => history++,
          onTake: () {},
        ),
      ),
    );
    final note = find.widgetWithText(TextField, 'angebrochen');
    await tester.ensureVisible(note);
    await tester.enterText(note, 'leer bald');
    final save = find.text('Speichern');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(savedNote, 'leer bald');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final verlauf = find.text('Verlauf');
    await tester.ensureVisible(verlauf);
    await tester.tap(verlauf);
    await tester.pumpAndSettle();
    expect(history, 1);
    expect(find.text('Speichern'), findsNothing);
  });

  testWidgets('a failure part-way keeps the sheet open; the retry sends only '
      'unsaved cells', (tester) async {
    final sent = <QuantityChange>[];
    var calls = 0;
    await _open(
      tester,
      _app(
        (_) => InventoryArticleEditor(
          row: _row(),
          locations: const [_a, _b],
          originLabel: _label,
          saveQuantity: (c) async {
            calls++;
            if (calls == 2) throw StateError('offline');
            sent.add(c);
          },
          saveNote: (_) async {},
          onHistory: () {},
          onTake: () {},
        ),
      ),
    );
    await tester.enterText(_field('a', StockOrigin.order), '5');
    await tester.ensureVisible(_field('b', StockOrigin.order));
    await tester.enterText(_field('b', StockOrigin.order), '7');
    final save = find.text('Speichern');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(sent, [(locationId: 'a', origin: StockOrigin.order, quantity: 5.0)]);
    expect(find.text('Speichern'), findsOneWidget, reason: 'still open');
    expect(
      find.text('Speichern fehlgeschlagen. Bitte versuche es erneut.'),
      findsOneWidget,
    );

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(sent, [
      (locationId: 'a', origin: StockOrigin.order, quantity: 5.0),
      (locationId: 'b', origin: StockOrigin.order, quantity: 7.0),
    ]);
    expect(find.text('Speichern'), findsNothing);
  });

  testWidgets('take: default origin is the one with stock', (tester) async {
    final row = buildInventoryRows(
      const [
        StockEntry(
          id: 'm1|a|investment',
          materialId: 'm1',
          materialName: 'Bacardi',
          locationId: 'a',
          origin: StockOrigin.investment,
          quantity: 2,
        ),
      ],
      [_a],
    ).single;
    (String, StockOrigin, double)? taken;
    await _open(
      tester,
      _app(
        (_) => InventoryTakeSheet(
          row: row,
          locations: const [_a],
          originLabel: _label,
          onTake: (l, o, q) async => taken = (l, o, q),
        ),
      ),
    );
    expect(find.text('Nur 2 vorhanden'), findsWidgets);
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Entnehmen').last);
    await tester.pumpAndSettle();
    expect(taken, ('a', StockOrigin.investment, 1.0));
  });

  testWidgets('take: more than available is rejected', (tester) async {
    (String, StockOrigin, double)? taken;
    await _open(
      tester,
      _app(
        (_) => InventoryTakeSheet(
          row: _row(),
          locations: const [_a, _b],
          originLabel: _label,
          onTake: (l, o, q) async => taken = (l, o, q),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Entnehmen').last);
    await tester.pumpAndSettle();
    expect(taken, isNull);
    expect(find.text('Nur 3 vorhanden'), findsWidgets);

    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Entnehmen').last);
    await tester.pumpAndSettle();
    expect(taken, ('a', StockOrigin.order, 2.0));
  });
}
