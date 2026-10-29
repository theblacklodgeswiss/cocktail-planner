import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/rest_entry_sheet.dart';
import 'package:cocktail_planer/services/speech_input.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoSpeech implements SpeechInput {
  @override
  bool get supported => false;

  @override
  Stream<String> listen({String locale = 'de-DE'}) => const Stream.empty();

  @override
  Future<void> stop() async {}
}

MaterialItem _item(String name) =>
    MaterialItem(unit: 'Fl.', name: name, price: 1, currency: 'EUR', note: '');

const _mine = StorageLocation(id: 'a', name: 'Prince', ownerEmail: 'p@x.de');
const _mario = StorageLocation(id: 'b', name: 'Mario');

/// Records every repository call of the sheet.
class _Fake {
  final movements = <Map<String, Object?>>[];
  final quantities = <Map<String, Object?>>[];
  final orderUpdates = <(String, Map<String, dynamic>)>[];
  List<StockEntry> stock = const [];

  RestEntryServices get services => RestEntryServices(
    canRecord: () => true,
    isAdmin: () => false,
    ownLocation: (_) async => _mine,
    loadCatalog: () async => [
      ('m1', _item('Bacardi')),
      ('m2', _item('Orangensaft')),
    ],
    loadLocations: () async => const [_mine, _mario],
    loadStock: () async => stock,
    applyMovement:
        ({
          required materialId,
          required materialName,
          required locationId,
          required origin,
          required delta,
          required reason,
          orderId,
        }) async => movements.add({
          'materialId': materialId,
          'locationId': locationId,
          'origin': origin,
          'delta': delta,
          'reason': reason,
          'orderId': orderId,
        }),
    setQuantity:
        ({
          required materialId,
          required materialName,
          required locationId,
          required origin,
          required quantity,
        }) async => quantities.add({
          'materialId': materialId,
          'locationId': locationId,
          'origin': origin,
          'quantity': quantity,
        }),
    updateOrder: (id, data) async {
      orderUpdates.add((id, data));
      return true;
    },
    speechInput: _NoSpeech.new,
  );
}

SavedOrder _order() => SavedOrder(
  id: 'o1',
  name: 'Hochzeit',
  date: DateTime(2026, 10, 1),
  items: const [],
  total: 0,
  personCount: 10,
  drinkerType: 'normal',
  currency: 'CHF',
  status: OrderStatus.accepted,
);

