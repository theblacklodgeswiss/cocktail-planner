// The offer and invoice screens as four-step flows (Task 18): same totals
// and saved data as before the redesign (reusing the characterization
// inputs of document_logic_test.dart), step reachability and the soft
// "Weiter", the share sheet instead of a dialog, the missing-extra empty
// state and the layout at 360x640 with text scale 1.3 in both themes, with
// and without the keyboard.
import 'package:cocktail_planer/models/employee.dart';
import 'package:cocktail_planer/screens/invoice/invoice_flow.dart';
import 'package:cocktail_planer/screens/offer/offer_flow.dart';
import 'package:cocktail_planer/screens/offer/widgets/offer_share_dialog.dart';
import 'package:cocktail_planer/screens/shared/document_sections/document_flow.dart';
import 'package:cocktail_planer/screens/shared/document_sections/document_services.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/utils/currency.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_test_harness.dart';

const _employees = [
  Employee(id: 'e1', name: 'Ana'),
  Employee(id: 'e2', name: 'Ben'),
];

class _H {
  final repo = FakeDocumentRepository();
  final links = FakeShareLinks();

  DocumentServices get services => DocumentServices(
    displayName: () => 'Ida',
    watchEmployees: () => Stream.value(_employees),
    watchAdditionalServices: () => Stream.value(const []),
    loadCocktailNames: () async => const ['Mojito', 'Hugo', 'Negroni'],
    generateShareMiddle:
        ({
          required originalCocktails,
          required selectedCocktails,
          required allAvailableCocktails,
        }) async => null,
    orderRepository: repo,
    shareLinkRepository: links,
  );

  Widget app(
    Widget Function(DocumentServices s) page, {
    ThemeData? theme,
    double textScale = 0.5,
  }) {
    final router = GoRouter(
      initialLocation: '/doc',
      routes: [
        GoRoute(path: '/doc', builder: (_, _) => page(services)),
        GoRoute(
          path: '/create-offer',
          builder: (_, state) => documentRoute(
            state.extra,
            (o) => OfferFlow(order: o, services: services),
          ),
        ),
        GoRoute(
          path: '/orders',
          builder: (_, _) => const Scaffold(body: Text('page /orders')),
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
          routerConfig: router,
          theme: theme,
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
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder get _primary => find.byType(PrimaryButton).last;

String _title(int step) =>
    const [
      'Kunde und Termin',
      'Leistungen und Mitarbeiter',
      'Positionen',
      'Preis, Rabatt, Senden',
    ][step];

Future<void> _openMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.more_horiz));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

final _chf = Currency.fromCode('CHF');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    // Clipboard writes succeed silently.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  group('offer flow', () {
    testWidgets('walks the four steps; back returns step by step', (
      tester,
    ) async {
      _tall(tester);
      final h = _H();
      await _pump(
        tester,
        h.app(
          (s) => OfferFlow(order: offerOrder(eventType: 'birthday'), services: s),
        ),
      );
      for (var step = 0; step < 3; step++) {
        expect(find.text(_title(step)), findsOneWidget);
        expect(tester.widget<PrimaryButton>(_primary).label, 'Weiter');
        await tester.tap(_primary);
        await tester.pumpAndSettle();
      }
      expect(find.text(_title(3)), findsOneWidget);
      expect(tester.widget<PrimaryButton>(_primary).label, 'Senden');
      // System back walks back one step (PopScope).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(_title(2)), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text(_title(1)), findsOneWidget);
    });

    testWidgets('soft Weiter: first tap shows the hint, second continues', (
      tester,
    ) async {
      _tall(tester);
      final h = _H();
      await _pump(tester, h.app((s) => OfferFlow(order: offerOrder(), services: s)));
      expect(tester.widget<PrimaryButton>(_primary).dimmed, isTrue);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.text(_title(0)), findsOneWidget);
      expect(find.text('offer.event_type_required'.tr()), findsOneWidget);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.text(_title(1)), findsOneWidget);
    });

