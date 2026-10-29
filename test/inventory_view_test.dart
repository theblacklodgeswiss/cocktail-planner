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
  int skipped = 0,
  void Function(InventoryRow, List<StorageLocation>)? onArticleTap,
  VoidCallback? onCapture,
}) => InventoryView(
  watchStock: () => Stream.value(stock),
  watchLocations: () => Stream.value(locations),
  loadCatalog: () async => InventoryCatalog(catalog, skipped: skipped),
  originLabel: (o) => o == StockOrigin.order ? 'Auftrag' : 'Investition',
  onArticleTap: onArticleTap ?? (_, _) {},
  onCapture: onCapture ?? () {},
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
    /// [n] articles "Artikel 000" ..., every third one stocked at A and B.
    List<StockEntry> manyStock(int n) => [
      for (var i = 0; i < n; i += 3) ...[
        _e('m$i', 'a', StockOrigin.order, 2),
        _e('m$i', 'b', StockOrigin.investment, 1.5),
      ],
    ];
    List<({String id, String name})> manyCatalog(int n) => [
      for (var i = 0; i < n; i++)
        (
          id: 'm$i',
          name:
              '${String.fromCharCode(65 + i % 26)} Artikel mit einem sehr '
              'langen Namen ${i.toString().padLeft(3, '0')}',
        ),
    ];

    for (final n in [30, 300]) {
      for (final dark in [false, true]) {
        testWidgets('$n articles build and scroll at 360x640, 1.3 '
            '(dark: $dark)', (tester) async {
          _phone(tester);
          await _pump(
            tester,
            _app(
              _view(
                stock: manyStock(n),
                locations: [_a, _b],
                catalog: manyCatalog(n),
              ),
              dark: dark,
              textScale: 1.3,
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Alle'));
          await tester.pump();
          // Lazy: only the visible rows are built.
          expect(find.byType(InventoryListRow).evaluate().length, lessThan(n));
          for (var i = 0; i < 40; i++) {
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -2000),
            );
            await tester.pump();
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Last in name order.
          final lastId = (manyCatalog(
            n,
          )..sort((a, b) => a.name.compareTo(b.name))).last.id;
          final last = find.byKey(ValueKey('inventory-row $lastId'));
          expect(last, findsOneWidget);
          expect(tester.getRect(last).bottom, lessThanOrEqualTo(640));
        });
      }
    }

    for (final scale in [1.0, 1.3]) {
      testWidgets('capture button visible without scrolling (scale $scale)', (
        tester,
      ) async {
        _phone(tester);
        var captures = 0;
        await _pump(
          tester,
          _app(
            _view(
              stock: manyStock(30),
              locations: [_a, _b],
              catalog: manyCatalog(30),
              onCapture: () => captures++,
            ),
            textScale: scale,
          ),
        );
        final button = find.byKey(const ValueKey('inventory-capture'));
        expect(find.text('Bestand erfassen'), findsOneWidget);
        expect(find.text('per Sprache oder Text'), findsOneWidget);
        final rect = tester.getRect(button);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640 / 2));
        expect(rect.height, greaterThanOrEqualTo(44));
        await tester.tap(button);
        expect(captures, 1);
      });
    }

    testWidgets('row is 48-56 px high at scale 1.0', (tester) async {
      _phone(tester);
      await _pump(
        tester,
        _app(
          _view(
            stock: [_e('m1', 'a', StockOrigin.order, 2)],
            locations: [_a],
            catalog: [(id: 'm1', name: 'Rum'), (id: 'm2', name: 'Raki')],
          ),
        ),
      );
      await tester.tap(find.text('Alle'));
      await tester.pump();
      for (final e in find.byType(InventoryListRow).evaluate()) {
        final h = tester.getSize(find.byWidget(e.widget)).height;
        expect(h, inInclusiveRange(48, 56));
      }
    });

    testWidgets('summary line and default filter "Mit Bestand"', (
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
      expect(find.text('2 Artikel · 1 mit Bestand'), findsOneWidget);
      expect(find.text('Rum'), findsOneWidget);
      expect(find.text('Gin'), findsNothing, reason: 'default: Mit Bestand');
      await tester.tap(find.text('Alle'));
      await tester.pump();
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('Kein Bestand'), findsOneWidget);
      // Sorted by name, with letter headers.
      expect(find.text('G'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Gin')).dy,
        lessThan(tester.getTopLeft(find.text('Rum')).dy),
      );
      await tester.tap(find.text('Leer'));
      await tester.pump();
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('Rum'), findsNothing);
      await tester.tap(find.text('Mit Bestand'));
      await tester.pump();
      expect(find.text('Gin'), findsNothing);
      expect(find.text('Rum'), findsOneWidget);
    });

    testWidgets('no stock at all: default filter "Alle"', (tester) async {
      _phone(tester);
      await _pump(
        tester,
        _app(
          _view(
            locations: [_a],
            catalog: [(id: 'm1', name: 'Rum'), (id: 'm2', name: 'Gin')],
          ),
        ),
      );
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('Rum'), findsOneWidget);
    });

    testWidgets('subtitle shows only non-zero parts, per origin with a '
        'location pill', (tester) async {
      _phone(tester);
      await _pump(
        tester,
        _app(
          _view(
            stock: [
              _e('m1', 'a', StockOrigin.order, 2),
              _e('m1', 'b', StockOrigin.order, 1),
              _e('m1', 'b', StockOrigin.investment, 0.5),
              _e('m2', 'b', StockOrigin.order, 5),
            ],
            locations: [_a, _b],
            catalog: [(id: 'm1', name: 'Rum'), (id: 'm2', name: 'Gin')],
          ),
        ),
      );
      expect(find.text('A 2 · B 1,5'), findsOneWidget);
      expect(find.text('B 5'), findsOneWidget, reason: 'A 0 is left out');
      expect(find.text('3,5'), findsOneWidget, reason: 'total');

      await tester.tap(find.text('B').first);
      await tester.pump();
      expect(find.text('Auftrag 1 · Investition 0,5'), findsOneWidget);
      expect(find.text('Auftrag 5'), findsOneWidget);
      expect(find.text('1,5'), findsOneWidget, reason: 'total at B');

      await tester.tap(find.text('A'));
      await tester.pump();
      expect(find.text('Gin'), findsNothing, reason: 'no stock at A');
      expect(find.text('Auftrag 2'), findsOneWidget);
    });

    testWidgets('tapping a row opens the article', (tester) async {
      _phone(tester);
      InventoryRow? opened;
      await _pump(
        tester,
        _app(
          _view(
            stock: [_e('m1', 'a', StockOrigin.order, 2)],
            locations: [_a],
            catalog: [(id: 'm1', name: 'Rum')],
            onArticleTap: (row, _) => opened = row,
          ),
        ),
      );
      await tester.tap(find.text('Rum'));
      expect(opened?.materialId, 'm1');
    });

    testWidgets('empty catalog: empty state with Excel import for admins', (
      tester,
    ) async {
      _phone(tester);
      var imports = 0;
      var captures = 0;
      await _pump(
        tester,
        _app(_view(onImport: () => imports++, onCapture: () => captures++)),
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Noch keine Artikel im Katalog'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.byType(PrimaryButton),
        ),
      );
      expect(imports, 1);
      // Capturing stays reachable.
      await tester.tap(find.byKey(const ValueKey('inventory-capture')));
      expect(captures, 1);
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
      expect(find.text('Excel-Import'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.byType(PrimaryButton),
        ),
        findsNothing,
      );
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
              return const InventoryCatalog([(id: 'm2', name: 'Gin')]);
            },
            originLabel: (o) => o.name,
            onArticleTap: (_, _) {},
            onCapture: () {},
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
      await tester.tap(find.text('Alle'));
      await tester.pump();
      expect(find.text('Gin'), findsOneWidget);
      expect(find.text('Rum'), findsOneWidget);
    });

    testWidgets('unreadable catalog documents are reported, rest listed', (
      tester,
    ) async {
      _phone(tester);
      await _pump(
        tester,
        _app(
          _view(
            locations: [_a],
            catalog: [(id: 'm1', name: 'Rum')],
            skipped: 2,
          ),
        ),
      );
      expect(find.text('Rum'), findsOneWidget);
      expect(
        find.text('2 Artikel konnten nicht gelesen werden.'),
        findsOneWidget,
      );
    });
  });

  group('list logic', () {
    final rows = buildInventoryRows(
      [
        _e('m1', 'a', StockOrigin.order, 2),
        _e('m1', 'b', StockOrigin.investment, 1),
        _e('gone', 'x', StockOrigin.order, 4, name: 'Alter Gin'),
      ],
      [_a, _b],
      catalog: [
        (id: 'm1', name: 'Rum'),
        (id: 'm2', name: 'Gin'),
        (id: 'm3', name: '43 Licor'),
        (id: 'm4', name: 'Grappa'),
      ],
    );
    String label(StockOrigin o) =>
        o == StockOrigin.order ? 'Auftrag' : 'Investition';

    test('subtitle: non-zero only, unknown locations by id, null if empty', () {
      InventoryRow r(String id) => rows.firstWhere((r) => r.materialId == id);
      expect(
        inventoryRowSubtitle(r('m1'), locations: [_a, _b], originLabel: label),
        'A 2 · B 1',
      );
      expect(
        inventoryRowSubtitle(
          r('m1'),
          locations: [_a, _b],
          locationId: 'b',
          originLabel: label,
        ),
        'Investition 1',
      );
      expect(
        inventoryRowSubtitle(
          r('gone'),
          locations: [_a, _b],
          originLabel: label,
        ),
        'x 4',
      );
      expect(
        inventoryRowSubtitle(r('m2'), locations: [_a, _b], originLabel: label),
        isNull,
      );
    });

    test('default filter and "Leer"', () {
      expect(defaultInventoryFilter(rows), InventoryFilter.inStock);
      expect(
        defaultInventoryFilter([
          for (final r in rows)
            if (r.total == 0) r,
        ]),
        InventoryFilter.all,
      );
      expect(
        filterInventoryRows(
          rows,
          filter: InventoryFilter.empty,
        ).map((r) => r.materialId),
        ['m3', 'm2', 'm4'],
      );
      expect(
        filterInventoryRows(
          rows,
          filter: InventoryFilter.empty,
          locationId: 'a',
        ).map((r) => r.materialId),
        ['m3', 'gone', 'm2', 'm4'],
      );
    });

    test('letter groups with first/last flags', () {
      final items = groupInventoryRows(rows);
      final shape = [
        for (final i in items)
          switch (i) {
            InventoryLetterItem(:final letter) => letter,
            InventoryRowItem(:final row, :final first, :final last) =>
              '${row.materialName}${first ? '^' : ''}${last ? r'$' : ''}',
          },
      ];
      expect(shape, [
        '#',
        r'43 Licor^$',
        'A',
        r'Alter Gin^$',
        'G',
        'Gin^',
        r'Grappa$',
        'R',
        r'Rum^$',
      ]);
      expect(inventoryLetter('ärger'), 'Ä');
      expect(inventoryLetter(' '), '#');
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
