import 'dart:async';

import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/inventory_rows.dart';
import 'package:cocktail_planer/screens/inventory/inventory_view.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

StockEntry _e(
  String material,
  String location,
  StockOrigin origin,
  double q, {
  String? name,
  String? note,
}) => StockEntry(
  id: StockEntry.buildId(material, location, origin),
  materialId: material,
  materialName: name ?? material,
  locationId: location,
  origin: origin,
  quantity: q,
  note: note,
);

const _a = StorageLocation(id: 'a', name: 'A');
const _b = StorageLocation(id: 'b', name: 'B');

Widget _app(Widget home, {bool dark = false, double textScale = 1}) =>
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
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    );

/// The view with fixed data (streams emit once, catalog resolves at once).
InventoryView _view({
  List<StockEntry> stock = const [],
  List<StorageLocation> locations = const [],
  List<({String id, String name})> catalog = const [],
  VoidCallback? onImport,
  void Function(InventoryRow, StorageLocation, StockOrigin)? onCellTap,
}) => InventoryView(
  watchStock: () => Stream.value(stock),
  watchLocations: () => Stream.value(locations),
  loadCatalog: () async => catalog,
  originLabel: (o) => o == StockOrigin.order ? 'Auftrag' : 'Investition',
  onArticleTap: (_, _) {},
  onCellTap: onCellTap ?? (_, _, _) {},
  onManageLocations: () {},
  onImport: onImport,
);

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('view', () {
    const c = StorageLocation(id: 'c', name: 'Lager Ost mit langem Namen');

    for (final dark in [false, true]) {
      testWidgets('card with 3 locations fits 360 px at 1.3 (dark: $dark)', (
        tester,
      ) async {
        _phone(tester);
        await _pump(
          tester,
          _app(
            _view(
              stock: [
                _e('m1', 'a', StockOrigin.order, 12.5),
                _e('m1', 'b', StockOrigin.investment, 1000),
                _e('m1', 'c', StockOrigin.order, 3, note: 'angebrochen'),
              ],
              locations: [_a, _b, c],
              catalog: [(id: 'm1', name: 'Havana Club Añejo 7 Años 0,7 l')],
            ),
            dark: dark,
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(InventoryCard), findsOneWidget);
        expect(find.text('1015,5'), findsOneWidget, reason: 'total');
        expect(find.text('Lager Ost mit langem Namen'), findsNWidgets(2));
        // Location pills (more than one location) and the article card.
        expect(find.text('Alle Lagerorte'), findsOneWidget);
        // Every quantity cell is a 44 px target.
        final cells = find.bySemanticsLabel(RegExp('Menge ändern'));
        expect(cells, findsNWidgets(6));
        for (final e in cells.evaluate()) {
          final size = tester.getSize(find.byWidget(e.widget));
          expect(size.height, greaterThanOrEqualTo(44));
        }
      });
    }

    testWidgets('catalog article without stock is listed with 0', (
      tester,
    ) async {
      _phone(tester);
      await _pump(
        tester,
        _app(
          _view(
            stock: [_e('m1', 'a', StockOrigin.order, 2)],
            locations: [_a],
            catalog: [(id: 'm1', name: 'Rum'), (id: 'm2', name: 'Gin')],
          ),
        ),
      );
      expect(find.byType(InventoryCard), findsNWidgets(2));
      // Sorted by name.
      expect(
        tester.getTopLeft(find.text('Gin')).dy,
        lessThan(tester.getTopLeft(find.text('Rum')).dy),
      );
      final gin = find.ancestor(
        of: find.text('Gin'),
        matching: find.byType(InventoryCard),
      );
      expect(find.descendant(of: gin, matching: find.text('0')), findsWidgets);
    });

    testWidgets('filter "Mit Bestand" hides articles without stock', (
      tester,
    ) async {
      _phone(tester);
      await _pump(
        tester,
        _app(
          _view(
            stock: [_e('m1', 'a', StockOrigin.order, 2)],
            locations: [_a],
            catalog: [(id: 'm1', name: 'Rum'), (id: 'm2', name: 'Gin')],
          ),
        ),
      );
      expect(find.text('Gin'), findsOneWidget);
      await tester.tap(find.text('Mit Bestand'));
      await tester.pump();
      expect(find.text('Gin'), findsNothing);
      expect(find.text('Rum'), findsOneWidget);
    });

    testWidgets('location pill limits cards and "Mit Bestand"', (tester) async {
      _phone(tester);
      await _pump(
        tester,
        _app(
          _view(
            stock: [
              _e('m1', 'a', StockOrigin.order, 2),
              _e('m2', 'b', StockOrigin.order, 5),
            ],
            locations: [_a, _b],
            catalog: [(id: 'm1', name: 'Rum'), (id: 'm2', name: 'Gin')],
          ),
        ),
      );
      await tester.tap(find.text('Mit Bestand'));
      await tester.pump();
      await tester.tap(find.text('B').first);
      await tester.pump();
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('Rum'), findsNothing);
    });

    testWidgets('empty catalog: empty state with Excel import for admins', (
      tester,
    ) async {
      _phone(tester);
      var imports = 0;
      await _pump(tester, _app(_view(onImport: () => imports++)));
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Noch keine Artikel im Katalog'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.byType(PrimaryButton),
        ),
      );
      expect(imports, 1);
    });

    testWidgets('empty catalog: hint, no import, for employees', (
      tester,
    ) async {
      _phone(tester);
      await _pump(tester, _app(_view()));
      expect(
        find.text('Ein Admin kann die Materialliste per Excel importieren.'),
        findsOneWidget,
      );
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('catalog failure keeps the stock list, with a retry', (
      tester,
    ) async {
      _phone(tester);
      var calls = 0;
      await _pump(
        tester,
        _app(
          InventoryView(
            watchStock: () => Stream.value([
              _e('m1', 'a', StockOrigin.order, 2, name: 'Rum'),
            ]),
            watchLocations: () => Stream.value([_a]),
            loadCatalog: () async {
              calls++;
              if (calls == 1) throw TimeoutException('slow');
              return [(id: 'm2', name: 'Gin')];
            },
            originLabel: (o) => o.name,
            onArticleTap: (_, _) {},
            onCellTap: (_, _, _) {},
            onManageLocations: () {},
          ),
        ),
      );
      expect(find.text('Rum'), findsOneWidget);
      expect(
        find.textContaining('Artikelkatalog konnte nicht geladen'),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Erneut versuchen'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('Rum'), findsOneWidget);
    });

    testWidgets('tapping a quantity reports location and origin', (
      tester,
    ) async {
      _phone(tester);
      (String, StockOrigin)? tapped;
      await _pump(
        tester,
        _app(
          _view(
            locations: [_a],
            catalog: [(id: 'm1', name: 'Rum')],
            onCellTap: (_, l, o) => tapped = (l.id, o),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel(RegExp('A, Investition')));
      expect(tapped, ('a', StockOrigin.investment));
    });
  });

  test('sums over locations and origins', () {
    final rows = buildInventoryRows(
      [
        _e('m1', 'a', StockOrigin.order, 1),
        _e('m1', 'a', StockOrigin.investment, 2),
        _e('m1', 'b', StockOrigin.order, 4),
      ],
      [_a, _b],
    );
    expect(rows, hasLength(1));
    expect(rows.single.total, 7);
    expect(rows.single.perLocation['a']![StockOrigin.investment], 2);
    expect(rows.single.perLocation['b']![StockOrigin.order], 4);
    expect(rows.single.perLocation['b']![StockOrigin.investment], 0);
  });

  test('Excel example 2.8 + 10 = 12.8', () {
    final rows = buildInventoryRows(
      [
        _e('m1', 'a', StockOrigin.order, 2.8),
        _e('m1', 'b', StockOrigin.investment, 10),
      ],
      [_a, _b],
    );
    expect(rows.single.total, closeTo(12.8, 1e-9));
  });

  test('catalog article without stock yields a zero row', () {
    final rows = buildInventoryRows(
      [],
      [_a],
      catalog: [(id: 'm9', name: 'Rum')],
    );
    expect(rows.single.materialName, 'Rum');
    expect(rows.single.total, 0);
    expect(rows.single.perLocation['a']![StockOrigin.order], 0);
  });

  test('orphaned stock entry still yields a row with its stored name', () {
    final rows = buildInventoryRows(
      [_e('gone', 'a', StockOrigin.order, 3, name: 'Old Gin')],
      [_a],
      catalog: [(id: 'm9', name: 'Rum')],
    );
    final orphan = rows.firstWhere((r) => r.materialId == 'gone');
    expect(orphan.materialName, 'Old Gin');
    expect(orphan.total, 3);
  });

  test('catalog name wins over stored name after a rename', () {
    final rows = buildInventoryRows(
      [_e('m1', 'a', StockOrigin.order, 1, name: 'Old')],
      [_a],
      catalog: [(id: 'm1', name: 'New')],
    );
    expect(rows.single.materialName, 'New');
  });

  test('note is passed through', () {
    final rows = buildInventoryRows(
      [
        _e('m1', 'a', StockOrigin.order, 1),
        _e('m1', 'b', StockOrigin.order, 1, note: 'angebrochen'),
      ],
      [_a, _b],
    );
    expect(rows.single.note, 'angebrochen');
  });

  test('formatQuantity uses comma and drops trailing zero', () {
    expect(formatQuantity(2.8), '2,8');
    expect(formatQuantity(12.8), '12,8');
    expect(formatQuantity(10), '10');
    expect(formatQuantity(2.8 + 10), '12,8');
  });

  test('parseQuantity handles comma, dot, empty, negative, garbage', () {
    expect(parseQuantity('2,8', allowZero: false), 2.8);
    expect(parseQuantity('2.8', allowZero: false), 2.8);
    expect(parseQuantity('', allowZero: true), isNull);
    expect(parseQuantity('-1', allowZero: true), isNull);
    expect(parseQuantity('abc', allowZero: true), isNull);
    expect(parseQuantity('0', allowZero: true), 0);
    expect(parseQuantity('0', allowZero: false), isNull);
  });

  test('shortOrderId shortens long ids', () {
    expect(shortOrderId('abcdefghij'), 'abcdef');
    expect(shortOrderId('abc'), 'abc');
  });
}
