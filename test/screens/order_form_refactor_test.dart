// Characterization tests for ModernOrderFormScreen (Task 8 safety net).
//
// These tests pin the CURRENT behavior of the 9-step order wizard - written
// and run against the monolithic screen before it was split into step
// widgets, then re-run unchanged afterwards. They pump the real screen with
// fakes injected through `OrderFormServices` (no Firebase, no network, no
// browser URL).
import 'dart:async';

import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/models/additional_service.dart';
import 'package:cocktail_planer/models/cocktail_data.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/models/recipe.dart';
import 'package:cocktail_planer/screens/forms/modern_order_form_screen.dart';
import 'package:cocktail_planer/screens/forms/order_form_services.dart';
import 'package:cocktail_planer/state/app_state.dart';
import 'package:cocktail_planer/widgets/order_setup_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeOrderRepository extends OrderRepository {
  final List<Map<String, dynamic>> saveCalls = [];
  final List<(String, Map<String, dynamic>)> updateCalls = [];
  String? saveResult = 'new-order-id';

  @override
  Future<String?> saveOrder({
    required String name,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double total,
    required String currency,
    int personCount = 0,
    String drinkerType = 'normal',
    String status = 'quote',
    List<String> cocktails = const [],
    List<String> shots = const [],
    List<Map<String, dynamic>> shotQuantities = const [],
    String bar = '',
    int distanceKm = 0,
    double thekeCost = 0,
    String phone = '',
    String location = '',
    String eventTime = '',
    String serviceType = 'cocktail_barservice',
    Map<String, double> cocktailPopularity = const {},
    List<String> barDrinks = const [],
    List<String> alcoholPurchase = const [],
    List<String> additionalServices = const [],
    String remarks = '',
    String eventType = '',
  }) async {
    saveCalls.add({
      'name': name,
      'date': date,
      'items': items,
      'total': total,
      'currency': currency,
      'personCount': personCount,
      'drinkerType': drinkerType,
      'status': status,
      'cocktails': cocktails,
      'shots': shots,
      'shotQuantities': shotQuantities,
      'bar': bar,
      'distanceKm': distanceKm,
      'thekeCost': thekeCost,
      'phone': phone,
      'location': location,
      'eventTime': eventTime,
      'serviceType': serviceType,
      'cocktailPopularity': Map<String, double>.from(cocktailPopularity),
      'barDrinks': barDrinks,
      'alcoholPurchase': alcoholPurchase,
      'additionalServices': additionalServices,
      'remarks': remarks,
      'eventType': eventType,
    });
    return saveResult;
  }

  @override
  Future<bool> updateOrder(String orderId, Map<String, dynamic> data) async {
    updateCalls.add((orderId, data));
    return true;
  }
}

const mojito = Recipe(id: 'r1', name: 'Mojito', ingredients: ['Rum']);
const caipirinha = Recipe(
  id: 'r2',
  name: 'Caipirinha',
  ingredients: ['Cachaça'],
);
const tequila = Recipe(
  id: 'r3',
  name: 'Tequila',
  ingredients: ['Tequila'],
  type: 'shot',
);

const photobooth = AdditionalService(
  id: 'photobooth',
  name: 'Fotobox',
  variants: [ServiceVariant(id: 'v3h', name: '3 Stunden', price: 300)],
);

/// Test harness: fakes + recorded side effects for one pumped form.
class Harness {
  Harness({
    this.isStaff = false,
    String url = 'http://localhost/order-form',
    Map<String, Completer<int?>>? distanceCompleters,
  }) : _url = url,
       _distanceCompleters = distanceCompleters;

  final bool isStaff;
  final String _url;
  final Map<String, Completer<int?>>? _distanceCompleters;
  final repo = FakeOrderRepository();
  final urls = <String>[];
  final distanceRequests = <String>[];
  final submitted = <OrderFormResult>[];
  Object? shoppingListExtra;

