// Characterization tests for ModernOrderFormScreen.
//
// Written in Task 8 against the nine-step wizard; Task 9 regrouped the
// wizard into five steps. The interactions were rewritten for the new
// steps, but the saveOrder / updateOrder golden maps and the staff
// contracts are unchanged, except where a deliberate behavior change says
// so (see the "popularity sync" group).
import 'dart:async';

import 'package:cocktail_planer/models/offer.dart' show EventType;
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/forms/order_form_state.dart';
import 'package:cocktail_planer/screens/forms/step_mapping.dart';
import 'package:cocktail_planer/state/app_state.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/widgets/order_setup_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_form_test_harness.dart';

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

  group('OrderFormState (pure)', () {
    late OrderFormState form;
    setUp(() => form = OrderFormState(distanceLookupPending: false));
    tearDown(() => form.dispose());

    test('totalSteps is 5', () {
      expect(OrderFormState.totalSteps, 5);
      expect(kFormSteps, 5);
    });

    test('canProceed: steps 3 and 4 are always open', () {
      for (final step in [3, 4]) {
        expect(form.canProceed(step), isTrue, reason: 'step $step');
      }
    });

    test('canProceed(0): event type required (old step 3 rule)', () {
      expect(form.canProceed(0), isFalse);
      form.selectedEventType = EventType.other;
      expect(form.canProceed(0), isTrue);
    });

    test('canProceed(1): date AND time AND trimmed address (old step 2)', () {
      expect(form.canProceed(1), isFalse);
      form.eventDate = DateTime(2027, 5, 1);
      form.eventTime = const TimeOfDay(hour: 18, minute: 0);
      expect(form.canProceed(1), isFalse);
      form.addressController.text = ' ';
      expect(form.canProceed(1), isFalse);
      form.addressController.text = 'Basel';
      expect(form.canProceed(1), isTrue);
      form.eventTime = null;
      expect(form.canProceed(1), isFalse);
    });

    test('canProceed(2): trimmed name AND phone (old step 1)', () {
      expect(form.canProceed(2), isFalse);
      form.nameController.text = 'Anna';
      expect(form.canProceed(2), isFalse);
      form.phoneController.text = '  ';
      expect(form.canProceed(2), isFalse);
      form.phoneController.text = '079';
      expect(form.canProceed(2), isTrue);
      form.nameController.text = ' ';
      expect(form.canProceed(2), isFalse);
    });

    test('firstInvalidStep: name -> 2, date -> 1, cocktails -> 3', () {
      expect(form.firstInvalidStep(), (
        step: 2,
        messageKey: 'order_setup.required_name',
      ));
      form.nameController.text = 'Anna';
      expect(form.firstInvalidStep(), (
        step: 1,
        messageKey: 'order_setup.required_date',
      ));
      form.eventDate = DateTime(2027, 5, 1);
      expect(form.firstInvalidStep(), (
        step: 3,
        messageKey: 'order_setup.required_cocktails',
      ));
      form.selectedRecipes.add(mojito);
      expect(form.firstInvalidStep(), isNull);
    });

    test('service type normalization and mocktail clearing', () {
      expect(
        OrderFormState.normalizeServiceType('cocktailservice'),
        'cocktail_service',
      );
      expect(OrderFormState.normalizeServiceType('barservice'), 'bar_service');
      expect(
        OrderFormState.normalizeServiceType('mocktail_service'),
        'mocktail_service',
      );

      form.toggleRecipeSelection(mojito);
      form.toggleRecipeSelection(tequila);
      form.shotQuantityController(tequila);
      form.cocktailFilter = 'shots';
      form.selectServiceType('mocktail_service');
      expect(form.selectedRecipes, [mojito]);
      expect(form.shotQuantities, isEmpty);
      expect(form.shotQuantityControllers, isEmpty);
      expect(form.cocktailPopularity, {'Mojito': 50.0});
      expect(form.cocktailFilter, 'all');
    });

    test('additional services split + flatten round-trip', () {
      form.applyAdditionalServicesPrefill([
        'photobooth:v3h',
        'booth_360',
        'other_services',
        ':bad',
      ]);
      expect(form.selectedAdditionalServices, {'photobooth': 'v3h'});
      expect(form.legacyAdditionalServiceIds, {'booth_360', ':bad'});
      expect(form.otherServicesSelected, isTrue);
      expect(form.additionalServicesList, [
        'photobooth:v3h',
        'booth_360',
        ':bad',
        'other_services',
      ]);
    });
  });

  group('submit validation jumps to the faulty step', () {
    testWidgets('missing name -> step 2 (desktop shows step 2 content)', (
      tester,
    ) async {
      desktop(tester);
      final h = Harness(url: stepUrl(4));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Anfrageübersicht'), findsOneWidget);

      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      // Snackbar + hint at the name field.
      expect(find.text('Name ist erforderlich'), findsNWidgets(2));
      expect(find.text(stepTitles[2]), findsOneWidget);
      expect(h.urls.last, stepUrl(2));
      expect(h.repo.saveCalls, isEmpty);
      await settle(tester);
    });

    testWidgets('name but no date -> step 1', (tester) async {
      desktop(tester);
      final h = Harness(url: stepUrl(2));
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Anna');
      await tester.enterText(find.byType(TextField).at(1), '079');
      await tester.pump();
      await tapNext(tester);
      await tapNext(tester);
      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      // Snackbar + hint at the date row.
      expect(find.text('Datum ist erforderlich'), findsNWidgets(2));
      expect(h.urls.last, stepUrl(1));
      expect(find.text('Datum auswählen'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('name + date but no cocktails -> step 3', (tester) async {
      desktop(tester);
      final h = Harness(url: stepUrl(4));
      await pumpForm(tester, h.app(prefill: prefillOrder(name: 'Anna')));
      await settle(tester);
      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      expect(h.urls.last, stepUrl(3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(stepTitles[3]), findsOneWidget);
      // Snackbar + hint above the drink list (once the catalog
      // FutureBuilder has delivered its data, one frame later).
      expect(
        find.text('Bitte wähle mindestens einen Cocktail'),
        findsNWidgets(2),
      );
      await settle(tester);
    });
  });

  group('URL step sync', () {
    testWidgets('?step=2 opens step 2 (mobile) without rewriting', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(2));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text(stepTitles[2]), findsOneWidget);
      expect(h.urls, isEmpty, reason: 'step param present -> no URL rewrite');
    });

    testWidgets('?step=2 opens step 2 (desktop)', (tester) async {
      desktop(tester);
      final h = Harness(url: stepUrl(2));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text(stepTitles[2]), findsOneWidget);
    });

    testWidgets('out-of-range ?step=9 stays on step 0', (tester) async {
      mobile(tester);
      final h = Harness(url: stepUrl(9));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text(stepTitles[0]), findsOneWidget);
      expect(h.urls, isEmpty);
    });

    testWidgets('no step param -> URL rewritten to step=0; Weiter/Zurück '
        'rewrite step', (tester) async {
      mobile(tester);
      final h = Harness();
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(h.urls, [stepUrl(0)]);
      await tester.tap(find.text('Hochzeitsfeier'));
      await tester.pump();
      await tapNext(tester);
      expect(find.text(stepTitles[1]), findsOneWidget);
      expect(h.urls.last, stepUrl(1));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.text(stepTitles[0]), findsOneWidget);
      expect(h.urls.last, stepUrl(0));
    });

    testWidgets('back arrow on step 0 goes to /dashboard when it cannot pop', (
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
      final h = Harness(url: stepUrl(1));
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Bern');
      await tester.pump(const Duration(milliseconds: 700));
      expect(h.distanceRequests, isEmpty);
      expect(find.text('wird berechnet…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.distanceRequests, ['Bern']);
      await tester.pump();
      expect(find.text('42 km'), findsOneWidget);
    });

    testWidgets('stale lookup result is discarded', (tester) async {
      mobile(tester);
      final completers = {'Alt': Completer<int?>(), 'Neu': Completer<int?>()};
      final h = Harness(url: stepUrl(1), distanceCompleters: completers);
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
      expect(find.text('7 km'), findsOneWidget);
    });

    testWidgets('staff never trigger a lookup and see the slider', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(isStaff: true, url: stepUrl(1));
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Bern');
      await settle(tester);
      expect(h.distanceRequests, isEmpty);
      expect(find.text('10 km'), findsOneWidget);
      // Guest count + distance.
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

      // Step 0: service type (default stays cocktail_barservice), drinker
      // type, event type.
      await tester.tap(find.text('Cocktail- & Barservice'));
      await tester.tap(find.text('Viel'));
      await tester.tap(find.text('Hochzeitsfeier'));
      await tester.pump();
      await tapNext(tester);

      // Step 1: time, address (distance lookup), currency.
      await pickTime(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'Bahnhofstrasse 1, Basel',
      );
      await settle(tester);
      expect(find.text('42 km'), findsOneWidget);
      await tester.tap(find.text('EUR'));
      await tester.pump();
      await tapNext(tester);

      // Step 2: contact + remarks.
      await tester.enterText(find.byType(TextField).at(0), ' Anna Muster ');
      await tester.enterText(find.byType(TextField).at(1), '+41 79 123 45 67');
      await tester.enterText(find.byType(TextField).at(2), ' Bitte pünktlich ');
      await tester.pump();
      await tapNext(tester);

      // Step 3: cocktails + a shot with quantity 3 (stepper), bar drinks
      // and alcohol. Popularity is never opened (defaults to 50 % each).
      await tester.tap(find.text('Mojito'));
      await tester.pump();
      await tester.tap(find.text('Tequila'));
      await tester.pump();
      expect(find.text('Weiter · 2 Drinks'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.text('Gin & Mischgetränke'));
      await tester.tap(find.text('Gin Bulldog 0.7L - 35,-'));
      await tester.pump();
      await tapNext(tester);

      // Step 4: additional services (variant picker) + other, overview,
      // submit.
      await tester.tap(find.text('Fotobox'));
      await sheet(tester);
      await tester.tap(find.text('3 Stunden'));
      await tester.pump();
      await tester.tap(find.text('OK').last);
      await sheet(tester);
      expect(find.text('3 Stunden (300 EUR)'), findsOneWidget);
      await tester.tap(find.text('Sonstiges'));
      await tester.pump();
      expect(find.text('Anfrageübersicht'), findsOneWidget);
      expect(find.text('Anna Muster'), findsOneWidget);
      await tester.tap(find.text('Antrag einreichen'));
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
      for (var i = 0; i < 4; i++) {
        await tapNext(tester);
      }
      expect(find.text('Anfrageübersicht'), findsOneWidget);
      await tester.tap(find.text('Antrag einreichen'));
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
      final h = Harness(url: stepUrl(4));
      h.repo.saveResult = null;
      await pumpForm(tester, h.app(prefill: completePrefill()));
      await settle(tester);
      await tester.tap(find.text('Antrag einreichen'));
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

  group('popularity sync (deliberate change: uniform on all layouts)', () {
    SavedOrder ghostPrefill() => prefillOrder(
      name: 'Pop',
      cocktails: const ['Mojito'],
      cocktailPopularity: const {'Mojito': 80.0, 'Ghost': 10.0},
    );

    // Before Task 9 mobile pruned "Ghost" on every rebuild while desktop
    // only did so while the popularity step was shown (and kept it here).
    // Now the values follow the selection when it changes (prefill
    // preselection included), on every layout.
    for (final (name, layout) in [('mobile', mobile), ('desktop', desktop)]) {
      testWidgets('$name prunes stale entries without showing popularity', (
        tester,
      ) async {
        layout(tester);
        final h = Harness(url: stepUrl(4));
        await pumpForm(tester, h.app(prefill: ghostPrefill()));
        await settle(tester);
        await tester.tap(find.text('Antrag einreichen'));
        await tester.pump();
        await settle(tester);
        expect(h.repo.saveCalls.single['cocktailPopularity'], {'Mojito': 80.0});
      });
    }
  });

  group('staff branch', () {
    testWidgets('no prefill: one submit, Claude button, validation applies', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(isStaff: true, url: stepUrl(4));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Auftragsübersicht'), findsOneWidget);
      expect(find.text('Mit Claude Einkaufsliste generieren'), findsOneWidget);
      expect(find.text('Einkaufsliste generieren'), findsOneWidget);

      // Missing name -> validation applies to staff too.
      await tester.tap(find.text('Einkaufsliste generieren'));
      await tester.pump();
      // Snackbar + hint at the name field.
      expect(find.text('Name ist erforderlich'), findsNWidgets(2));
      expect(find.text(stepTitles[2]), findsOneWidget);
      await settle(tester);
    });

    /// Staff fill in only what they have (no address): name/phone, a
    /// jump to step 1 via the step label, date/time, then a soft "Weiter"
    /// past the missing address (first tap shows the hints, second one
    /// continues), one cocktail and the overview.
    Future<void> fillStaff(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'Staff Event');
      await tester.enterText(find.byType(TextField).at(1), '044');
      await tester.pump();
      await tester.tap(find.text('3 von 5'));
      await sheet(tester);
      await tester.tap(find.text(stepTitles[1]).last);
      await sheet(tester);
      await settle(tester);
      await pickDate(tester);
      await pickTime(tester);
      await tapNext(tester);
      expect(find.text('Adresse ist erforderlich'), findsOneWidget);
      await tapNext(tester);
      await tapNext(tester);
      await tester.tap(find.text('Mojito'));
      await tester.pump();
      await tapNext(tester);
    }

    testWidgets('no prefill, valid: appState + /shopping-list with setupData', (
      tester,
    ) async {
      desktop(tester);
      final h = Harness(isStaff: true, url: stepUrl(2));
      await pumpForm(tester, h.app());
      await settle(tester);
      await fillStaff(tester);
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
      final h = Harness(isStaff: true, url: stepUrl(2));
      await pumpForm(tester, h.app(withOnSubmit: true));
      await settle(tester);
      await fillStaff(tester);
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
        final h = Harness(isStaff: true, url: stepUrl(4));
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
        await tester.tap(find.text('Einkaufsliste generieren'));
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

  group('URL step re-sync on dependency changes', () {
    // didChangeDependencies re-reads `?step=`; it fires whenever the
    // screen's MediaQuery (size, keyboard inset) or locale changes.
    testWidgets('window resize jumps to the URL step (mobile)', (tester) async {
      mobile(tester);
      final h = Harness(url: stepUrl(3));
      await pumpForm(tester, h.app(prefill: completePrefill()));
      await settle(tester);
      expect(find.text(stepTitles[3]), findsOneWidget);
      h.url = stepUrl(1);
      tester.view.physicalSize = const Size(520, 2600);
      await tester.pump();
      await settle(tester);
      expect(find.text(stepTitles[1]), findsOneWidget);
      expect(find.text(stepTitles[3]), findsNothing);
    });

    testWidgets('keyboard inset change jumps to the URL step (mobile)', (
      tester,
    ) async {
      mobile(tester);
      addTearDown(tester.view.resetViewInsets);
      final h = Harness(url: stepUrl(3));
      await pumpForm(tester, h.app(prefill: completePrefill()));
      await settle(tester);
      h.url = stepUrl(1);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await settle(tester);
      expect(find.text(stepTitles[1]), findsOneWidget);
    });

    testWidgets('window resize jumps to the URL step (desktop)', (
      tester,
    ) async {
      desktop(tester);
      final h = Harness(url: stepUrl(3));
      await pumpForm(tester, h.app(prefill: completePrefill()));
      await settle(tester);
      h.url = stepUrl(1);
      tester.view.physicalSize = const Size(1300, 2600);
      await tester.pump();
      await settle(tester);
      expect(find.text(stepTitles[1]), findsOneWidget);
      expect(find.text(stepTitles[3]), findsNothing);
    });

    testWidgets('a legacy index re-syncs through the mapping', (tester) async {
      mobile(tester);
      final h = Harness(url: stepUrl(0));
      await pumpForm(tester, h.app(prefill: completePrefill()));
      await settle(tester);
      h.url = stepUrl(7); // old additional services -> new 4
      tester.view.physicalSize = const Size(520, 2600);
      await tester.pump();
      await settle(tester);
      expect(find.text(stepTitles[4]), findsOneWidget);
    });
  });

  group('golden saveOrder (guest, desktop)', () {
    testWidgets('desktop walkthrough with a non-default popularity', (
      tester,
    ) async {
      desktop(tester);
      final h = Harness();
      await pumpForm(tester, h.app(prefill: prefillOrder()));
      await settle(tester);

      await tester.tap(find.text('Nur Cocktailservice'));
      await tester.tap(find.text('Hochzeitsfeier'));
      await tester.pump();
      await tapNext(tester);
      await pickTime(tester);
      await tester.enterText(find.byType(TextField).first, 'Riehen');
      await settle(tester);
      await tapNext(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Desk Gast');
      await tester.enterText(find.byType(TextField).at(1), '061 111');
      await tester.pump();
      await tapNext(tester);
      // Cocktail service: no bar drinks section.
      expect(find.text('Gin & Mischgetränke'), findsNothing);
      await tester.tap(find.text('Caipirinha'));
      await tester.pump();
      await tester.tap(find.text('Tequila'));
      await tester.pump();
      // Open the optional popularity section and drag Caipirinha's slider
      // to the far right.
      await tester.tap(find.text('Beliebtheit anpassen'));
      await tester.pump();
      await tester.drag(find.byType(Slider).first, const Offset(2000, 0));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      await tapNext(tester);
      expect(find.text('Anfrageübersicht'), findsOneWidget);
      expect(find.byType(PrimaryButton), findsOneWidget);
      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      await settle(tester);

      expect(h.repo.saveCalls.single, {
        'name': 'Desk Gast',
        'date': DateTime(2027, 5, 1),
        'items': <Map<String, dynamic>>[],
        'total': 0.0,
        'currency': 'CHF',
        'personCount': 100,
        'drinkerType': 'normal',
        'status': 'quote',
        'cocktails': ['Caipirinha'],
        'shots': ['Tequila'],
        'shotQuantities': [
          {'name': 'Tequila', 'quantity': 1},
        ],
        'bar': '',
        'distanceKm': 42,
        'thekeCost': 0.0,
        'phone': '061 111',
        'location': 'Riehen',
        'eventTime': '18:00',
        'serviceType': 'cocktail_service',
        'cocktailPopularity': {'Caipirinha': 100.0, 'Tequila': 50.0},
        'barDrinks': <String>[],
        'alcoholPurchase': <String>[],
        'additionalServices': <String>[],
        'remarks': '',
        'eventType': 'wedding',
      });
      expect(find.text('page /order-success'), findsOneWidget);
    });
  });
}
