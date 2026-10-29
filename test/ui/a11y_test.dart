// Task 19: every VM-testable main screen builds in light and dark at
// 360x640 with text scale 1.3, with and without reduced motion and high
// contrast; the primary screens also meet Flutter's tap-target guidelines.
// The iOS guideline (44x44, = AppSize.minTap) is used on purpose: the spec's
// 46-52 px list cards and 44 px glass buttons cannot meet Android's 48 px.
import 'package:cocktail_planer/models/employee.dart';
import 'package:cocktail_planer/models/material_item.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/models/stock.dart';
import 'package:cocktail_planer/screens/admin/materials_view.dart';
import 'package:cocktail_planer/screens/dashboard/customer_start.dart';
import 'package:cocktail_planer/screens/dashboard/staff_dashboard_view.dart';
import 'package:cocktail_planer/screens/dashboard/widgets/my_requests_list.dart';
import 'package:cocktail_planer/screens/inventory/inventory_view.dart';
import 'package:cocktail_planer/screens/login_screen.dart';
import 'package:cocktail_planer/screens/more/more_view.dart';
import 'package:cocktail_planer/screens/offer/offer_flow.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_view.dart';
import 'package:cocktail_planer/screens/shared/document_sections/document_services.dart';
import 'package:cocktail_planer/screens/orders/order_shopping_list_view.dart';
import 'package:cocktail_planer/screens/orders/orders_overview_view.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/app_sheet.dart';
import 'package:cocktail_planer/ui/widgets/large_title_scaffold.dart';
import 'package:cocktail_planer/utils/currency.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/document_test_harness.dart';
import '../screens/order_detail_test_harness.dart';
import '../screens/order_form_test_harness.dart';

SavedOrder _order() => SavedOrder(
  id: '1',
  name: 'Hochzeit Meier',
  date: DateTime(2026, 11, 20),
  items: const [],
  total: 100,
  personCount: 50,
  drinkerType: 'normal',
  currency: 'CHF',
  status: OrderStatus.quote,
  location: 'Basel',
);

Widget _host(Widget home, {required bool dark}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/:any',
        builder: (_, s) => Scaffold(body: Text('page ${s.uri}')),
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
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        routerConfig: router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
      ),
    ),
  );
}

typedef _Build = Widget Function(bool dark);

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(w);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Features extends FakeAccessibilityFeatures {
  const _Features();
  @override
  bool get disableAnimations => true;
  @override
  bool get highContrast => true;
}