  OrderFormServices get services => OrderFormServices(
    isEmployeeOrHigher: () => isStaff,
    resolveRole: () async {},
    loadCocktailData: () async => const CocktailData(
      materials: [],
      recipes: [mojito, caipirinha, tequila],
    ),
    watchAdditionalServices: () => Stream.value(const [photobooth]),
    distanceKmFromAddress: (address) {
      distanceRequests.add(address);
      final completers = _distanceCompleters;
      if (completers != null) return completers[address]!.future;
      return Future.value(42);
    },
    currentUri: () => Uri.parse(_url),
    updateUrl: urls.add,
    orderRepository: repo,
  );

  Widget app({SavedOrder? prefill, bool withOnSubmit = false}) {
    final router = GoRouter(
      initialLocation: '/order-form',
      routes: [
        GoRoute(
          path: '/order-form',
          builder: (_, _) => ModernOrderFormScreen(
            prefill: prefill,
            services: services,
            onSubmit: withOnSubmit ? submitted.add : null,
          ),
        ),
        GoRoute(
          path: '/shopping-list',
          builder: (_, state) {
            shoppingListExtra = state.extra;
            return const Scaffold(body: Text('page /shopping-list'));
          },
        ),
        GoRoute(
          path: '/order-success',
          builder: (_, _) => const Scaffold(body: Text('page /order-success')),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const Scaffold(body: Text('page /dashboard')),
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
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          // The test font (Ahem) renders every glyph as a full square, so
          // German labels overflow fixed-width rows that fit in real fonts.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.5)),
            child: child!,
          ),
        ),
      ),
    );
  }
}

SavedOrder prefillOrder({
  String id = 'order-1',
  String name = '',
  String phone = '',
  String location = '',
  String eventTime = '',
  String offerEventTime = '',
  String eventType = '',
  String serviceType = '',
  int personCount = 0,
  int distanceKm = 0,
  String currency = '',
  String drinkerType = '',
  List<String> cocktails = const [],
  List<String> requestedCocktails = const [],
  List<String> shots = const [],
  List<ShotSelection> shotSelections = const [],
  List<String> barDrinks = const [],
  List<String> alcoholPurchase = const [],
  List<String> additionalServices = const [],
  Map<String, double> cocktailPopularity = const {},
  String remarks = '',
  String guestCountRange = '',
  List<Map<String, dynamic>> items = const [],
}) => SavedOrder(
  id: id,
  name: name,
  date: DateTime(2027, 5, 1),
  items: items,
  total: 0,
  personCount: personCount,
  drinkerType: drinkerType,
  currency: currency,
  status: OrderStatus.quote,
  phone: phone,
  location: location,
  eventTime: eventTime,
  offerEventTime: offerEventTime,
  eventType: eventType,
  serviceType: serviceType,
  distanceKm: distanceKm,
  cocktails: cocktails,
  requestedCocktails: requestedCocktails,
  shots: shots,
  shotSelections: shotSelections,
  barDrinks: barDrinks,
  alcoholPurchase: alcoholPurchase,
  additionalServices: additionalServices,
  cocktailPopularity: cocktailPopularity,
  remarks: remarks,
  guestCountRange: guestCountRange,
);

