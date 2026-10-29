import 'dart:async';

import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/inventory_view.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home) => EasyLocalization(
  supportedLocales: const [Locale('de'), Locale('en')],
  path: 'assets/translations',
  fallbackLocale: const Locale('de'),
  startLocale: const Locale('de'),
  child: Builder(
    builder: (context) => MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: Scaffold(body: home),
    ),
  ),
);

Future<void> pumpApp(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

/// Fake repository streams; every subscription gets fresh controllers.
class FakeStreams {
  final stock = <StreamController<List<StockEntry>>>[];
  final locations = <StreamController<List<StorageLocation>>>[];
  var catalogCalls = 0;

  Stream<List<StockEntry>> watchStock() {
    final c = StreamController<List<StockEntry>>();
    stock.add(c);
    return c.stream;
  }

  Stream<List<StorageLocation>> watchLocations() {
    final c = StreamController<List<StorageLocation>>();
    locations.add(c);
    return c.stream;
  }

  Future<InventoryCatalog> loadCatalog() async {
    catalogCalls++;
    return const InventoryCatalog([(id: 'm9', name: 'Grenadine')]);
  }

  void close() {
    for (final c in [...stock, ...locations]) {
      c.close();
    }
  }
}

InventoryView view(FakeStreams f, {Duration? timeout}) => InventoryView(
  watchStock: f.watchStock,
  watchLocations: f.watchLocations,
  loadCatalog: f.loadCatalog,
  originLabel: (o) => o.name,
  onArticleTap: (_, _) {},
  onCapture: () {},
  onManageLocations: () {},
  timeout: timeout ?? inventoryLoadTimeout,
);

const _loc = StorageLocation(id: 'l1', name: 'Keller');
const _entry = StockEntry(
  id: 'm1|l1|order',
  materialId: 'm1',
  materialName: 'Rum',
  locationId: 'l1',
  origin: StockOrigin.order,
  quantity: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('loading until the stock arrives', (tester) async {
    final f = FakeStreams();
    addTearDown(f.close);
    await pumpApp(tester, app(view(f)));
    expect(find.byType(LoadingState), findsOneWidget);
    f.stock.last.add([_entry]);
    await tester.pump();
    expect(find.byType(InventoryListRow), findsWidgets);
  });

  testWidgets('rows, even before the locations arrive', (tester) async {
    final f = FakeStreams();
    addTearDown(f.close);
    await pumpApp(tester, app(view(f)));
    f.stock.last.add([_entry]);
    await tester.pump();
    expect(find.byType(InventoryListRow), findsWidgets);
    expect(find.text('Rum'), findsOneWidget);
    expect(find.text('Keller'), findsNothing);

    f.locations.last.add([_loc]);
    await tester.pump();
    expect(find.text('Keller 3'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(f.catalogCalls, 1, reason: 'catalog is loaded once, on start');
  });

  testWidgets('no stock -> catalog articles with 0, not an error', (
    tester,
  ) async {
    final f = FakeStreams();
    addTearDown(f.close);
    await pumpApp(tester, app(view(f)));
    f.stock.last.add([]);
    f.locations.last.add([]);
    await tester.pump();
    expect(find.text('Grenadine'), findsOneWidget);
    expect(find.byType(LoadingState), findsNothing);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('search filters by name', (tester) async {
    final f = FakeStreams();
    addTearDown(f.close);
    await pumpApp(tester, app(view(f)));
    f.stock.last.add([_entry]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'gren');
    await tester.pump();
    expect(find.text('Grenadine'), findsOneWidget);
    expect(find.text('Rum'), findsNothing);
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(find.text('Keine Artikel gefunden'), findsOneWidget);
    expect(f.catalogCalls, 1);
  });

  testWidgets('error -> ErrorState with the cause; retry re-subscribes', (
    tester,
  ) async {
    final f = FakeStreams();
    addTearDown(f.close);
    await pumpApp(tester, app(view(f)));
    f.locations.last.addError(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ),
    );
    await tester.pump();
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Daten konnten nicht geladen werden.'), findsOneWidget);
    expect(find.text('Keine Berechtigung (permission-denied)'), findsOneWidget);

    expect(f.stock, hasLength(1));
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pump();
    expect(f.stock, hasLength(2), reason: 'fresh stock subscription');
    expect(f.locations, hasLength(2), reason: 'fresh locations subscription');
    expect(find.byType(LoadingState), findsOneWidget);

    f.stock.last.add([_entry]);
    f.locations.last.add([_loc]);
    await tester.pump();
    expect(find.byType(InventoryListRow), findsWidgets);
  });

  testWidgets('timeout -> error with retry', (tester) async {
    final f = FakeStreams();
    addTearDown(f.close);
    await pumpApp(tester, app(view(f, timeout: const Duration(seconds: 2))));
    expect(find.byType(LoadingState), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.textContaining('Zeitüberschreitung'), findsOneWidget);

    await tester.tap(find.text('Erneut versuchen'));
    await tester.pump();
    expect(find.byType(LoadingState), findsOneWidget);
    f.stock.last.add([_entry]);
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.byType(InventoryListRow),
      findsWidgets,
      reason: 'no late timeout',
    );
  });
}
