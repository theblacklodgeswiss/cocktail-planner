import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/dashboard/staff_dashboard_view.dart';
import 'package:cocktail_planer/screens/orders/orders_logic.dart';
import 'package:cocktail_planer/screens/orders/orders_overview_view.dart';
import 'package:cocktail_planer/screens/orders/orders_year_view.dart';
import 'package:cocktail_planer/screens/orders/pending_orders_view.dart';
import 'package:cocktail_planer/screens/orders/widgets/order_card.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/date_tile.dart';
import 'package:cocktail_planer/ui/widgets/floating_card.dart';
import 'package:cocktail_planer/ui/widgets/staff_tab_bar.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
import 'package:cocktail_planer/ui/widgets/status_dot.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pages = [
  '/orders',
  '/pending-orders',
  '/order-form',
  '/admin',
  '/settings',
];

String? lastPage;

Widget app(Widget home, {ThemeData? theme, double textScale = 1}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      for (final path in _pages)
        GoRoute(
          path: path,
          builder: (_, state) {
            lastPage = state.uri.toString();
            return Scaffold(body: Text('page ${state.uri}'));
          },
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
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pills scroll sideways (the test font is wide); bring one into view first.
Future<void> tapPill(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
}

void phone(WidgetTester tester, {double w = 360, double h = 640}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final now = DateTime(2026, 10, 27, 10);

SavedOrder order(
  String id, {
  String? name,
  DateTime? date,
  double total = 100,
  OrderStatus status = OrderStatus.quote,
  int persons = 50,
  String location = 'Basel',
  String? createdBy,
}) => SavedOrder(
  id: id,
  name: name ?? 'Order $id',
  date: date ?? DateTime(2026, 6, 1),
  items: const [],
  total: total,
  personCount: persons,
  drinkerType: 'normal',
  currency: 'CHF',
  status: status,
  location: location,
  createdBy: createdBy,
);

final sample = [
  order('q1', name: 'Hochzeit Meier', date: DateTime(2026, 6, 20)),
  order(
    'a1',
    name: 'Firmenfest',
    status: OrderStatus.accepted,
    date: DateTime(2026, 11, 6),
  ),
  order(
    'c1',
    name: 'Geburtstag',
    status: OrderStatus.completed,
    date: DateTime(2026, 7, 4),
  ),
  order(
    'd1',
    name: 'Absage',
    status: OrderStatus.declined,
    date: DateTime(2026, 6, 2),
  ),
  order('q2', name: 'Sommerfest', date: DateTime(2026, 7, 10)),
  order(
    'a2',
    name: 'Jubiläum',
    status: OrderStatus.accepted,
    date: DateTime(2026, 12, 1),
  ),
];

final longName = 'Hochzeit ${'Mustermann-Beispielhaft ' * 3}'.substring(0, 80);

OrdersOverviewView overview({
  List<SavedOrder>? orders,
  Object? error,
  VoidCallback? onRetry,
  OrderStatusFilter initialFilter = OrderStatusFilter.quotes,
  void Function(SavedOrder)? onOpen,
  VoidCallback? onOpenArchive,
  int pendingCount = 0,
}) => OrdersOverviewView(
  orders: orders,
  error: error,
  onRetry: onRetry ?? () {},
  now: now,
  initialFilter: initialFilter,
  pendingCount: pendingCount,
  onOpen: onOpen ?? (_) {},
  onOpenPending: () {},
  onOpenArchive: onOpenArchive ?? () {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('status dot mapping', () {
    test('four statuses', () {
      expect(staffStatusKind(OrderStatus.quote), StatusKind.offer);
      expect(staffStatusKind(OrderStatus.accepted), StatusKind.accepted);
      expect(staffStatusKind(OrderStatus.completed), StatusKind.completed);
      expect(staffStatusKind(OrderStatus.declined), StatusKind.declined);
    });
  });

  group('orders overview', () {
    testWidgets('title, pills with counts and the default quotes filter', (
      tester,
    ) async {
      phone(tester);
      await pumpApp(tester, app(overview(orders: sample)));
      // Large title, collapsed title and the tab label.
      expect(find.text('Aufträge'), findsWidgets);
      expect(find.byType(StaffTabBar), findsOneWidget);
      // No back arrow on the staff home / tab navigation.
      expect(find.bySemanticsLabel('Zurück'), findsNothing);
      expect(find.text('Alle 6'), findsOneWidget);
      expect(find.text('Angebot offen 2'), findsOneWidget);
      expect(find.text('Angenommen 3'), findsOneWidget);
      expect(find.text('Abgeschlossen 1'), findsOneWidget);
      expect(find.text('Hochzeit Meier'), findsOneWidget);
      expect(find.text('Sommerfest'), findsOneWidget);
      expect(find.text('Geburtstag'), findsNothing);
    });

    testWidgets('selecting a pill filters the list', (tester) async {
      phone(tester);
      await pumpApp(tester, app(overview(orders: sample)));
      await tapPill(tester, 'Angenommen 3');
      await settle(tester);
      // Hero shows Firmenfest too; the list has one card per accepted order.
      expect(find.widgetWithText(OrderCard, 'Firmenfest'), findsOneWidget);
      expect(find.widgetWithText(OrderCard, 'Geburtstag'), findsOneWidget);
      expect(find.text('Hochzeit Meier'), findsNothing);

      await tapPill(tester, 'Abgeschlossen 1');
      await settle(tester);
      expect(find.widgetWithText(OrderCard, 'Geburtstag'), findsOneWidget);
      expect(find.widgetWithText(OrderCard, 'Firmenfest'), findsNothing);

      await tapPill(tester, 'Alle 6');
      await settle(tester);
      expect(find.text('Bestellungen · 6'), findsOneWidget);
    });

    testWidgets('?status=accepted selects the Angenommen pill', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          overview(
            orders: sample,
            initialFilter: statusFilterFromQuery('accepted'),
          ),
        ),
      );
      expect(find.byType(OrderCard), findsNWidgets(3));
      expect(find.text('Hochzeit Meier'), findsNothing);
    });

    testWidgets('month headings, card meta and total', (tester) async {
      phone(tester, h: 1400);
      await pumpApp(
        tester,
        app(overview(orders: sample, initialFilter: OrderStatusFilter.all)),
      );
      expect(find.text('Juni 2026'), findsOneWidget);
      expect(find.text('Juli 2026'), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('50 Gäste · Basel'), findsWidgets);
      expect(find.text('100.00 CHF'), findsWidgets);
      expect(find.byType(DateTile), findsWidgets);
    });

    testWidgets('next appointment hero with countdown in days', (tester) async {
      phone(tester);
      await pumpApp(tester, app(overview(orders: sample)));
      expect(find.text('NÄCHSTER TERMIN'), findsOneWidget);
      final hero = find.byType(NextAppointmentHero);
      expect(
        find.descendant(of: hero, matching: find.text('10')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hero, matching: find.text('Tage')),
        findsOneWidget,
      );
    });

    testWidgets('hero says Heute for today and hides without one', (
      tester,
    ) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          overview(
            orders: [
              order(
                't',
                name: 'Heute-Fest',
                status: OrderStatus.accepted,
                date: DateTime(2026, 10, 27),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Heute'), findsOneWidget);

      await pumpApp(tester, app(overview(orders: [order('q')])));
      expect(find.text('NÄCHSTER TERMIN'), findsNothing);
    });

    testWidgets('tap opens the order; Archiv opens the archive', (
      tester,
    ) async {
      phone(tester);
      SavedOrder? opened;
      var archive = 0;
      await pumpApp(
        tester,
        app(
          overview(
            orders: sample,
            onOpen: (o) => opened = o,
            onOpenArchive: () => archive++,
          ),
        ),
      );
      await tester.tap(find.text('Sommerfest'));
      await settle(tester);
      expect(opened?.id, 'q2');
      await tester.tap(find.text('Archiv'));
      await settle(tester);
      expect(archive, 1);
    });

    testWidgets('search filters across statuses', (tester) async {
      phone(tester);
      await pumpApp(tester, app(overview(orders: sample)));
      await tester.tap(
        find.bySemanticsLabel('Name oder Gästeanzahl suchen...'),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'geburt');
      await settle(tester);
      expect(find.widgetWithText(OrderCard, 'Geburtstag'), findsOneWidget);
      expect(find.byType(OrderCard), findsOneWidget);
    });

    testWidgets('empty, loading and error with retry', (tester) async {
      phone(tester);
      await pumpApp(tester, app(overview(orders: const [])));
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Keine Bestellungen'), findsOneWidget);

      await pumpApp(tester, app(overview()));
      expect(find.byType(LoadingState), findsOneWidget);

      var retries = 0;
      await pumpApp(
        tester,
        app(overview(error: 'boom', onRetry: () => retries++)),
      );
      expect(find.byType(ErrorState), findsOneWidget);
      await tester.tap(find.text('Erneut versuchen'));
      await settle(tester);
      expect(retries, 1);
    });

    testWidgets('200 search results scroll without errors', (tester) async {
      phone(tester);
      final many = [
        for (var i = 0; i < 200; i++)
          order(
            'o$i',
            name: 'Fest $i',
            status: OrderStatus.values[i % 4],
            date: DateTime(2026, 1 + i % 12, 1 + i % 28),
          ),
      ];
      await pumpApp(tester, app(overview(orders: many)));
      await tester.tap(
        find.bySemanticsLabel('Name oder Gästeanzahl suchen...'),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'fest');
      await settle(tester);
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -20000),
        5000,
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cards meet the 44 px tap target', (tester) async {
      phone(tester);
      final handle = tester.ensureSemantics();
      await pumpApp(tester, app(overview(orders: sample, pendingCount: 2)));
      final card = tester.getSize(find.byType(FloatingCard).first);
      expect(card.height, greaterThanOrEqualTo(44));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });
  });

  group('pending orders', () {
    PendingOrdersView pending({
      List<SavedOrder>? orders,
      Future<bool> Function(SavedOrder)? onDismiss,
    }) => PendingOrdersView(
      orders: orders,
      onRetry: () {},
      onOpen: (_) {},
      onDismiss: onDismiss ?? (_) async => true,
    );

    final pendingSample = [
      order('p1', name: 'Anfrage Huber', total: 0, date: DateTime(2026, 9, 1)),
      order('p2', name: 'Anfrage Keller', total: 0, date: DateTime(2026, 8, 1)),
    ];

    testWidgets('visible Erledigt button confirms and calls dismiss', (
      tester,
    ) async {
      phone(tester);
      final dismissed = <String>[];
      await pumpApp(
        tester,
        app(
          pending(
            orders: pendingSample,
            onDismiss: (o) async {
              dismissed.add(o.id);
              return true;
            },
          ),
        ),
      );
      // Event date ascending: Keller first.
      final buttons = find.text('Erledigt');
      expect(buttons, findsNWidgets(2));
      await tester.tap(buttons.first);
      await settle(tester);
      expect(find.text('Pendenz erledigt?'), findsOneWidget);
      // Confirm button of the sheet (last "Erledigt").
      await tester.tap(find.text('Erledigt').last);
      await settle(tester);
      expect(dismissed, ['p2']);
      expect(find.text('Anfrage Keller'), findsNothing);
    });

    testWidgets('cancel keeps the order', (tester) async {
      phone(tester);
      final dismissed = <String>[];
      await pumpApp(
        tester,
        app(
          pending(
            orders: pendingSample,
            onDismiss: (o) async {
              dismissed.add(o.id);
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.text('Erledigt').first);
      await settle(tester);
      await tester.tap(find.text('Abbrechen'));
      await settle(tester);
      expect(dismissed, isEmpty);
      expect(find.text('Anfrage Keller'), findsOneWidget);
    });

    testWidgets('swipe still dismisses after confirmation', (tester) async {
      phone(tester);
      final dismissed = <String>[];
      await pumpApp(
        tester,
        app(
          pending(
            orders: pendingSample,
            onDismiss: (o) async {
              dismissed.add(o.id);
              return true;
            },
          ),
        ),
      );
      await tester.drag(find.text('Anfrage Huber'), const Offset(-500, 0));
      await settle(tester);
      expect(find.text('Pendenz erledigt?'), findsOneWidget);
      await tester.tap(find.text('Erledigt').last);
      await settle(tester);
      expect(dismissed, ['p1']);
    });

    testWidgets('a failed dismiss shows the order again', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(pending(orders: pendingSample, onDismiss: (_) async => false)),
      );
      await tester.tap(find.text('Erledigt').first);
      await settle(tester);
      await tester.tap(find.text('Erledigt').last);
      await settle(tester);
      expect(find.text('Anfrage Keller'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      phone(tester);
      await pumpApp(tester, app(pending(orders: const [])));
      expect(find.text('Keine offenen Pendenzen'), findsOneWidget);
    });
  });

  group('year archive', () {
    testWidgets('year cards with counts open the month list', (tester) async {
      phone(tester);
      await pumpApp(
        tester,
        app(
          OrdersYearView(
            orders: [
              ...sample,
              order('old', name: 'Altfest', date: DateTime(2025, 3, 1)),
            ],
            onRetry: () {},
            onOpen: (_) {},
          ),
        ),
      );
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('6 Bestellungen'), findsOneWidget);
      await tester.tap(find.text('2025'));
      await settle(tester);
      expect(find.text('Altfest'), findsOneWidget);
      expect(find.text('März 2025'), findsOneWidget);
    });

    testWidgets('200 orders in one year scroll without errors', (tester) async {
      phone(tester);
      final many = [
        for (var i = 0; i < 200; i++)
          order(
            'o$i',
            name: i == 0 ? longName : 'Fest $i',
            status: OrderStatus.values[i % 4],
            date: DateTime(2026, 1 + i % 12, 1 + i % 28),
          ),
      ];
      await pumpApp(
        tester,
        app(OrdersYearView(orders: many, onRetry: () {}, onOpen: (_) {})),
      );
      await tester.tap(find.text('2026'));
      await settle(tester);
      for (var i = 0; i < 6; i++) {
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -4000),
          5000,
        );
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('dashboard', () {
    final fixture = [
      order('p1', total: 0),
      order('p2', total: 0, status: OrderStatus.accepted),
      order('q1'),
      order('q2'),
      order('q3'),
      order(
        'a1',
        name: 'Diese-Woche-Fest',
        status: OrderStatus.accepted,
        date: DateTime(2026, 10, 30),
      ),
      order('c1', status: OrderStatus.completed, date: DateTime(2026, 10, 26)),
      order(
        'a2',
        name: 'Spaeter-Fest',
        status: OrderStatus.accepted,
        date: DateTime(2026, 12, 5),
      ),
      order('d1', status: OrderStatus.declined),
    ];

    StaffDashboardView dashboard({
      List<SavedOrder>? orders,
      Object? error,
      bool isAdmin = false,
    }) => StaffDashboardView(
      orders: orders,
      error: error,
      onRetry: () {},
      now: now,
      isAdmin: isAdmin,
      onOpen: (_) {},
    );

    testWidgets('numbers equal the old counts', (tester) async {
      phone(tester, h: 1400);
      final old = dashboardCounts(fixture);
      expect(old.pending, 2);
      expect(old.accepted, 3);
      await pumpApp(tester, app(dashboard(orders: fixture)));
      Finder stat(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(FloatingCard),
      );
      expect(
        find.descendant(
          of: stat('Offen'),
          matching: find.text('${old.pending}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: stat('Angenommen'),
          matching: find.text('${old.accepted}'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: stat('Diese Woche'),
          matching: find.text('${acceptedThisWeek(fixture, now)}'),
        ),
        findsOneWidget,
      );
      // Hero + upcoming list; quote count stays reachable.
      expect(find.text('NÄCHSTER TERMIN'), findsOneWidget);
      expect(find.text('Diese-Woche-Fest'), findsOneWidget);
      expect(find.text('Spaeter-Fest'), findsOneWidget);
      expect(find.text('${old.openOffers} Angebote'), findsOneWidget);
    });

    testWidgets('destinations stay reachable', (tester) async {
      phone(tester, h: 1400);
      await pumpApp(tester, app(dashboard(orders: fixture, isAdmin: true)));
      await tester.tap(find.text('Offene Angebote'));
      await settle(tester);
      expect(lastPage, '/orders?status=quote');
    });

    testWidgets('admin row only for admins', (tester) async {
      phone(tester, h: 1400);
      await pumpApp(tester, app(dashboard(orders: fixture)));
      expect(find.text('Admin-Bereich'), findsNothing);
      await pumpApp(tester, app(dashboard(orders: fixture, isAdmin: true)));
      expect(find.text('Admin-Bereich'), findsOneWidget);
    });

    testWidgets('error state instead of debug output', (tester) async {
      phone(tester);
      await pumpApp(tester, app(dashboard(error: 'boom')));
      expect(find.byType(ErrorState), findsOneWidget);
    });
  });

  group('no overflow at 360 px, text scale 1.3, light and dark', () {
    final long = [
      order(
        'l1',
        name: longName,
        status: OrderStatus.accepted,
        date: DateTime(2026, 11, 1),
        location: 'Sehr langer Ortsname mit Zusatz und Hausnummer 123b',
        persons: 1200,
        total: 123456.78,
        createdBy: 'mitarbeiter.mit.langer.adresse@example.com',
      ),
      order('l2', name: longName, total: 0),
      order('l3', name: longName, status: OrderStatus.completed),
    ];

    for (final dark in [false, true]) {
      final theme = dark ? AppTheme.dark() : AppTheme.light();
      final mode = dark ? 'dark' : 'light';

      testWidgets('overview ($mode)', (tester) async {
        phone(tester);
        await pumpApp(
          tester,
          app(
            overview(
              orders: long,
              pendingCount: 12,
              initialFilter: OrderStatusFilter.all,
            ),
            theme: theme,
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('pending ($mode)', (tester) async {
        phone(tester);
        await pumpApp(
          tester,
          app(
            PendingOrdersView(
              orders: long,
              onRetry: () {},
              onOpen: (_) {},
              onDismiss: (_) async => true,
            ),
            theme: theme,
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('year archive ($mode)', (tester) async {
        phone(tester);
        await pumpApp(
          tester,
          app(
            OrdersYearView(orders: long, onRetry: () {}, onOpen: (_) {}),
            theme: theme,
            textScale: 1.3,
          ),
        );
        await tester.tap(find.text('2026'));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('dashboard ($mode)', (tester) async {
        phone(tester);
        await pumpApp(
          tester,
          app(
            StaffDashboardView(
              orders: long,
              onRetry: () {},
              now: now,
              isAdmin: true,
              onOpen: (_) {},
            ),
            theme: theme,
            textScale: 1.3,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
