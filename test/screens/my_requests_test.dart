import 'dart:async';

import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/dashboard/widgets/my_request_detail_view.dart';
import 'package:cocktail_planer/screens/dashboard/widgets/my_requests_list.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/large_title_scaffold.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget home, {ThemeData? theme, double textScale = 1}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/order-form',
        builder: (_, _) => const Scaffold(body: Text('page /order-form')),
      ),
    ],
  );
  return EasyLocalization(
    supportedLocales: const [Locale('de'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('de'),
    startLocale: const Locale('de'),
    child: Builder(
      builder: (context) => MaterialApp.router(
        theme: theme ?? AppTheme.light(),
        routerConfig: router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
  // Let stream events reach their StreamBuilders.
  await tester.pump(const Duration(milliseconds: 100));
}

SavedOrder order({
  String id = '1',
  String name = 'Hochzeit Müller',
  OrderStatus status = OrderStatus.quote,
  String location = 'Köln',
  String remarks = '',
}) => SavedOrder(
  id: id,
  name: name,
  date: DateTime(2026, 11, 14),
  items: const [],
  total: 0,
  personCount: 80,
  drinkerType: 'normal',
  currency: 'EUR',
  status: status,
  location: location,
  remarks: remarks,
  cocktails: const ['Mojito', 'Caipirinha'],
  shotSelections: const [ShotSelection(name: 'Jägermeister', quantity: 20)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  void phone(WidgetTester tester, {double w = 360, double h = 640}) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget screen(
    Stream<List<SavedOrder>> Function() factory, {
    void Function(SavedOrder)? onOpen,
  }) {
    return LargeTitleScaffold(
      title: 'Meine Anfragen',
      slivers: [
        MyRequestsContent(streamFactory: factory, onOpen: onOpen ?? (_) {}),
      ],
    );
  }

  group('MyRequestsList', () {
    testWidgets('completed shows the accepted label, meta line and taps', (
      tester,
    ) async {
      phone(tester);
      SavedOrder? opened;
      await pumpApp(
        tester,
        app(
          Scaffold(
            body: MyRequestsList(
              requests: [order(status: OrderStatus.completed)],
              onTap: (o) => opened = o,
            ),
          ),
        ),
      );
      expect(find.text('Angenommen'), findsOneWidget);
      expect(find.text('Abgeschlossen'), findsNothing);
      expect(find.text('80 Gäste · Köln'), findsOneWidget);
      await tester.tap(find.text('Hochzeit Müller'));
      expect(opened?.id, '1');
    });

    testWidgets('keeps the empty hint for the landing page', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          const Scaffold(
            body: MyRequestsList(requests: [], onTap: _noop),
          ),
        ),
      );
      expect(find.text('Noch keine Anfragen gestellt'), findsOneWidget);
    });
  });

  group('MyRequestsContent', () {
    testWidgets('empty shows EmptyState with CTA to the order form', (
      tester,
    ) async {
      phone(tester);
      await pumpApp(
        tester,
        app(screen(() => Stream.value(const <SavedOrder>[]))),
      );
      expect(find.byType(EmptyState), findsOneWidget);
      await tester.tap(find.text('Anfrage starten'));
      await tester.pumpAndSettle();
      expect(find.text('page /order-form'), findsOneWidget);
    });

    testWidgets('loading shows LoadingState', (tester) async {
      phone(tester);
      final c = StreamController<List<SavedOrder>>();
      addTearDown(c.close);
      await pumpApp(tester, app(screen(() => c.stream)));
      expect(find.byType(LoadingState), findsOneWidget);
    });

    testWidgets('error shows ErrorState and retry re-subscribes', (
      tester,
    ) async {
      phone(tester);
      var calls = 0;
      await pumpApp(
        tester,
        app(
          screen(() {
            calls++;
            return calls == 1
                ? Stream<List<SavedOrder>>.error('boom')
                : Stream.value([order()]);
          }),
        ),
      );
      expect(find.byType(ErrorState), findsOneWidget);
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 2);
      expect(find.text('Hochzeit Müller'), findsOneWidget);
    });

    testWidgets('lists all requests (no max-3 cut) and opens one', (
      tester,
    ) async {
      phone(tester);
      SavedOrder? opened;
      await pumpApp(
        tester,
        app(
          screen(
            () => Stream.value([
              for (var i = 0; i < 4; i++) order(id: '$i', name: 'Fest $i'),
            ]),
            onOpen: (o) => opened = o,
          ),
        ),
      );
      expect(find.text('Fest 0'), findsOneWidget);
      await tester.tap(find.text('Fest 0'));
      expect(opened?.id, '0');
    });
  });

  group('MyRequestDetailView', () {
    Widget view(
      SavedOrder o, {
      bool staff = false,
      bool loading = false,
      VoidCallback? onPdf,
    }) => Scaffold(
      body: SingleChildScrollView(
        child: MyRequestDetailView(
          request: o,
          showStaffAction: staff,
          onOpenOrder: () {},
          onConfirmation: onPdf,
          confirmationLoading: loading,
        ),
      ),
    );

    testWidgets('PDF button only for accepted (and completed)', (tester) async {
      phone(tester);
      await pumpApp(tester, app(view(order(), onPdf: () {})));
      expect(find.text('Bestätigung als PDF'), findsNothing);
      expect(
        find.text('Wir melden uns mit einem persönlichen Angebot'),
        findsOneWidget,
      );

      var pdf = 0;
      await pumpApp(
        tester,
        app(view(order(status: OrderStatus.completed), onPdf: () => pdf++)),
      );
      expect(find.text('Bestätigung als PDF'), findsOneWidget);
      expect(
        find.text('Wir melden uns mit einem persönlichen Angebot'),
        findsNothing,
      );
      await tester.tap(find.text('Bestätigung als PDF'));
      expect(pdf, 1);
    });

    testWidgets('staff button only for staff', (tester) async {
      phone(tester);
      await pumpApp(tester, app(view(order())));
      expect(find.text('Zum Auftrag'), findsNothing);
      await pumpApp(tester, app(view(order(), staff: true)));
      expect(find.text('Zum Auftrag'), findsOneWidget);
    });

    testWidgets('drinks are listed individually, status uses customer label', (
      tester,
    ) async {
      phone(tester);
      await pumpApp(
        tester,
        app(view(order(status: OrderStatus.completed, remarks: 'Ohne Nüsse'))),
      );
      expect(find.text('Mojito'), findsOneWidget);
      expect(find.text('Caipirinha'), findsOneWidget);
      expect(find.text('Jägermeister (20)'), findsOneWidget);
      expect(find.text('Ohne Nüsse'), findsOneWidget);
      expect(find.text('Angenommen'), findsOneWidget);
    });
  });

  for (final dark in [false, true]) {
    testWidgets('no overflow at 360px, scale 1.3, long name (dark=$dark)', (
      tester,
    ) async {
      phone(tester);
      final longName = List.filled(10, 'Hochzeit').join(' ');
      expect(longName.length, greaterThanOrEqualTo(80));
      final o = order(
        name: longName,
        status: OrderStatus.completed,
        location: 'Bad Homburg vor der Höhe am Taunus',
        remarks: longName,
      );
      final theme = dark ? AppTheme.dark() : AppTheme.light();

      await pumpApp(
        tester,
        app(screen(() => Stream.value([o])), theme: theme, textScale: 1.3),
      );
      expect(tester.takeException(), isNull);

      await pumpApp(
        tester,
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: MyRequestDetailView(
                request: o,
                showStaffAction: true,
                onOpenOrder: () {},
                onConfirmation: () {},
                confirmationLoading: false,
              ),
            ),
          ),
          theme: theme,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

void _noop(SavedOrder _) {}
