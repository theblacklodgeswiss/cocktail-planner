import 'dart:async';

import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/inventory/rest_entry_sheet.dart';
import 'package:cocktail_planer/services/speech_input.dart';
import 'package:cocktail_planer/services/stock_ai_interpreter.dart';
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

StockEntry _stock(String m, StockOrigin o, double q) => StockEntry(
  id: StockEntry.buildId(m, 'a', o),
  materialId: m,
  materialName: m,
  locationId: 'a',
  origin: o,
  quantity: q,
);

/// Fake collaborators with an injected AI.
class _Fake {
  final movements = <Map<String, Object?>>[];
  final quantities = <Map<String, Object?>>[];
  final orderUpdates = <(String, Map<String, dynamic>)>[];
  final requests = <StockInterpretRequest>[];
  final enabledWrites = <bool>[];
  List<StockEntry> stock = [
    _stock('m1', StockOrigin.order, 3),
    _stock('m1', StockOrigin.investment, 2),
  ];
  bool aiConfigured = true;
  bool aiEnabled = true;
  bool stockFails = false;
  bool saveEnabledFails = false;

  /// What the fake AI answers; null = the AI is not wired at all.
  Future<StockAiResult?> Function(StockInterpretRequest)? answer;

  RestEntryServices get services => RestEntryServices(
    canRecord: () => true,
    isAdmin: () => false,
    ownLocation: (_) async => _mine,
    loadCatalog: () async => [
      ('m1', _item('Bacardi')),
      ('m2', _item('Orangensaft')),
      ('m3', _item('Sprite')),
      ('m4', _item('Sprite Zero')),
    ],
    loadLocations: () async => const [_mine, _mario],
    loadStock: () async {
      if (stockFails) throw StateError('offline');
      return stock;
    },
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
    interpret: answer == null
        ? null
        : (r) {
            requests.add(r);
            return answer!(r);
          },
    aiConfigured: () => aiConfigured,
    stockAiEnabled: () => aiEnabled,
    setStockAiEnabled: (v) async {
      if (saveEnabledFails) throw StateError('storage');
      enabledWrites.add(v);
    },
  );
}

/// "vierzig Bacardi" (with a stock note) and an ambiguous "ein Sprite".
const _aiAnswer = StockAiResult([
  StockAiLine(
    spokenText: 'vierzig Bacardi',
    materialId: 'm1',
    quantity: 40,
    note: 'Im System sind 5',
    confidence: 0.95,
  ),
  StockAiLine(
    spokenText: 'ein Sprite',
    candidateIds: ['m3', 'm4'],
    quantity: 1,
    confidence: 0.5,
  ),
]);

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

