import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/dashboard/widgets/my_requests_list.dart';
import 'package:cocktail_planer/screens/orders/widgets/order_card.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Short name: the test font (Ahem) is one em wide per glyph, so a normal
// name would wrap and no longer model a two-line card.
SavedOrder _order() => SavedOrder(
  id: '1',
  name: 'Fest',
  date: DateTime(2026, 6, 20),
  items: const [],
  total: 100,
  personCount: 50,
  drinkerType: 'normal',
  currency: 'CHF',
  status: OrderStatus.quote,
  location: 'Basel',
);

Widget _app(Widget child, double scale) => EasyLocalization(
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
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: Scaffold(body: ListView(children: [child])),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('list card density (spec: 46-52 px with two text lines)', () {
    testWidgets('order card at scale 1.0', (tester) async {
      await _pump(tester, _app(OrderCard(order: _order(), onTap: () {}), 1));
      final h = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(OrderCard),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .height;
      expect(h, inInclusiveRange(46, 52));
    });

    testWidgets('my-requests card at scale 1.0', (tester) async {
      await _pump(
        tester,
        _app(MyRequestCard(request: _order(), onTap: () {}), 1),
      );
      final h = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(MyRequestCard),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .height;
      expect(h, inInclusiveRange(46, 52));
    });

    testWidgets('cards grow with the text scale instead of clipping', (
      tester,
    ) async {
      await _pump(tester, _app(OrderCard(order: _order(), onTap: () {}), 1.3));
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSize(
              find
                  .descendant(
                    of: find.byType(OrderCard),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(46),
      );
    });
  });
}