Widget _inventory({required bool empty, required bool dark}) => _host(
  Scaffold(
    body: InventoryView(
      watchStock: () => Stream.value(
        empty
            ? const <StockEntry>[]
            : const [
                StockEntry(
                  id: 'm1|l1|order',
                  materialId: 'm1',
                  materialName: 'Rum',
                  locationId: 'l1',
                  origin: StockOrigin.order,
                  quantity: 3,
                ),
              ],
      ),
      watchLocations: () => Stream.value(
        empty
            ? const <StorageLocation>[]
            : const [StorageLocation(id: 'l1', name: 'Keller')],
      ),
      loadCatalog: () async =>
          const InventoryCatalog([(id: 'm9', name: 'Grenadine')]),
      originLabel: (o) => o.name,
      onArticleTap: (_, _) {},
      onCellTap: (_, _, _) {},
      onManageLocations: () {},
      timeout: inventoryLoadTimeout,
    ),
  ),
  dark: dark,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  final now = DateTime(2026, 10, 27, 10);
  final detail = DetailFakes();
  final doc = FakeDocumentRepository();

  // name -> builder (dark) ; guideline: also run the tap-target checks.
  final screens = <String, (_Build, bool)>{
    'customer start': (
      (d) =>
          _host(CustomerStart(signedIn: false, onOpenRequest: (_) {}), dark: d),
      true,
    ),
    'login': ((d) => _host(const LoginScreen(), dark: d), false),
    'my requests': (
      (d) => _host(
        LargeTitleScaffold(
          title: 'Meine Anfragen',
          slivers: [
            MyRequestsContent(
              streamFactory: () => Stream.value([_order()]),
              onOpen: (_) {},
            ),
          ],
        ),
        dark: d,
      ),
      false,
    ),
    'order list': (
      (d) => _host(
        OrdersOverviewView(
          orders: [_order()],
          onRetry: () {},
          now: now,
          onOpen: (_) {},
          onOpenPending: () {},
          onOpenArchive: () {},
        ),
        dark: d,
      ),
      true,
    ),
    'dashboard': (
      (d) => _host(
        StaffDashboardView(
          orders: [_order()],
          allOrders: [_order()],
          onRetry: () {},
          now: now,
          isAdmin: true,
          onOpen: (_) {},
        ),
        dark: d,
      ),
      false,
    ),
    'more': (
      (d) => _host(
        MoreView(
          user: const MoreUser(name: 'Mia Muster', email: 'mia@example.com'),
          flags: const MoreFlags(
            isAdmin: true,
            canManageUsers: true,
            isAnonymous: false,
            web: true,
          ),
          version: '1.2.3',
          onLinkGoogle: () {},
          onFormSync: () {},
          onLogout: () async {},
        ),
        dark: d,
      ),
      false,
    ),
    'inventory data': ((d) => _inventory(empty: false, dark: d), true),
    'inventory empty': ((d) => _inventory(empty: true, dark: d), false),
    'shopping list': (
      (d) => _host(
        OrderShoppingListView(
          items: const [
            {
              'name': 'Baileys',
              'unit': '0.7L',
              'price': 14.0,
              'quantity': 2,
              'note': 'Kaufland',
            },
          ],
          currency: Currency.fromCode('CHF'),
          staff: true,
          applied: false,
          saving: false,
          entries: const [],
          locations: const [StorageLocation(id: 'l1', name: 'Lager')],
          catalog: const [
            (
              id: 'm1',
              item: MaterialItem(
                unit: '0.7L',
                name: 'Baileys',
                price: 14,
                currency: 'CHF',
                note: '',
              ),
            ),
          ],
          ownLocationId: 'l1',
          onSetSource: (_, _) {},
          onBack: () {},
          onEdit: () {},
        ),
        dark: d,
      ),
      false,
    ),
    'admin list': (
      (d) => _host(
        MaterialsView(
          title: 'Inventar verwalten',
          header: const Text('pills'),
          isFixedValue: false,
          items: [
            (
              id: '1',
              item: const MaterialItem(
                unit: 'Stk',
                name: 'Vodka',
                price: 1.5,
                currency: 'CHF',
                note: '',
              ),
            ),
          ],
          loading: false,
          errorMessage: null,
          onRetry: () {},
          onSave: (_, _) async => true,
          onDelete: (_) async => true,
          onReorder: (_) async {},
        ),
        dark: d,
      ),
      false,
    ),
  };

  for (final dark in [false, true]) {
    for (final special in [false, true]) {
      final tag =
          '${dark ? 'dark' : 'light'}'
          '${special ? ' reduced motion + high contrast' : ''}';
      for (final e in screens.entries) {
        testWidgets('${e.key}: $tag', (tester) async {
          _phone(tester);
          if (special) {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const _Features();
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
          }
          await _pump(tester, e.value.$1(dark));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('order detail: $tag', (tester) async {
        _phone(tester);
        if (special) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const _Features();
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final order = detailOrder();
        await tester.runAsync(() async {
          await tester.pumpWidget(
            detailApp(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showAppSheet<void>(
                      context,
                      full: true,
                      builder: (_) => OrderDetailView(
                        order: order,
                        currency: Currency.fromCode(order.currency),
                        services: detail.services,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
              textScale: 1.3,
              theme: dark ? AppTheme.dark() : AppTheme.light(),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      });

      for (final step in [0, 4]) {
        testWidgets('order form step $step: $tag', (tester) async {
          _phone(tester);
          if (special) {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const _Features();
            addTearDown(
              tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
            );
          }
          final h = Harness(url: stepUrl(step));
          await pumpForm(
            tester,
            h.app(
              textScale: 1.3,
              theme: dark ? AppTheme.dark() : AppTheme.light(),
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('offer flow step 1: $tag', (tester) async {
        _phone(tester);
        if (special) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const _Features();
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final services = DocumentServices(
          displayName: () => 'Ida',
          watchEmployees: () =>
              Stream.value(const [Employee(id: 'e1', name: 'Ana')]),
          watchAdditionalServices: () => Stream.value(const []),
          loadCocktailNames: () async => const ['Mojito'],
          generateShareMiddle:
              ({
                required originalCocktails,
                required selectedCocktails,
                required allAvailableCocktails,
              }) async => null,
          orderRepository: doc,
          shareLinkRepository: FakeShareLinks(),
        );
        await _pump(
          tester,
          _host(
            OfferFlow(order: offerOrder(), services: services),
            dark: dark,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('tap-target guidelines', () {
    for (final dark in [false, true]) {
      for (final e in screens.entries.where((e) => e.value.$2)) {
        testWidgets('${e.key} dark=$dark', (tester) async {
          final handle = tester.ensureSemantics();
          _phone(tester);
          await _pump(tester, e.value.$1(dark));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        });
      }
      testWidgets('order form step 0 dark=$dark', (tester) async {
        final handle = tester.ensureSemantics();
        _phone(tester);
        final h = Harness(url: stepUrl(0));
        await pumpForm(
          tester,
          h.app(
            textScale: 1.3,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
          ),
        );
        await settle(tester);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });
}