Future<void> _open(
  WidgetTester tester,
  _Fake fake, {
  bool dark = false,
  bool count = false,
  bool afterOrder = false,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      _app(
        (c) => afterOrder
            ? showRestEntrySheet(c, order: _order(), services: fake.services)
            : showStockCaptureSheet(c, services: fake.services),
        dark: dark,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (count) {
    await tester.tap(find.text('Zählung (Bestand setzen)'));
    await tester.pumpAndSettle();
  }
}

Finder get _sheetScrollable => find
    .descendant(
      of: find.byType(RestEntrySheet),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    return;
  }
  // Jump through the sheet's list (dragging could hit the multi-line text
  // field, which scrolls itself).
  final list = tester.state<ScrollableState>(_sheetScrollable).position;
  list.jumpTo(0);
  await tester.pump();
  while (finder.evaluate().isEmpty && list.pixels < list.maxScrollExtent) {
    list.jumpTo((list.pixels + 150).clamp(0, list.maxScrollExtent));
    await tester.pump();
  }
  if (finder.evaluate().isNotEmpty) await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Types [text] and taps "Weiter" without settling (the AI may be pending).
Future<void> _typeAndContinue(WidgetTester tester, String text) async {
  await _reveal(tester, find.byType(TextField));
  await tester.enterText(find.byType(TextField).first, text);
  // Unfocus so the caret no longer pulls the field back into view.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _reveal(tester, find.text('Weiter'));
  await tester.tap(find.text('Weiter'));
  await tester.pump();
  await tester.pump();
}

Future<void> _shown(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  expect(finder, findsWidgets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final count in [false, true]) {
    for (final dark in [false, true]) {
      final mode = count ? 'Zählung' : 'Dazu';
      testWidgets('$mode: AI success shows badged lines, chips and the note; '
          'nothing booked before saving (dark: $dark)', (tester) async {
        final fake = _Fake()..answer = (_) async => _aiAnswer;
        await _open(tester, fake, dark: dark, count: count);
        expect(find.text('KI-Auswertung'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _typeAndContinue(tester, 'vierzig Bacardi und ein Sprite');
        await tester.pumpAndSettle();

        expect(fake.requests, hasLength(1));
        final r = fake.requests.single;
        expect(r.text, 'vierzig Bacardi und ein Sprite');
        expect(r.mode, count ? StockAiMode.count : StockAiMode.add);
        expect(r.stock, fake.stock);
        expect(r.defaultLocation, _mine);

        expect(find.text('Von Claude vorgeschlagen – bitte prüfen'), findsOne);
        expect(find.text('Erkannter Text'), findsOneWidget);
        await _shown(tester, find.text('Claude: Im System sind 5'));
        await _shown(tester, find.text('Ungewöhnlich hohe Menge'));
        await _shown(tester, find.text('Artikel nicht eindeutig'));
        await _shown(tester, find.text('KI-Vorschlag'));
        expect(find.text('Ohne KI ausgewertet'), findsNothing);
        expect(fake.movements, isEmpty);
        expect(fake.quantities, isEmpty);
        expect(tester.takeException(), isNull);

        // The ambiguous line keeps the pick flow.
        await _tap(tester, find.widgetWithText(ActionChip, 'Sprite'));
        await _tap(tester, find.text('Speichern'));
        if (count) {
          expect(fake.quantities, [
            {
              'materialId': 'm1',
              'locationId': 'a',
              'origin': StockOrigin.order,
              'quantity': 38.0,
            },
            {
              'materialId': 'm3',
              'locationId': 'a',
              'origin': StockOrigin.order,
              'quantity': 1.0,
            },
          ]);
          expect(fake.movements, isEmpty);
        } else {
          expect(fake.movements.map((m) => (m['materialId'], m['delta'])), [
            ('m1', 40.0),
            ('m3', 1.0),
          ]);
          expect(fake.movements.every((m) => m['reason'] == 'manual'), isTrue);
          expect(fake.quantities, isEmpty);
        }
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets('pending AI shows "Wird ausgewertet…", Zurück cancels it '
        '(dark: $dark)', (tester) async {
      final pending = Completer<StockAiResult?>();
      final fake = _Fake()..answer = (_) => pending.future;
      await _open(tester, fake, dark: dark);
      await _typeAndContinue(tester, '2 Bacardi');
      expect(find.text('Wird ausgewertet…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Zurück'));
      await tester.pump();
      expect(find.text('Wird ausgewertet…'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      // A late answer is ignored.
      pending.complete(_aiAnswer);
      await tester.pumpAndSettle();
      expect(find.text('Erkannter Text'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(fake.requests, hasLength(1));
    });

    testWidgets('AI failure falls back to the rule lines with a hint '
        '(dark: $dark)', (tester) async {
      final fake = _Fake()..answer = (_) async => throw StateError('offline');
      await _open(tester, fake, dark: dark);
      await _typeAndContinue(tester, '2 Bacardi');
      await tester.pumpAndSettle();

      expect(find.text('Ohne KI ausgewertet'), findsOneWidget);
      expect(find.text('KI-Vorschlag'), findsNothing);
      expect(find.text('Von Claude vorgeschlagen – bitte prüfen'), findsNothing);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Speichern'));
      expect(fake.movements.single['materialId'], 'm1');
      expect(fake.movements.single['delta'], 2.0);
    });
  }

  testWidgets('AI timeout (10 s) falls back to the rule lines', (tester) async {
    final fake = _Fake()..answer = (_) => Completer<StockAiResult?>().future;
    await _open(tester, fake);
    await _typeAndContinue(tester, '2 Bacardi');
    expect(find.text('Wird ausgewertet…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('Wird ausgewertet…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Ohne KI ausgewertet'), findsOneWidget);
    expect(find.text('Bacardi'), findsWidgets);
  });

  testWidgets('invalid AI answer (null) falls back with a hint', (
    tester,
  ) async {
    final fake = _Fake()..answer = (_) async => null;
    await _open(tester, fake);
    await _typeAndContinue(tester, '2 Bacardi');
    await tester.pumpAndSettle();
    expect(find.text('Ohne KI ausgewertet'), findsOneWidget);
  });

  testWidgets('AI with zero lines while the rules found some: rules + hint', (
    tester,
  ) async {
    final fake = _Fake()..answer = (_) async => const StockAiResult([]);
    await _open(tester, fake);
    await _typeAndContinue(tester, '2 Bacardi');
    await tester.pumpAndSettle();
    expect(find.text('Ohne KI ausgewertet'), findsOneWidget);
    expect(find.text('Keine Zeilen erkannt.'), findsNothing);
  });

  const oneBacardi = StockAiResult([
    StockAiLine(
      spokenText: '2 Bacardi',
      materialId: 'm1',
      quantity: 2,
      confidence: 0.9,
    ),
  ]);

  testWidgets('AI found fewer lines than the rules: no line vanishes', (
    tester,
  ) async {
    final fake = _Fake()..answer = (_) async => oneBacardi;
    await _open(tester, fake);
    await _typeAndContinue(tester, '2 Bacardi, 6 Orangensaft');
    await tester.pumpAndSettle();
    expect(find.text('Ohne KI ausgewertet'), findsOneWidget);
    await _shown(tester, find.text('Orangensaft'));
    await _shown(tester, find.text('KI-Vorschlag nutzen'));
    await _tap(tester, find.text('Speichern'));
    expect(fake.movements.map((m) => m['materialId']), ['m1', 'm2']);
  });

  testWidgets('"Regel-Erkennung nutzen" switches to the rule result and back', (
    tester,
  ) async {
    final fake = _Fake()..answer = (_) async => _aiAnswer;
    await _open(tester, fake);
    await _typeAndContinue(tester, '3 Orangensaft');
    await tester.pumpAndSettle();
    expect(find.text('Von Claude vorgeschlagen – bitte prüfen'), findsOne);

    await _tap(tester, find.text('Regel-Erkennung nutzen'));
    expect(find.text('Von Claude vorgeschlagen – bitte prüfen'), findsNothing);
    expect(find.text('KI-Vorschlag'), findsNothing);
    await _shown(tester, find.text('Orangensaft'));

    await _tap(tester, find.text('KI-Vorschlag nutzen'));
    expect(find.text('Von Claude vorgeschlagen – bitte prüfen'), findsOne);
    expect(fake.requests, hasLength(1), reason: 'no new call on switching');

    await _tap(tester, find.text('Regel-Erkennung nutzen'));
    await _tap(tester, find.text('Speichern'));
    expect(fake.movements.single['materialId'], 'm2');
    expect(fake.movements.single['delta'], 3.0);
  });

  testWidgets('switch off: no AI call, the choice is persisted', (
    tester,
  ) async {
    final fake = _Fake()..answer = (_) async => _aiAnswer;
    await _open(tester, fake);
    await _tap(tester, find.text('KI-Auswertung'));
    expect(fake.enabledWrites, [false]);

    await _typeAndContinue(tester, '2 Bacardi');
    await tester.pumpAndSettle();
    expect(fake.requests, isEmpty);
    expect(find.text('Ohne KI ausgewertet'), findsNothing);
    expect(find.text('KI-Vorschlag'), findsNothing);
  });

  testWidgets('preference off from the start: no AI call', (tester) async {
    final fake = _Fake()
      ..answer = ((_) async => _aiAnswer)
      ..aiEnabled = false;
    await _open(tester, fake);
    await _typeAndContinue(tester, '2 Bacardi');
    await tester.pumpAndSettle();
    expect(fake.requests, isEmpty);
  });

  testWidgets('not configured: no switch, no call', (tester) async {
    final fake = _Fake()
      ..answer = ((_) async => _aiAnswer)
      ..aiConfigured = false;
    await _open(tester, fake);
    expect(find.text('KI-Auswertung'), findsNothing);
    await _typeAndContinue(tester, '2 Bacardi');
    await tester.pumpAndSettle();
    expect(fake.requests, isEmpty);
    expect(find.text('Ohne KI ausgewertet'), findsNothing);
  });

  testWidgets('double tap on "Weiter" makes one call', (tester) async {
    final pending = Completer<StockAiResult?>();
    final fake = _Fake()..answer = (_) => pending.future;
    await _open(tester, fake);
    await tester.enterText(find.byType(TextField).first, '2 Bacardi');
    await _reveal(tester, find.text('Weiter'));
    await tester.tap(find.text('Weiter'));
    await tester.tap(find.text('Weiter'), warnIfMissed: false);
    await tester.pump();
    // The input view is replaced by the pending state: no third tap target.
    expect(find.text('Wird ausgewertet…'), findsOneWidget);
    pending.complete(_aiAnswer);
    await tester.pumpAndSettle();
    expect(fake.requests, hasLength(1));
  });

  testWidgets('empty text: no AI call', (tester) async {
    final fake = _Fake()..answer = (_) async => _aiAnswer;
    await _open(tester, fake);
    await _typeAndContinue(tester, '   ');
    await tester.pumpAndSettle();
    expect(fake.requests, isEmpty);
    expect(find.text('Keine Zeilen erkannt.'), findsOneWidget);
  });

  testWidgets('after an order the same pipeline books the rest', (
    tester,
  ) async {
    final fake = _Fake()
      ..answer = (_) async => const StockAiResult([
        StockAiLine(
          spokenText: 'zwei Bacardi',
          materialId: 'm1',
          quantity: 2,
          confidence: 0.9,
        ),
      ]);
    await _open(tester, fake, afterOrder: true);
    expect(find.text('Rest erfassen'), findsOneWidget);
    expect(find.text('KI-Auswertung'), findsOneWidget);

    await _typeAndContinue(tester, 'zwei Bacardi');
    await tester.pumpAndSettle();
    expect(fake.requests.single.mode, StockAiMode.add);
    await _shown(tester, find.text('KI-Vorschlag'));
    await _tap(tester, find.text('Speichern'));
    expect(fake.movements.single['reason'], 'rest');
    expect(fake.movements.single['orderId'], 'o1');
    expect(fake.movements.single['delta'], 2.0);
    expect(fake.orderUpdates.single.$2, {'restRecorded': true});
  });

  testWidgets('stock load fails in "Dazu": rules without AI, no dead end', (
    tester,
  ) async {
    final fake = _Fake()
      ..answer = ((_) async => _aiAnswer)
      ..stockFails = true;
    await _open(tester, fake);
    await _typeAndContinue(tester, '2 Bacardi');
    await tester.pumpAndSettle();
    expect(fake.requests, isEmpty);
    expect(find.text('Erkannter Text'), findsOneWidget);
    await _shown(tester, find.text('Ohne KI ausgewertet'));
    expect(find.text('Noch kein Bestand'), findsNothing);
    await _tap(tester, find.text('Speichern'));
    expect(fake.movements.single['delta'], 2.0);
  });

  testWidgets('saving the switch fails: no crash, the switch still works', (
    tester,
  ) async {
    final fake = _Fake()
      ..answer = ((_) async => _aiAnswer)
      ..saveEnabledFails = true;
    await _open(tester, fake);
    await _tap(tester, find.text('KI-Auswertung'));
    expect(tester.takeException(), isNull);
    await _typeAndContinue(tester, '2 Bacardi');
    await tester.pumpAndSettle();
    expect(fake.requests, isEmpty);
  });
}