Widget _app(
  Future<Object?> Function(BuildContext) opener, {
  bool dark = false,
}) => EasyLocalization(
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
              onPressed: () => opener(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _enter(WidgetTester tester, String text) async {
  final field = find.byType(TextField);
  if (field.evaluate().isEmpty) await _reveal(tester, field, delta: -100);
  await tester.enterText(field.first, text);
  await _tap(tester, find.text('Weiter'));
}

/// Scrolls the sheet's list until [finder] is built and on screen.
Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 100,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(RestEntrySheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) await _reveal(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) => _tap(tester, find.text('Speichern'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final dark in [false, true]) {
    testWidgets('standalone "Dazu" books manual movements without order '
        '(dark: $dark)', (tester) async {
      _phone(tester);
      final fake = _Fake();
      bool? result;
      await _pump(
        tester,
        _app(
          (c) async =>
              result = await showStockCaptureSheet(c, services: fake.services),
          dark: dark,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Bestand erfassen'), findsOneWidget);
      expect(find.text('Dazu (Zugang)'), findsOneWidget);
      expect(find.text('Zählung (Bestand setzen)'), findsOneWidget);
      expect(find.textContaining('z. B. „2 Bacardi'), findsOneWidget);
      // Only the rest of an order can be "nothing left".
      await _reveal(tester, find.text('Weiter'));
      expect(find.text('Nichts übrig'), findsNothing);
      expect(tester.takeException(), isNull);

      await _enter(tester, '2 Bacardi, bei Mario 6 Orangensaft');
      // Confirmation view before anything is booked.
      expect(find.text('Erkannter Text'), findsOneWidget);
      expect(fake.movements, isEmpty);
      expect(tester.takeException(), isNull);

      await _save(tester);
      expect(fake.movements, [
        {
          'materialId': 'm1',
          'locationId': 'a',
          'origin': StockOrigin.order,
          'delta': 2.0,
          'reason': 'manual',
          'orderId': null,
        },
        {
          'materialId': 'm2',
          'locationId': 'b',
          'origin': StockOrigin.order,
          'delta': 6.0,
          'reason': 'manual',
          'orderId': null,
        },
      ]);
      expect(fake.quantities, isEmpty);
      expect(fake.orderUpdates, isEmpty);
      expect(result, isTrue);
      expect(find.text('Erkannter Text'), findsNothing);
    });
  }

  testWidgets('standalone "Zählung" sets the counted quantities and shows '
      'old → new', (tester) async {
    _phone(tester);
    final fake = _Fake()
      ..stock = const [
        StockEntry(
          id: 'm1|a|order',
          materialId: 'm1',
          materialName: 'Bacardi',
          locationId: 'a',
          origin: StockOrigin.order,
          quantity: 3,
        ),
      ];
    await _pump(
      tester,
      _app((c) => showStockCaptureSheet(c, services: fake.services)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zählung (Bestand setzen)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ersetzen den bisherigen Bestand'), findsOne);

    await _enter(tester, '2 Bacardi, 5 Orangensaft');
    expect(find.text('Bestand 3 → 2'), findsOneWidget);
    await _reveal(tester, find.text('Bestand 0 → 5'));
    expect(find.text('Bestand 0 → 5'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _save(tester);
    expect(fake.quantities, [
      {
        'materialId': 'm1',
        'locationId': 'a',
        'origin': StockOrigin.order,
        'quantity': 2.0,
      },
      {
        'materialId': 'm2',
        'locationId': 'a',
        'origin': StockOrigin.order,
        'quantity': 5.0,
      },
    ]);
    expect(fake.movements, isEmpty);
    expect(fake.orderUpdates, isEmpty);
  });

  testWidgets('mode toggle: back from "Zählung" to "Dazu" adds again', (
    tester,
  ) async {
    _phone(tester);
    final fake = _Fake();
    await _pump(
      tester,
      _app((c) => showStockCaptureSheet(c, services: fake.services)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zählung (Bestand setzen)'));
    await tester.pumpAndSettle();
    await _enter(tester, '1 Bacardi');
    expect(find.text('Bestand 0 → 1'), findsOneWidget);

    await tester.tap(find.text('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dazu (Zugang)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Was kommt dazu?'), findsOneWidget);
    await _tap(tester, find.text('Weiter'));
    expect(find.textContaining('Bestand 0 →'), findsNothing);

    await _save(tester);
    expect(fake.movements.single['delta'], 1.0);
    expect(fake.quantities, isEmpty);
  });

  testWidgets('after an order: rest booking and restRecorded unchanged', (
    tester,
  ) async {
    _phone(tester);
    final fake = _Fake();
    bool? result;
    await _pump(
      tester,
      _app(
        (c) async => result = await showRestEntrySheet(
          c,
          order: _order(),
          services: fake.services,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Rest erfassen'), findsOneWidget);
    expect(find.text('Dazu (Zugang)'), findsNothing);
    await _reveal(tester, find.text('Nichts übrig'));
    expect(find.text('Nichts übrig'), findsOneWidget);

    await _enter(tester, '2 Bacardi');
    await _save(tester);
    expect(fake.movements.single['reason'], 'rest');
    expect(fake.movements.single['orderId'], 'o1');
    expect(fake.orderUpdates.single.$1, 'o1');
    expect(fake.orderUpdates.single.$2, {'restRecorded': true});
    expect(result, isTrue);
  });
}
