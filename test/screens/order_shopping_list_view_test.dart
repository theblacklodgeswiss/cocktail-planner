import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/orders/order_shopping_list_view.dart';
import 'package:cocktail_planer/screens/shopping_list/stock_logic.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/utils/currency.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home, {ThemeData? theme, double textScale = 1}) {
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
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
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
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 400));
}

const _baileys = MaterialItem(
  unit: '0.7L',
  name: 'Baileys Irish Cream Original Likör',
  price: 14,
  currency: 'CHF',
  note: 'Kaufland',
);

OrderShoppingListView view({
  bool staff = true,
  bool applied = false,
  bool saving = false,
  void Function(int, ItemSource)? onSetSource,
  List<Map<String, dynamic>>? items,
}) => OrderShoppingListView(
  items:
      items ??
      [
        {
          'name': _baileys.name,
          'unit': _baileys.unit,
          'price': 14.0,
          'quantity': 2,
          'note': 'Kaufland',
        },
      ],
  currency: Currency.fromCode('CHF'),
  staff: staff,
  applied: applied,
  saving: saving,
  entries: const [],
  locations: const [StorageLocation(id: 'l1', name: 'Lager Zürich')],
  catalog: const [(id: 'm1', item: _baileys)],
  ownLocationId: 'l1',
  onSetSource: onSetSource ?? (_, _) {},
  onBack: () {},
  onEdit: () {},
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('staff sees the source switch and the internal cost', (
    tester,
  ) async {
    await pumpApp(tester, app(view()));
    expect(find.byKey(const Key('source-switch-0')), findsOneWidget);
    expect(find.byKey(const Key('internal-cost-0')), findsOneWidget);
    expect(find.textContaining('Interne Kosten gesamt'), findsOneWidget);
  });

  testWidgets('customer sees neither switch nor internal costs', (
    tester,
  ) async {
    await pumpApp(tester, app(view(staff: false)));
    expect(find.byKey(const Key('source-switch-0')), findsNothing);
    expect(find.byKey(const Key('internal-cost-0')), findsNothing);
    expect(find.textContaining('Interne Kosten'), findsNothing);
    // The customer total is still shown.
    expect(find.textContaining('28.00'), findsWidgets);
  });

  testWidgets('switching to Lager selects the own location', (tester) async {
    final calls = <(int, ItemSource)>[];
    await pumpApp(tester, app(view(onSetSource: (i, s) => calls.add((i, s)))));
    await tester.tap(find.byKey(const Key('source-switch-0')));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.single.$1, 0);
    expect(calls.single.$2.isStock, isTrue);
    expect(calls.single.$2.locationId, 'l1');
  });

  testWidgets('after stockApplied the switch is locked and a note is shown', (
    tester,
  ) async {
    final calls = <(int, ItemSource)>[];
    await pumpApp(
      tester,
      app(view(applied: true, onSetSource: (i, s) => calls.add((i, s)))),
    );
    final sw = tester.widget<Switch>(find.byKey(const Key('source-switch-0')));
    expect(sw.onChanged, isNull);
    expect(find.byKey(const Key('locked-note-0')), findsOneWidget);
    expect(find.byKey(const Key('internal-cost-0')), findsNothing);
    expect(find.textContaining('Interne Kosten gesamt'), findsNothing);
    await tester.tap(find.byKey(const Key('source-switch-0')));
    await tester.pump();
    expect(calls, isEmpty);
  });

  testWidgets('a stock item stays switchable off before booking', (
    tester,
  ) async {
    final calls = <(int, ItemSource)>[];
    await pumpApp(
      tester,
      app(
        view(
          onSetSource: (i, s) => calls.add((i, s)),
          items: [
            {
              'name': _baileys.name,
              'unit': _baileys.unit,
              'price': 14.0,
              'quantity': 1,
              'source': 'stock',
              'sourceLocationId': 'l1',
            },
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('source-switch-0')));
    await tester.pump();
    expect(calls.single.$2.isStock, isFalse);
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360x640, scale 1.3 (dark=$dark)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        app(
          view(
            items: [
              for (var i = 0; i < 3; i++)
                {
                  'name': _baileys.name,
                  'unit': _baileys.unit,
                  'price': 14.0,
                  'quantity': 12,
                  'note': 'Kaufland Sonderposten',
                  'source': 'stock',
                  'sourceLocationId': 'l1',
                },
            ],
          ),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