/// A prefill that satisfies every `_canProceed` gate.
SavedOrder completePrefill({
  List<String> cocktails = const ['Mojito'],
  List<String> shots = const ['Tequila'],
  String serviceType = 'cocktail_barservice',
}) => prefillOrder(
  name: 'Max Prefill',
  phone: '079 000 00 00',
  location: 'Basel',
  eventTime: '19:30',
  eventType: 'birthday',
  serviceType: serviceType,
  cocktails: cocktails,
  shots: shots,
  shotSelections: const [ShotSelection(name: 'Tequila', quantity: 4)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    appState.clearPendingFormOrder();
    appState.clearLinkedOrder();
    appState.setSelectedRecipes(const []);
    appState.cocktailPopularity.clear();
  });

  void mobile(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpForm(WidgetTester tester, Widget app) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Lets a page animation (300 ms) and any pending debounce (800 ms) finish.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
  }

  Finder mobileNext() => find.widgetWithText(FilledButton, 'Weiter');

  bool enabled(WidgetTester tester, Finder finder) =>
      tester.widget<ButtonStyleButton>(finder).onPressed != null;

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(mobileNext().first);
    await settle(tester);
  }

  /// Runs a modal bottom sheet's open/close animation to completion.
  Future<void> sheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> pickTime(WidgetTester tester) async {
    await tester.tap(find.text('Uhrzeit auswählen'));
    await sheet(tester);
    await tester.tap(find.text('OK').last);
    await sheet(tester);
  }

  Future<void> pickDate(WidgetTester tester) async {
    await tester.tap(find.text('Datum auswählen'));
    await sheet(tester);
    await tester.tap(find.text('OK').last);
    await sheet(tester);
  }

  group('canProceed per step (mobile Weiter button)', () {
    testWidgets('step 0 (service type) always proceeds', (tester) async {
      mobile(tester);
      final h = Harness();
      await pumpForm(tester, h.app());
      expect(find.text('Welchen Service benötigst du?'), findsOneWidget);
      expect(enabled(tester, mobileNext()), isTrue);
      await settle(tester);
    });

    testWidgets('step 1 requires trimmed name AND phone', (tester) async {
      mobile(tester);
      final h = Harness(url: 'http://localhost/order-form?step=1');
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Deine Kontaktdaten'), findsOneWidget);
      expect(enabled(tester, mobileNext()), isFalse);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Anna');
      await tester.pump();
      expect(enabled(tester, mobileNext()), isFalse, reason: 'phone missing');

      await tester.enterText(fields.at(1), '   ');
      await tester.pump();
      expect(enabled(tester, mobileNext()), isFalse, reason: 'blank phone');

      await tester.enterText(fields.at(1), '079');
      await tester.pump();
      expect(enabled(tester, mobileNext()), isTrue);

      await tester.enterText(fields.at(0), '  ');
      await tester.pump();
      expect(enabled(tester, mobileNext()), isFalse, reason: 'blank name');
    });

    testWidgets('step 2 requires date AND time AND address', (tester) async {
      mobile(tester);
      final h = Harness(url: 'http://localhost/order-form?step=2');
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Event-Details'), findsWidgets);
      expect(enabled(tester, mobileNext()), isFalse);

      await tester.enterText(find.byType(TextField).first, 'Basel');
      await settle(tester);
      expect(enabled(tester, mobileNext()), isFalse, reason: 'no date/time');

      await pickDate(tester);
      expect(enabled(tester, mobileNext()), isFalse, reason: 'no time');

      await pickTime(tester);
      expect(find.text('18:00'), findsOneWidget);
      expect(enabled(tester, mobileNext()), isTrue);

      await tester.enterText(find.byType(TextField).first, ' ');
      await settle(tester);
      expect(enabled(tester, mobileNext()), isFalse, reason: 'blank address');
    });

    testWidgets('step 3 requires an event type (single-select toggle)', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: 'http://localhost/order-form?step=3');
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Deine Präferenzen'), findsOneWidget);
      expect(enabled(tester, mobileNext()), isFalse);

      await tester.tap(find.text('Hochzeitsfeier'));
      await tester.pump();
      expect(enabled(tester, mobileNext()), isTrue);

      // Tapping the selected chip again deselects it.
      await tester.tap(find.text('Hochzeitsfeier'));
      await tester.pump();
      expect(enabled(tester, mobileNext()), isFalse);
    });

    for (final step in [4, 5, 6, 7]) {
      testWidgets('step $step always proceeds, even with nothing selected', (
        tester,
      ) async {
        mobile(tester);
        final h = Harness(url: 'http://localhost/order-form?step=$step');
        await pumpForm(tester, h.app());
        await settle(tester);
        expect(enabled(tester, mobileNext()), isTrue);
      });
    }

    testWidgets('step 8 shows the submit button instead of Weiter', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: 'http://localhost/order-form?step=8');
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Anfrageübersicht'), findsOneWidget);
      expect(mobileNext(), findsNothing);
      // Bottom bar + the overview's own action row both render it.
      expect(find.text('Antrag einreichen'), findsNWidgets(2));
    });
  });

  group('submit validation jumps to the faulty step', () {
    testWidgets('missing name -> step 1 (desktop shows step 1 content)', (
      tester,
    ) async {
      desktop(tester);
      final h = Harness(url: 'http://localhost/order-form?step=8');
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Anfrageübersicht'), findsOneWidget);

      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      expect(find.text('Name ist erforderlich'), findsOneWidget);
      expect(find.text('Deine Kontaktdaten'), findsWidgets);
      expect(h.urls.last, 'http://localhost/order-form?step=1');
      expect(h.repo.saveCalls, isEmpty);
      await settle(tester);
    });

    testWidgets('name but no date -> step 2', (tester) async {
      desktop(tester);
      final h = Harness(url: 'http://localhost/order-form?step=1');
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Anna');
      await tester.pump();
      // Desktop stepper allows jumping freely to the overview.
      await tester.tap(find.text('Zusammenfassung'));
      await tester.pump();
      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      expect(find.text('Datum ist erforderlich'), findsOneWidget);
      expect(h.urls.last, 'http://localhost/order-form?step=2');
      expect(find.text('Datum auswählen'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('name + date but no cocktails -> step 5', (tester) async {
      desktop(tester);
      final h = Harness(url: 'http://localhost/order-form?step=8');
      await pumpForm(tester, h.app(prefill: prefillOrder(name: 'Anna')));
      await settle(tester);
      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      expect(
        find.text('Bitte wähle mindestens einen Cocktail'),
        findsOneWidget,
      );
      expect(h.urls.last, 'http://localhost/order-form?step=5');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Cocktail-Auswahl'), findsWidgets);
      await settle(tester);
    });

    testWidgets(
      'mobile: jump updates step/footer but NOT the PageView page (quirk)',
      (tester) async {
        mobile(tester);
        final h = Harness(url: 'http://localhost/order-form?step=8');
        await pumpForm(tester, h.app());
        await settle(tester);
        await tester.tap(find.text('Antrag einreichen').first);
        await tester.pump();
        expect(find.text('Name ist erforderlich'), findsOneWidget);
        expect(h.urls.last, 'http://localhost/order-form?step=1');
        // Footer now belongs to step 1 (Weiter disabled: name/phone empty)...
        expect(enabled(tester, mobileNext()), isFalse);
        // ...while the PageView still shows the overview page.
        expect(find.text('Anfrageübersicht'), findsOneWidget);
        await settle(tester);
      },
    );
  });

  group('URL step sync', () {
    testWidgets('?step=3 opens step 3 (mobile)', (tester) async {
      mobile(tester);
      final h = Harness(url: 'http://localhost/order-form?step=3');
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Deine Präferenzen'), findsOneWidget);
      expect(h.urls, isEmpty, reason: 'step param present -> no URL rewrite');
    });

    testWidgets('?step=3 opens step 3 (desktop)', (tester) async {
      desktop(tester);
      final h = Harness(url: 'http://localhost/order-form?step=3');
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Deine Präferenzen'), findsWidgets);
    });

    testWidgets('out-of-range ?step=9 stays on step 0', (tester) async {
      mobile(tester);
      final h = Harness(url: 'http://localhost/order-form?step=9');
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Welchen Service benötigst du?'), findsOneWidget);
    });

    testWidgets('no step param -> URL rewritten to step=0; Weiter/Zurück '
        'rewrite step', (tester) async {
      mobile(tester);
      final h = Harness();
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(h.urls, ['http://localhost/order-form?step=0']);
      await tapNext(tester);
      expect(find.text('Deine Kontaktdaten'), findsOneWidget);
      expect(h.urls.last, 'http://localhost/order-form?step=1');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Zurück'));
      await settle(tester);
      expect(find.text('Welchen Service benötigst du?'), findsOneWidget);
      expect(h.urls.last, 'http://localhost/order-form?step=0');
    });

    testWidgets('AppBar back on step 0 goes to /dashboard when it cannot pop', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness();
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.text('page /dashboard'), findsOneWidget);
    });
  });

  group('distance auto-calculation (guest)', () {
    testWidgets('debounced 800 ms, shows calculating, then km', (tester) async {
      mobile(tester);
      final h = Harness(url: 'http://localhost/order-form?step=2');
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Bern');
      await tester.pump(const Duration(milliseconds: 700));
      expect(h.distanceRequests, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.distanceRequests, ['Bern']);
      await tester.pump();
      // Go to preferences (step 3) via the desktop-free path: date+time.
      await pickDate(tester);
      await pickTime(tester);
      await tapNext(tester);
      expect(find.text('42 km'), findsOneWidget);
    });

    testWidgets('stale lookup result is discarded', (tester) async {
      mobile(tester);
      final completers = {'Alt': Completer<int?>(), 'Neu': Completer<int?>()};
      final h = Harness(
        url: 'http://localhost/order-form?step=2',
        distanceCompleters: completers,
      );
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Alt');
      await tester.pump(const Duration(milliseconds: 900));
      await tester.enterText(find.byType(TextField).first, 'Neu');
      await tester.pump(const Duration(milliseconds: 900));
      expect(h.distanceRequests, ['Alt', 'Neu']);
      completers['Neu']!.complete(7);
      await tester.pump();
      completers['Alt']!.complete(99);
      await tester.pump();
      await pickDate(tester);
      await pickTime(tester);
      await tapNext(tester);
      expect(find.text('7 km'), findsOneWidget);
    });

    testWidgets('staff never trigger a lookup and see the slider', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(
        isStaff: true,
        url: 'http://localhost/order-form?step=2',
      );
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Bern');
      await settle(tester);
      expect(h.distanceRequests, isEmpty);
      await pickDate(tester);
      await pickTime(tester);
      await tapNext(tester);
      expect(find.text('10 km'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
    });
  });

  group('golden saveOrder (guest)', () {
    testWidgets('full walkthrough produces the exact saveOrder arguments', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness();
      // Only the date is prefilled (the Cupertino date picker defaults to
      // "now", which is not deterministic).
      await pumpForm(tester, h.app(prefill: prefillOrder()));
      await settle(tester);

      // Step 0: service type (default stays cocktail_barservice).
      await tester.tap(find.text('Cocktail- & Barservice'));
      await tester.pump();
      await tapNext(tester);

      // Step 1: contact.
      await tester.enterText(find.byType(TextField).at(0), ' Anna Muster ');
      await tester.enterText(find.byType(TextField).at(1), '+41 79 123 45 67');
      await tester.pump();
      await tapNext(tester);

      // Step 2: event details.
      await pickTime(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'Bahnhofstrasse 1, Basel',
      );
      await settle(tester);
      await tapNext(tester);

      // Step 3: preferences.
      expect(find.text('42 km'), findsOneWidget);
      await tester.tap(find.text('Viel'));
      await tester.tap(find.text('EUR'));
      await tester.tap(find.text('Hochzeitsfeier'));
      await tester.pump();
      await tapNext(tester);

      // Step 4: bar drinks + alcohol.
      await tester.tap(find.text('Gin & Mischgetränke'));
      await tester.tap(find.text('Gin Bulldog 0.7L - 35,-'));
      await tester.pump();
      await tapNext(tester);

      // Step 5: cocktails + a shot with quantity 3.
      await tester.tap(find.text('Mojito'));
      await tester.pump();
      await tester.tap(find.text('Tequila'));
      await tester.pump();
      expect(find.text('2 Cocktails ausgewählt'), findsOneWidget);
      // Search field is first, the shot quantity field last.
      await tester.enterText(find.byType(TextField).last, '3');
      await tester.pump();
      await tapNext(tester);

      // Step 6: popularity (defaults to 50 % each).
      expect(find.text('50%'), findsNWidgets(2));
      await tapNext(tester);

      // Step 7: additional services (variant picker) + other + remarks.
      await tester.tap(find.text('Fotobox'));
      await sheet(tester);
      await tester.tap(find.text('3 Stunden'));
      await tester.pump();
      await tester.tap(find.text('OK').last);
      await sheet(tester);
      expect(find.text('3 Stunden (300 EUR)'), findsOneWidget);
      await tester.tap(find.text('Sonstiges'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, ' Bitte pünktlich ');
      await tester.pump();
      await tapNext(tester);

      // Step 8: overview + submit.
      expect(find.text('Anfrageübersicht'), findsOneWidget);
      expect(find.text('Anna Muster'), findsOneWidget);
      await tester.tap(find.text('Antrag einreichen').first);
      await tester.pump();
      await settle(tester);

      expect(h.repo.saveCalls, hasLength(1));
      expect(h.repo.saveCalls.single, {
        'name': 'Anna Muster',
        'date': DateTime(2027, 5, 1),
        'items': <Map<String, dynamic>>[],
        'total': 0.0,
        'currency': 'EUR',
        'personCount': 100,
        'drinkerType': 'heavy',
        'status': 'quote',
        'cocktails': ['Mojito'],
        'shots': ['Tequila'],
        'shotQuantities': [
          {'name': 'Tequila', 'quantity': 3},
        ],
        'bar': '',
        'distanceKm': 42,
        'thekeCost': 0.0,
        'phone': '+41 79 123 45 67',
        'location': 'Bahnhofstrasse 1, Basel',
        'eventTime': '18:00',
        'serviceType': 'cocktail_barservice',
        'cocktailPopularity': {'Mojito': 50.0, 'Tequila': 50.0},
        'barDrinks': ['gin_mix'],
        'alcoholPurchase': ['gin_bulldog'],
        'additionalServices': ['photobooth:v3h', 'other_services'],
        'remarks': 'Bitte pünktlich',
        'eventType': 'wedding',
      });
      expect(find.text('page /order-success'), findsOneWidget);
    });

    testWidgets('prefill round-trip + mocktail switch clears shots', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness();
      await pumpForm(
        tester,
        h.app(
          prefill: prefillOrder(
            name: 'Prefill Gast',
            phone: '061',
            location: 'Allschwil',
            offerEventTime: '20:15',
            eventTime: '10:00',
            eventType: 'company',
            serviceType: 'cocktailservice',
            personCount: 250,
            distanceKm: 33,
            currency: 'USD',
            drinkerType: 'light',
            requestedCocktails: ['Mojito (2x)', 'Unbekannt'],
            shots: ['Tequila'],
            shotSelections: const [ShotSelection(name: 'Tequila', quantity: 4)],
            barDrinks: ['vodka_mix'],
            alcoholPurchase: ['vodka_ciroc'],
            additionalServices: [
              'photobooth:v3h',
              'booth_360',
              'other_services',
            ],
            cocktailPopularity: {'Mojito': 80.0, 'Tequila': 30.0},
            remarks: 'Alt',
          ),
        ),
      );
      await settle(tester);

      // Step 0: switch to mocktails -> shots removed.
      await tester.tap(find.text('Nur Mocktailservice'));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tapNext(tester);
      }
      expect(find.text('Anfrageübersicht'), findsOneWidget);
      await tester.tap(find.text('Antrag einreichen').first);
      await tester.pump();
      await settle(tester);

      expect(h.repo.saveCalls.single, {
        'name': 'Prefill Gast',
        'date': DateTime(2027, 5, 1),
        'items': <Map<String, dynamic>>[],
        'total': 0.0,
        'currency': 'USD',
        'personCount': 250,
        'drinkerType': 'light',
        'status': 'quote',
        'cocktails': ['Mojito'],
        'shots': <String>[],
        'shotQuantities': <Map<String, dynamic>>[],
        'bar': '',
        // The prefilled address triggered a guest lookup (fake: 42 km).
        'distanceKm': 42,
        'thekeCost': 0.0,
        'phone': '061',
        'location': 'Allschwil',
        'eventTime': '20:15',
        'serviceType': 'mocktail_service',
        'cocktailPopularity': {'Mojito': 80.0},
        'barDrinks': ['vodka_mix'],
        'alcoholPurchase': ['vodka_ciroc'],
        'additionalServices': ['photobooth:v3h', 'booth_360', 'other_services'],
        'remarks': 'Alt',
        'eventType': 'company',
      });
    });

    testWidgets('saveOrder returning null shows the save error', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: 'http://localhost/order-form?step=8');
      h.repo.saveResult = null;
      await pumpForm(tester, h.app(prefill: completePrefill()));
      await settle(tester);
      await tester.tap(find.text('Antrag einreichen').first);
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          'Fehler beim Speichern der Anfrage. Bitte versuche es später erneut.',
        ),
        findsOneWidget,
      );
      expect(find.text('page /order-success'), findsNothing);
      await settle(tester);
    });
  });

  group('staff branch', () {
    testWidgets('no prefill: syncs appState and goes to /shopping-list', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(
        isStaff: true,
        url: 'http://localhost/order-form?step=8',
      );
      // A prefill would switch to the update branch, so fill via URL steps.
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Auftragsübersicht'), findsOneWidget);
      expect(find.text('Mit Claude Einkaufsliste generieren'), findsOneWidget);
      expect(find.text('Einkaufsliste generieren'), findsNWidgets(2));

      // Missing name -> validation applies to staff too.
      await tester.tap(find.text('Einkaufsliste generieren').first);
      await tester.pump();
      expect(find.text('Name ist erforderlich'), findsOneWidget);
      await settle(tester);
    });

    /// Desktop: name/phone, date+time, one cocktail, popularity, overview.
    Future<void> fillStaffDesktop(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'Staff Event');
      await tester.enterText(find.byType(TextField).at(1), '044');
      await tester.pump();
      await tester.tap(find.text('Event-Details').last);
      await tester.pump();
      await pickDate(tester);
      await pickTime(tester);
      await tester.tap(find.text('Cocktails').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Mojito'));
      await tester.pump();
      await tester.tap(find.text('Beliebtheit'));
      await tester.pump();
      await tester.tap(find.text('Zusammenfassung'));
      await tester.pump();
    }

    testWidgets('no prefill, valid: appState + /shopping-list with setupData', (
      tester,
    ) async {
      desktop(tester);
      final h = Harness(
        isStaff: true,
        url: 'http://localhost/order-form?step=1',
      );
      await pumpForm(tester, h.app());
      await settle(tester);
      await fillStaffDesktop(tester);
      await tester.tap(find.text('Einkaufsliste generieren'));
      await tester.pump();
      await settle(tester);

      expect(h.repo.saveCalls, isEmpty);
      expect(h.repo.updateCalls, isEmpty);
      expect(find.text('page /shopping-list'), findsOneWidget);
      expect(appState.selectedRecipes.map((r) => r.name), ['Mojito']);
      expect(appState.cocktailPopularity, {'Mojito': 50.0});
      final setup = h.shoppingListExtra as OrderSetupData;
      expect(setup.orderName, 'Staff Event');
      expect(setup.phoneNumber, '044');
      expect(setup.eventTime, const TimeOfDay(hour: 18, minute: 0));
      expect(setup.address, isNull);
      expect(setup.personCount, 100);
      expect(setup.distanceKm, 10);
      expect(setup.currency, 'CHF');
      expect(setup.drinkerType, 'normal');
      expect(setup.serviceType, 'cocktail_barservice');
      expect(setup.barDrinks, isNull);
      expect(setup.alcoholPurchase, isNull);
      expect(setup.additionalServices, isNull);
      expect(setup.remarks, isNull);
    });

    testWidgets('onSubmit callback replaces navigation', (tester) async {
      desktop(tester);
      final h = Harness(
        isStaff: true,
        url: 'http://localhost/order-form?step=1',
      );
      await pumpForm(tester, h.app(withOnSubmit: true));
      await settle(tester);
      await fillStaffDesktop(tester);
      await tester.tap(find.text('Einkaufsliste generieren'));
      await tester.pump();
      await settle(tester);

      expect(h.submitted, hasLength(1));
      final result = h.submitted.single;
      expect(result.setupData.orderName, 'Staff Event');
      expect(result.selectedRecipes.map((r) => r.name), ['Mojito']);
      expect(find.text('page /shopping-list'), findsNothing);
      expect(appState.selectedRecipes.map((r) => r.name), ['Mojito']);
      expect(appState.cocktailPopularity, {'Mojito': 50.0});
    });

    testWidgets(
      'prefill: updateOrder golden + setLinkedOrder + /shopping-list',
      (tester) async {
        mobile(tester);
        final h = Harness(
          isStaff: true,
          url: 'http://localhost/order-form?step=8',
        );
        await pumpForm(
          tester,
          h.app(
            prefill: prefillOrder(
              id: 'form-77',
              name: 'Staff Prefill',
              phone: '076',
              location: 'Zürich',
              eventTime: '17:05',
              eventType: 'wedding',
              serviceType: 'barservice',
              personCount: 300,
              distanceKm: 120,
              currency: 'EUR',
              drinkerType: 'heavy',
              cocktails: ['Caipirinha'],
              requestedCocktails: ['Mojito'],
              shots: ['Tequila'],
              shotSelections: const [
                ShotSelection(name: 'Tequila', quantity: 5),
              ],
              cocktailPopularity: {'Caipirinha': 70.0},
              items: const [
                {'name': 'Rum', 'quantity': 2},
              ],
            ),
          ),
        );
        await settle(tester);
        expect(h.distanceRequests, isEmpty);
        await tester.tap(find.text('Einkaufsliste generieren').first);
        await tester.pump();
        await settle(tester);

        expect(h.repo.saveCalls, isEmpty);
        expect(h.repo.updateCalls, hasLength(1));
        final (id, data) = h.repo.updateCalls.single;
        expect(id, 'form-77');
        expect(data, {
          'name': 'Staff Prefill',
          'date': DateTime(2027, 5, 1).toIso8601String(),
          'phone': '076',
          'location': 'Zürich',
          'personCount': 300,
          'distanceKm': 120,
          'currency': 'EUR',
          'drinkerType': 'heavy',
          'serviceType': 'bar_service',
          'cocktails': ['Caipirinha'],
          'shots': ['Tequila'],
          'shotQuantities': [
            {'name': 'Tequila', 'quantity': 5},
          ],
          'eventTime': '17:05',
          'offerEventTime': '17:05',
          'eventType': 'wedding',
          'offerClientName': 'Staff Prefill',
          'offerClientContact': '076',
        });
        expect(appState.linkedOrderId, 'form-77');
        expect(appState.linkedOrderName, 'Staff Prefill');
        expect(appState.linkedOrderRequestedCocktails, ['Mojito']);
        expect(appState.savedOrderItems, [
          {'name': 'Rum', 'quantity': 2},
        ]);
        expect(appState.selectedRecipes.map((r) => r.name), [
          'Caipirinha',
          'Tequila',
        ]);
        expect(appState.cocktailPopularity, {
          'Caipirinha': 70.0,
          'Tequila': 50.0,
        });
        expect(find.text('page /shopping-list'), findsOneWidget);
        final setup = h.shoppingListExtra as OrderSetupData;
        expect(setup.address, 'Zürich');
      },
    );
  });

  group('desktop stepper', () {
    testWidgets('step summaries reflect the form state', (tester) async {
      desktop(tester);
      final h = Harness();
      await pumpForm(
        tester,
        h.app(
          prefill: prefillOrder(
            name: 'Lea',
            personCount: 120,
            barDrinks: ['shots'],
            additionalServices: ['other_services'],
            cocktails: ['Mojito'],
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Cocktail & Bar'), findsOneWidget);
      expect(find.text('Lea'), findsOneWidget);
      expect(find.text('01.05.2027'), findsOneWidget);
      expect(find.text('120 Personen'), findsOneWidget);
      expect(find.text('1 ausgewählt'), findsNWidgets(2));
      expect(find.text('1 Cocktails'), findsOneWidget);
      expect(find.text('1 konfiguriert'), findsOneWidget);
      expect(find.text('Alles prüfen & abschließen'), findsOneWidget);

      // Tapping a stepper item jumps there and rewrites the URL.
      await tester.tap(find.text('Präferenzen'));
      await tester.pump();
      expect(find.text('Deine Präferenzen'), findsWidgets);
      expect(h.urls.last, 'http://localhost/order-form?step=3');
      await settle(tester);
    });
  });
}