    testWidgets('the step label jumps to any step', (tester) async {
      _tall(tester);
      final h = _H();
      await _pump(tester, h.app((s) => OfferFlow(order: offerOrder(), services: s)));
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_title(3)).last);
      await tester.pumpAndSettle();
      expect(find.text(_title(3)), findsOneWidget);
    });

    testWidgets('same total as before; save writes the same data', (
      tester,
    ) async {
      _tall(tester);
      final h = _H();
      await _pump(
        tester,
        h.app(
          (s) => OfferFlow(
            order: offerOrder(discountPercent: 10, eventType: 'wedding'),
            services: s,
            initialStep: 3,
          ),
        ),
      );
      // Characterization: 1000 subtotal - 10 % = 900.
      expect(find.text(_chf.format(900)), findsWidgets);
      await _openMenuItem(tester, 'offer.save_only'.tr());
      final a = h.repo.offerDataCalls.single;
      expect(a['discount'], 100);
      expect(a['discountPercent'], 10);
      expect(a['eventTypes'], ['wedding']);
      expect(a['barCost'], 150);
      expect(h.repo.cocktailsCalls.single['cocktails'], ['Mojito', 'Hugo']);
      expect(find.text('page /orders'), findsOneWidget);
    });

    testWidgets('a final action with gaps jumps to the faulty step', (
      tester,
    ) async {
      _tall(tester);
      final h = _H();
      await _pump(
        tester,
        h.app(
          (s) => OfferFlow(order: offerOrder(), services: s, initialStep: 3),
        ),
      );
      await _openMenuItem(tester, 'offer.save_only'.tr());
      expect(find.text(_title(0)), findsOneWidget);
      expect(find.text('offer.event_type_required'.tr()), findsOneWidget);
      expect(h.repo.offerDataCalls, isEmpty);
    });

    testWidgets('Senden opens the share sheet, not a dialog', (tester) async {
      _tall(tester);
      final h = _H();
      await _pump(
        tester,
        h.app(
          (s) => OfferFlow(
            order: offerOrder(eventType: 'birthday'),
            services: s,
            initialStep: 3,
          ),
        ),
      );
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.byType(OfferShareSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.ensureVisible(find.text('offer.copy_link'.tr()));
      await tester.tap(find.text('offer.copy_link'.tr()));
      await tester.pumpAndSettle();
      expect(h.links.offerLinks.single.$2, 'o1');
      expect(h.links.offerLinks.single.$1.grandTotal, closeTo(1000, 1e-9));
    });
  });

  group('invoice flow', () {
    testWidgets('same total as before; PDF saves, links and copies', (
      tester,
    ) async {
      _tall(tester);
      final h = _H();
      await _pump(
        tester,
        h.app(
          (s) => InvoiceFlow(order: invoiceOrder(), services: s, initialStep: 3),
        ),
      );
      // Characterization: 1272 - 5 % = 1208.40.
      expect(find.text(_chf.format(1208.4)), findsWidgets);
      expect(tester.widget<PrimaryButton>(_primary).label, 'invoice.generate_pdf'.tr());
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      // Confirmation sheet instead of a dialog.
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('common.save'.tr()).last);
      await tester.pumpAndSettle();
      expect(h.repo.totalsCalls.single['total'], closeTo(1000, 1e-9));
      expect(h.repo.offerDataCalls.single['discount'], closeTo(63.6, 1e-9));
      expect(h.links.invoiceLinks.single.offerExtraHours, 2);
    });

    testWidgets('employees are pickable on step 2 and required', (
      tester,
    ) async {
      _tall(tester);
      final h = _H();
      await _pump(
        tester,
        h.app(
          (s) => InvoiceFlow(
            order: invoiceOrder(assignedEmployees: const []),
            services: s,
            initialStep: 3,
          ),
        ),
      );
      await _openMenuItem(tester, 'invoice.save'.tr());
      expect(find.text(_title(1)), findsOneWidget);
      expect(find.text('invoice.employees_required'.tr()), findsWidgets);
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_title(3)).last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _openMenuItem(tester, 'invoice.save'.tr());
      expect(h.repo.offerDataCalls.single['assignedEmployees'], ['Ana']);
    });

    testWidgets('positions mode lists positions as cards', (tester) async {
      _tall(tester);
      final h = _H();
      await _pump(
        tester,
        h.app(
          (s) => InvoiceFlow(
            order: invoiceOrder(
              offerPositions: const [
                {'name': 'Service', 'price': 300.0, 'quantity': 2},
              ],
            ),
            services: s,
            initialStep: 2,
          ),
        ),
      );
      expect(find.text('Service'), findsOneWidget);
      expect(find.text(_chf.format(600)), findsOneWidget);
      final edit = tester.getSize(find.byIcon(Icons.edit_outlined));
      expect(edit, isNotNull);
      expect(
        tester.getSize(find.ancestor(
          of: find.byIcon(Icons.edit_outlined),
          matching: find.byType(SizedBox),
        ).first).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  testWidgets('a missing route extra shows the empty state', (tester) async {
    _tall(tester);
    final h = _H();
    await _pump(
      tester,
      h.app(
        (s) => Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => context.go('/create-offer'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('docflow.missing_title'.tr()), findsOneWidget);
    await tester.tap(find.text('docflow.to_orders'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('page /orders'), findsOneWidget);
  });

  group('layout at 360x640, text scale 1.3', () {
    final flows = <String, Widget Function(DocumentServices, int)>{
      'offer': (s, step) =>
          OfferFlow(order: offerOrder(), services: s, initialStep: step),
      'invoice': (s, step) =>
          InvoiceFlow(order: invoiceOrder(), services: s, initialStep: step),
      'invoice positions': (s, step) => InvoiceFlow(
        order: invoiceOrder(
          offerPositions: const [
            {'name': 'Cocktail- & Barservice', 'price': 1234.5, 'quantity': 1},
            {'name': 'Reisekosten', 'price': 0.7, 'quantity': 120},
          ],
        ),
        services: s,
        initialStep: step,
      ),
    };
    for (final entry in flows.entries) {
      for (final dark in [false, true]) {
        for (final keyboard in [0.0, 300.0]) {
          for (var step = 0; step < 4; step++) {
            testWidgets(
              '${entry.key} step ${step + 1}, ${dark ? 'dark' : 'light'}, keyboard $keyboard',
              (tester) async {
                tester.view.physicalSize = const Size(360, 640);
                tester.view.devicePixelRatio = 1;
                tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
                addTearDown(tester.view.reset);
                final h = _H();
                await _pump(
                  tester,
                  h.app(
                    (s) => entry.value(s, step),
                    theme: dark ? AppTheme.dark() : AppTheme.light(),
                    textScale: 1.3,
                  ),
                );
                // Show the hints too (soft Weiter / final action).
                await tester.tap(_primary);
                await tester.pumpAndSettle();
                if (find.text('ui.cancel'.tr()).evaluate().isNotEmpty) {
                  await tester.tap(find.text('ui.cancel'.tr()).last);
                  await tester.pumpAndSettle();
                }
                expect(tester.takeException(), isNull);
                final button = tester.getRect(_primary);
                expect(button.top, greaterThan(0));
                expect(button.bottom, lessThanOrEqualTo(640 - keyboard));
                expect(button.height, greaterThanOrEqualTo(44));
              },
            );
          }
        }
      }
    }
  });
}
