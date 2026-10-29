import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/rest_entry_sheet.dart';
import 'package:cocktail_planer/services/speech_input.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
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
  final movementIds = <String?>[];
  final quantities = <Map<String, Object?>>[];
  final orderUpdates = <(String, Map<String, dynamic>)>[];
  List<StockEntry> stock = const [];

  /// Number of repository writes (movements and quantities) so far.
  int _writes = 0;

  /// The write with this 1-based number throws once.
  int? failAt;

  void _maybeFail() {
    _writes++;
    if (_writes == failAt) {
      failAt = null;
      throw StateError('offline');
    }
  }

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
          movementId,
        }) async {
          _maybeFail();
          movementIds.add(movementId);
          movements.add({
            'materialId': materialId,
            'locationId': locationId,
            'origin': origin,
            'delta': delta,
            'reason': reason,
            'orderId': orderId,
          });
        },
    setQuantity:
        ({
          required materialId,
          required materialName,
          required locationId,
          required origin,
          required quantity,
        }) async {
          _maybeFail();
          quantities.add({
            'materialId': materialId,
            'locationId': locationId,
            'origin': origin,
            'quantity': quantity,
          });
        },
    updateOrder: (id, data) async {
      orderUpdates.add((id, data));
      return true;
    },
    speechInput: _NoSpeech.new,
  );
}

StockEntry _stock(String m, StockOrigin o, double q) => StockEntry(
  id: StockEntry.buildId(m, 'a', o),
  materialId: m,
  materialName: m,
  locationId: 'a',
  origin: o,
  quantity: q,
);

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

/// Scrolls the sheet's list (down, then up) until [finder] is built.
Future<void> _shown(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    try {
      await _reveal(tester, finder);
    } on StateError {
      await _reveal(tester, finder, delta: -100);
    }
  }
  expect(finder, findsWidgets);
}

Future<void> _save(WidgetTester tester) => _tap(tester, find.text('Speichern'));

