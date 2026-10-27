// Shared fakes and helpers for the order wizard widget tests
// (order_form_refactor_test.dart, order_form_steps_test.dart). Pumps the
// real ModernOrderFormScreen with fakes injected through
// `OrderFormServices` (no Firebase, no network, no browser URL).
import 'dart:async';

import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/models/additional_service.dart';
import 'package:cocktail_planer/models/cocktail_data.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/models/recipe.dart';
import 'package:cocktail_planer/screens/forms/modern_order_form_screen.dart';
import 'package:cocktail_planer/screens/forms/order_form_services.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
    this.loadCocktailData,
  }) : _url = url,
       _distanceCompleters = distanceCompleters;

  final bool isStaff;
  String _url;

  /// Overrides the recipe catalog load (default: three recipes).
  final Future<CocktailData> Function()? loadCocktailData;

  /// Simulates the browser URL changing (e.g. back/forward).
  set url(String value) => _url = value;
  final Map<String, Completer<int?>>? _distanceCompleters;
  final repo = FakeOrderRepository();
  final urls = <String>[];
  final distanceRequests = <String>[];
  final submitted = <OrderFormResult>[];
  Object? shoppingListExtra;

  OrderFormServices get services => OrderFormServices(
    isEmployeeOrHigher: () => isStaff,
    resolveRole: () async {},
    loadCocktailData:
        loadCocktailData ??
        () async => const CocktailData(
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

  /// [textScale] defaults to 0.5: the test font (Ahem) renders every glyph
  /// as a full square, so walkthroughs use small text; the layout tests
  /// pass 1.3 explicitly.
  Widget app({
    SavedOrder? prefill,
    bool withOnSubmit = false,
    ThemeData? theme,
    double textScale = 0.5,
  }) {
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

/// A prefill that satisfies every `canProceed` gate.
SavedOrder completePrefill({
  List<String> cocktails = const ['Mojito'],
  List<String> shots = const ['Tequila'],
  String serviceType = 'cocktail_barservice',
  String guestCountRange = '',
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
  guestCountRange: guestCountRange,
  barDrinks: const ['gin_mix'],
  additionalServices: const ['photobooth:v3h', 'booth_360'],
  remarks: 'Bitte früh aufbauen',
);

String stepUrl(int step) => 'http://localhost/order-form?step=$step';

/// Step titles (German) by new index.
const stepTitles = [
  'Was feiern wir?',
  'Wann und wo?',
  'Wie erreichen wir dich?',
  'Was soll im Glas sein?',
  'Noch etwas dazu?',
];

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

/// Lets a step entrance (280 ms) and any pending debounce (800 ms) finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump();
}

/// The bottom "Weiter" (or, on the last step, the submit) button.
Finder nextButton() => find.byType(PrimaryButton);

bool dimmed(WidgetTester tester) =>
    tester.widget<PrimaryButton>(nextButton()).dimmed;

Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(nextButton());
  await settle(tester);
}

/// Runs a sheet's open/close animation to completion.
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

/// The TextField whose caption (label above it) is [caption].
Finder fieldWithCaption(String caption) => find.descendant(
  of: find
      .ancestor(of: find.text(caption), matching: find.byType(Column))
      .first,
  matching: find.byType(TextField),
);

bool hasFocus(WidgetTester tester, Finder textField) => tester
    .widget<EditableText>(
      find.descendant(of: textField, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;