Future<void> _openCapture(
  WidgetTester tester,
  _Fake fake, {
  bool dark = false,
  void Function(bool)? onResult,
  bool count = false,
}) async {
  _phone(tester);
  await _pump(
    tester,
    _app((c) async {
      final r = await showStockCaptureSheet(c, services: fake.services);
      onResult?.call(r);
      return r;
    }, dark: dark),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (count) {
    await tester.tap(find.text('Zählung (Bestand setzen)'));
    await tester.pumpAndSettle();
  }
}

VoidCallback? _onPressed(WidgetTester tester, String label) => tester
    .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, label))
    .onPressed;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final dark in [false, true]) {
    testWidgets('standalone "Dazu" books manual movements without order '
        '(dark: $dark)', (tester) async {
      final fake = _Fake();
      bool? result;
      await _openCapture(tester, fake, dark: dark, onResult: (r) => result = r);

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
      // Deterministic per line: a retried commit is a no-op.
      expect(
        fake.movementIds[0],
        matches(r'^manual\|[0-9a-f]{16}\|m1\|a\|order$'),
      );
      expect(
        fake.movementIds[1],
        matches(r'^manual\|[0-9a-f]{16}\|m2\|b\|order$'),
      );
      expect(fake.quantities, isEmpty);
      expect(fake.orderUpdates, isEmpty);
      expect(result, isTrue);
      expect(find.text('Erkannter Text'), findsNothing);
    });

    testWidgets('"Zählung" without origin keeps Investition; total and per '
        'origin shown, no overflow (dark: $dark)', (tester) async {
      final fake = _Fake()
        ..stock = [
          _stock('m1', StockOrigin.order, 3),
          _stock('m1', StockOrigin.investment, 2),
        ];
      await _openCapture(tester, fake, dark: dark, count: true);
      expect(find.textContaining('Investitions-Bestand bleibt'), findsOne);

      await _enter(tester, '6 Bacardi, 5 Orangensaft');
      await _shown(
        tester,
        find.text('Gesamt 5 → 6 · Auftrag 3 → 4 · Investition 2 → 2'),
      );
      await _reveal(tester, find.textContaining('Gesamt 0 → 5'));
      await _shown(
        tester,
        find.text('Gesamt 0 → 5 · Auftrag 0 → 5 · Investition 0 → 0'),
      );
      expect(tester.takeException(), isNull);

      await _save(tester);
      expect(fake.quantities, [
        {
          'materialId': 'm1',
          'locationId': 'a',
          'origin': StockOrigin.order,
          'quantity': 4.0,
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
  }

  testWidgets('"Zählung": counting the total writes nothing (no-op)', (
    tester,
  ) async {
    final fake = _Fake()
      ..stock = [
        _stock('m1', StockOrigin.order, 3),
        _stock('m1', StockOrigin.investment, 2),
      ];
    bool? result;
    await _openCapture(tester, fake, count: true, onResult: (r) => result = r);
    await _enter(tester, '5 Bacardi');
    await _shown(
      tester,
      find.text('Gesamt 5 → 5 · Auftrag 3 → 3 · Investition 2 → 2'),
    );
    await _save(tester);
    expect(fake.quantities, isEmpty);
    expect(result, isTrue);
  });

  testWidgets('"Zählung" below Investition blocks until "Investition" is '
      'said; with it only Investition is set', (tester) async {
    final fake = _Fake()
      ..stock = [
        _stock('m1', StockOrigin.order, 3),
        _stock('m1', StockOrigin.investment, 2),
      ];
    await _openCapture(tester, fake, count: true);
    await _enter(tester, '1 Bacardi');
    await _shown(
      tester,
      find.textContaining('kleiner als der Investitions-Bestand'),
    );
    expect(_onPressed(tester, 'Speichern'), isNull);

    await _tap(tester, find.text('Zurück'));
    await _enter(tester, '1 Bacardi Investition');
    await _shown(
      tester,
      find.text('Gesamt 5 → 4 · Auftrag 3 → 3 · Investition 2 → 1'),
    );
    await _save(tester);
    expect(fake.quantities, [
      {
        'materialId': 'm1',
        'locationId': 'a',
        'origin': StockOrigin.investment,
        'quantity': 1.0,
      },
    ]);
  });

  testWidgets('"Zählung" 0 is valid; "Dazu" 0 is not', (tester) async {
    final fake = _Fake()..stock = [_stock('m1', StockOrigin.order, 3)];
    await _openCapture(tester, fake, count: true);
    await _enter(tester, '0 Bacardi');
    await _shown(
      tester,
      find.text('Gesamt 3 → 0 · Auftrag 3 → 0 · Investition 0 → 0'),
    );
    expect(find.text('Ungültige Menge'), findsNothing);
    await _save(tester);
    expect(fake.quantities.single['quantity'], 0.0);

    final add = _Fake();
    await _openCapture(tester, add);
    await _enter(tester, '0 Bacardi');
    expect(find.text('Menge muss größer als 0 sein'), findsOneWidget);
    expect(_onPressed(tester, 'Speichern'), isNull);
  });

  testWidgets('"Zählung": the same article twice at a location is blocked', (
    tester,
  ) async {
    final fake = _Fake();
    await _openCapture(tester, fake, count: true);
    await _enter(tester, '2 Bacardi, 1 Bacardi');
    await _shown(tester, find.textContaining('doppelt'));
    expect(_onPressed(tester, 'Speichern'), isNull);
  });

  for (final count in [false, true]) {
    final mode = count ? 'Zählung' : 'Dazu';
    testWidgets('$mode: partial failure locks "Zurück"; retry never books a '
        'line twice', (tester) async {
      final fake = _Fake()
        ..stock = [_stock('m1', StockOrigin.order, 3)]
        ..failAt = 2;
      await _openCapture(tester, fake, count: count);
      await _enter(tester, '2 Bacardi, 6 Orangensaft');
      await _save(tester);

      final written = count ? fake.quantities : fake.movements;
      expect(written, hasLength(1), reason: 'first line booked, second failed');
      await _shown(tester, find.text('Gebucht'));
      expect(
        tester
            .widget<TextAction>(find.widgetWithText(TextAction, 'Zurück'))
            .onPressed,
        isNull,
        reason: 'locked after a partial booking',
      );

      await _save(tester);
      expect(written.map((w) => w['materialId']), ['m1', 'm2']);
      expect(find.text('Erkannter Text'), findsNothing, reason: 'closed');
    });

    testWidgets('$mode: closing after a partial booking reports it and '
        'returns true', (tester) async {
      final fake = _Fake()..failAt = 2;
      bool? result;
      await _openCapture(
        tester,
        fake,
        count: count,
        onResult: (r) => result = r,
      );
      await _enter(tester, '2 Bacardi, 6 Orangensaft');
      await _save(tester);
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('1 Zeile(n) wurden bereits gebucht.'), findsOneWidget);
      expect(fake.orderUpdates, isEmpty);
    });
  }

  testWidgets('mode toggle: back from "Zählung" to "Dazu" adds again', (
    tester,
  ) async {
    final fake = _Fake();
    await _openCapture(tester, fake, count: true);
    await _enter(tester, '1 Bacardi');
    await _shown(tester, find.textContaining('Gesamt 0 → 1'));

    await _tap(tester, find.text('Zurück'));
    await tester.tap(find.text('Dazu (Zugang)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Was kommt dazu?'), findsOneWidget);
    await _tap(tester, find.text('Weiter'));
    expect(find.textContaining('Gesamt'), findsNothing);

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
    expect(find.textContaining('z. B. „2 Bacardi'), findsNothing);
    await _reveal(tester, find.text('Nichts übrig'));
    expect(find.text('Nichts übrig'), findsOneWidget);

    await _enter(tester, '2 Bacardi');
    await _save(tester);
    expect(fake.movements.single['reason'], 'rest');
    expect(fake.movements.single['orderId'], 'o1');
    expect(fake.movementIds.single, isNull);
    expect(fake.orderUpdates.single.$1, 'o1');
    expect(fake.orderUpdates.single.$2, {'restRecorded': true});
    expect(result, isTrue);
  });
}
