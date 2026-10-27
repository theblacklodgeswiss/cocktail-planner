// Behavior of the five-step order wizard (Task 9): step mapping, field
// hints, keyboard/back handling, the deliberate behavior changes and the
// layout at 360x640 with large text, both themes and an open keyboard.
import 'package:cocktail_planer/models/cocktail_data.dart';
import 'package:cocktail_planer/models/offer.dart' show EventType;
import 'package:cocktail_planer/screens/forms/order_form_state.dart';
import 'package:cocktail_planer/screens/forms/step_mapping.dart';
import 'package:cocktail_planer/state/app_state.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/ui/widgets/pill_filter.dart';
import 'package:cocktail_planer/ui/widgets/states.dart';
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

  group('step mapping', () {
    test('mapLegacyStep pins the old -> new table', () {
      const expected = {0: 0, 1: 2, 2: 1, 3: 0, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4};
      for (final entry in expected.entries) {
        expect(
          mapLegacyStep(entry.key),
          entry.value,
          reason: 'old ${entry.key}',
        );
      }
      expect(() => mapLegacyStep(-1), throwsRangeError);
      expect(() => mapLegacyStep(9), throwsRangeError);
    });

    test('resolveStepParam: 0..4 new, 5..8 legacy, rest null', () {
      for (var i = 0; i < kFormSteps; i++) {
        expect(resolveStepParam('$i'), i);
      }
      expect(resolveStepParam('5'), 3);
      expect(resolveStepParam('6'), 3);
      expect(resolveStepParam('7'), 4);
      expect(resolveStepParam('8'), 4);
      for (final raw in [null, '', 'x', '-1', '9', '42']) {
        expect(resolveStepParam(raw), isNull, reason: '$raw');
      }
    });
  });

  group('fieldError / visibleHint (pure)', () {
    late OrderFormState form;
    setUp(() => form = OrderFormState(distanceLookupPending: false));
    tearDown(() => form.dispose());

    test('fieldError mirrors the canProceed data rules', () {
      expect(fieldError(form, FormFieldId.name), 'order_setup.required_name');
      expect(
        fieldError(form, FormFieldId.phone),
        'order_wizard.required_phone',
      );
      expect(
        fieldError(form, FormFieldId.eventType),
        'offer.event_type_required',
      );
      form.nameController.text = 'Anna';
      form.selectedEventType = EventType.birthday;
      expect(fieldError(form, FormFieldId.name), isNull);
      expect(fieldError(form, FormFieldId.eventType), isNull);
      for (var step = 0; step < kFormSteps; step++) {
        expect(
          form.canProceed(step),
          requiredFieldsOf(step).every((f) => fieldError(form, f) == null),
        );
      }
    });

    test('hints stay hidden on a pristine form', () {
      for (final field in FormFieldId.values) {
        expect(form.visibleHint(field), isNull, reason: field.name);
      }
      form.attemptedSteps.add(2);
      expect(form.visibleHint(FormFieldId.name), 'order_setup.required_name');
      expect(form.visibleHint(FormFieldId.address), isNull, reason: 'step 1');
      form.touchedFields.add(FormFieldId.address);
      expect(
        form.visibleHint(FormFieldId.address),
        'order_wizard.required_address',
      );
    });

    test('popularity follows the selection (deterministic)', () {
      form.update(() => form.toggleRecipeSelection(mojito));
      expect(form.cocktailPopularity, {'Mojito': 50.0});
      form.cocktailPopularity['Mojito'] = 70;
      form.update(() => form.toggleRecipeSelection(tequila));
      expect(form.cocktailPopularity, {'Mojito': 70.0, 'Tequila': 50.0});
      form.update(() => form.toggleRecipeSelection(mojito));
      expect(form.cocktailPopularity, {'Tequila': 50.0});
      form.update(() => form.toggleRecipeSelection(tequila));
      expect(form.cocktailPopularity, isEmpty);
    });
  });

  group('Weiter and field hints', () {
    testWidgets('step 0: needs an event type; tap while invalid explains', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(0));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text(stepTitles[0]), findsOneWidget);
      expect(dimmed(tester), isTrue);
      expect(
        find.text('Bitte wähle mindestens einen Anlass aus.'),
        findsNothing,
      );

      await tapNext(tester);
      expect(find.text(stepTitles[0]), findsOneWidget, reason: 'no advance');
      expect(
        find.text('Bitte wähle mindestens einen Anlass aus.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Hochzeitsfeier'));
      await tester.pump();
      expect(dimmed(tester), isFalse);
      expect(
        find.text('Bitte wähle mindestens einen Anlass aus.'),
        findsNothing,
      );
      // Tapping the selected pill again clears it (single select).
      await tester.tap(find.text('Hochzeitsfeier'));
      await tester.pump();
      expect(dimmed(tester), isTrue);
      await tester.tap(find.text('Firmenanlass'));
      await tester.pump();
      await tapNext(tester);
      expect(find.text(stepTitles[1]), findsOneWidget);
    });

    testWidgets('step 1: date, time and address; first missing is the date', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(1));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(dimmed(tester), isTrue);
      await tapNext(tester);
      expect(find.text(stepTitles[1]), findsOneWidget);
      expect(find.text('Datum ist erforderlich'), findsOneWidget);
      expect(find.text('Uhrzeit ist erforderlich'), findsOneWidget);
      expect(find.text('Adresse ist erforderlich'), findsOneWidget);

      await pickDate(tester);
      await pickTime(tester);
      expect(find.text('Datum ist erforderlich'), findsNothing);
      expect(dimmed(tester), isTrue, reason: 'address missing');
      // Now the address is the first missing field: it gets focus.
      await tapNext(tester);
      expect(hasFocus(tester, find.byType(TextField).first), isTrue);

      await tester.enterText(find.byType(TextField).first, 'Basel');
      await tester.pump();
      expect(dimmed(tester), isFalse);
      await tapNext(tester);
      expect(find.text(stepTitles[2]), findsOneWidget);
    });

    testWidgets('step 2: name hint appears only after Weiter, name focused', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(2));
      await pumpForm(tester, h.app());
      await settle(tester);
      final name = fieldWithCaption('Vor- und Nachname *');
      expect(find.text('Name ist erforderlich'), findsNothing);
      expect(dimmed(tester), isTrue);

      await tapNext(tester);
      expect(find.text(stepTitles[2]), findsOneWidget);
      expect(find.text('Name ist erforderlich'), findsOneWidget);
      expect(find.text('Handynummer ist erforderlich'), findsOneWidget);
      expect(hasFocus(tester, name), isTrue);

      await tester.enterText(name, 'Anna');
      await tester.pump();
      expect(find.text('Name ist erforderlich'), findsNothing);
      expect(dimmed(tester), isTrue, reason: 'phone missing');
      await tester.enterText(find.byType(TextField).at(1), '079');
      await tester.pump();
      expect(dimmed(tester), isFalse);
      await tapNext(tester);
      expect(find.text(stepTitles[3]), findsOneWidget);
    });

    testWidgets('a field touched and left shows its hint, others do not', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(2));
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.tap(find.byType(TextField).at(0));
      await tester.pump();
      expect(find.text('Name ist erforderlich'), findsNothing);
      await tester.tap(find.byType(TextField).at(1));
      await tester.pump();
      await tester.pump();
      expect(find.text('Name ist erforderlich'), findsOneWidget);
      expect(find.text('Handynummer ist erforderlich'), findsNothing);
    });

    testWidgets('keyboard next walks name -> phone -> remarks', (tester) async {
      mobile(tester);
      final h = Harness(url: stepUrl(2));
      await pumpForm(tester, h.app());
      await settle(tester);
      final fields = find.byType(TextField);
      final name = tester.widget<TextField>(fields.at(0));
      final phone = tester.widget<TextField>(fields.at(1));
      expect(name.textInputAction, TextInputAction.next);
      expect(name.autofillHints, [AutofillHints.name]);
      expect(phone.textInputAction, TextInputAction.next);
      expect(phone.autofillHints, [AutofillHints.telephoneNumber]);

      await tester.tap(fields.at(0));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(hasFocus(tester, fields.at(1)), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(hasFocus(tester, fields.at(2)), isTrue);
    });

    testWidgets('address has the street-address autofill hint', (tester) async {
      mobile(tester);
      final h = Harness(url: stepUrl(1));
      await pumpForm(tester, h.app());
      await settle(tester);
      final address = tester.widget<TextField>(find.byType(TextField).first);
      expect(address.autofillHints, [AutofillHints.fullStreetAddress]);
      expect(address.textInputAction, TextInputAction.done);
    });

    testWidgets('the first missing field is scrolled into view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = Harness(url: stepUrl(1));
      await pumpForm(tester, h.app(textScale: 1.3));
      await settle(tester);
      // Scroll to the bottom (currency), far away from the date row.
      await tester.dragFrom(const Offset(180, 300), const Offset(0, -2000));
      await settle(tester);
      expect(
        tester.getRect(find.text('Datum auswählen')).top,
        lessThan(0),
        reason: 'precondition: date scrolled out of view',
      );
      await tester.tap(nextButton());
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.text('Datum auswählen'));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(tester.getRect(nextButton()).top));
    });

    testWidgets('step 3 always proceeds; the button counts the drinks', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(3));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(dimmed(tester), isFalse);
      expect(find.text('Weiter'), findsOneWidget);
      await tester.tap(find.text('Mojito'));
      await tester.pump();
      expect(find.text('Weiter · 1 Drink'), findsOneWidget);
      await tester.tap(find.text('Caipirinha'));
      await tester.pump();
      expect(find.text('Weiter · 2 Drinks'), findsOneWidget);
      await tapNext(tester);
      expect(find.text(stepTitles[4]), findsOneWidget);
    });

    testWidgets('filter pills: only the categories that exist', (tester) async {
      mobile(tester);
      final h = Harness(url: stepUrl(3));
      await pumpForm(tester, h.app());
      await settle(tester);
      Finder pill(String label) => find.descendant(
        of: find.byType(PillFilter<String>),
        matching: find.text(label),
      );
      expect(pill('Alle'), findsOneWidget);
      expect(pill('Cocktails'), findsOneWidget);
      expect(pill('Shots'), findsOneWidget);
      expect(pill('Ohne Alkohol'), findsNothing);
      await tester.tap(pill('Shots'));
      await tester.pump();
      expect(find.text('Mojito'), findsNothing);
      expect(find.text('Tequila'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump();
      expect(find.text('Keine Getränke gefunden'), findsOneWidget);
    });
  });

  group('deliberate behavior changes', () {
    testWidgets('mobile: a failed submit moves the page to the faulty step', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(4));
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.text('Anfrageübersicht'), findsOneWidget);
      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      await settle(tester);
      expect(h.urls.last, stepUrl(2));
      // The page itself moved (before: footer only, overview still shown).
      expect(find.text('Anfrageübersicht'), findsNothing);
      expect(find.text(stepTitles[2]), findsOneWidget);
      // Snackbar + the hint at the field + focus.
      expect(find.text('Name ist erforderlich'), findsNWidgets(2));
      expect(hasFocus(tester, find.byType(TextField).first), isTrue);
    });

    testWidgets('cocktail check on submit lands on step 3 with a hint', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(4));
      await pumpForm(tester, h.app(prefill: prefillOrder(name: 'Anna')));
      await settle(tester);
      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      await settle(tester);
      expect(find.text(stepTitles[3]), findsOneWidget);
      expect(
        find.text('Bitte wähle mindestens einen Cocktail'),
        findsNWidgets(2),
      );
    });

    for (final staff in [false, true]) {
      testWidgets('overview shows exactly one submit button '
          '(${staff ? 'staff' : 'guest'}, mobile)', (tester) async {
        mobile(tester);
        final h = Harness(isStaff: staff, url: stepUrl(4));
        await pumpForm(tester, h.app(prefill: completePrefill()));
        await settle(tester);
        expect(find.byType(PrimaryButton), findsOneWidget);
        expect(
          find.text(staff ? 'Einkaufsliste generieren' : 'Antrag einreichen'),
          findsOneWidget,
        );
      });
    }

    testWidgets('popularity values exist without opening the section and '
        'are pruned on deselect', (tester) async {
      mobile(tester);
      final h = Harness(url: stepUrl(3));
      await pumpForm(tester, h.app(prefill: completePrefill(shots: const [])));
      await settle(tester);
      // Mojito comes from the prefill; add Caipirinha and Tequila, drop
      // Mojito, never open "Beliebtheit anpassen".
      expect(find.text('Beliebtheit anpassen'), findsOneWidget);
      expect(find.byType(Slider), findsNothing, reason: 'collapsed');
      await tester.tap(find.text('Caipirinha'));
      await tester.tap(find.text('Tequila'));
      await tester.tap(find.text('Mojito'));
      await tester.pump();
      await tapNext(tester);
      await tester.tap(find.text('Antrag einreichen'));
      await tester.pump();
      await settle(tester);
      expect(h.repo.saveCalls.single['cocktailPopularity'], {
        'Caipirinha': 50.0,
        'Tequila': 50.0,
      });
    });
  });

  group('navigation', () {
    testWidgets('Android back goes to the previous step (PopScope)', (
      tester,
    ) async {
      mobile(tester);
      final h = Harness(url: stepUrl(2));
      await pumpForm(tester, h.app());
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(stepTitles[1]), findsOneWidget);
      expect(h.urls.last, stepUrl(1));
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text(stepTitles[0]), findsOneWidget);
    });

    for (var step = 0; step < kFormSteps; step++) {
      testWidgets('?step=$step opens "${stepTitles[step]}" (n von 5)', (
        tester,
      ) async {
        mobile(tester);
        final h = Harness(url: stepUrl(step));
        await pumpForm(tester, h.app(prefill: completePrefill()));
        await settle(tester);
        expect(find.text(stepTitles[step]), findsOneWidget);
        expect(find.text('${step + 1} von 5'), findsOneWidget);
        expect(h.urls, isEmpty);
      });
    }

    for (final (legacy, mapped) in [(5, 3), (6, 3), (7, 4), (8, 4)]) {
      testWidgets('legacy ?step=$legacy lands on step $mapped', (tester) async {
        mobile(tester);
        final h = Harness(url: stepUrl(legacy));
        await pumpForm(tester, h.app(prefill: completePrefill()));
        await settle(tester);
        expect(find.text(stepTitles[mapped]), findsOneWidget);
        expect(h.urls, [stepUrl(mapped)], reason: 'rewritten to new index');
      });
    }

    testWidgets('summary "Ändern" jumps back to the step', (tester) async {
      mobile(tester);
      final h = Harness(url: stepUrl(4));
      await pumpForm(tester, h.app(prefill: completePrefill()));
      await settle(tester);
      // Groups: Anlass, Termin und Ort, Kontakt, Getränke.
      await tester.tap(find.text('Ändern').at(2));
      await settle(tester);
      expect(find.text(stepTitles[2]), findsOneWidget);
      expect(h.urls.last, stepUrl(2));
    });
  });

  group('cocktail catalog states', () {
    testWidgets('failure shows ErrorState, retry loads', (tester) async {
      mobile(tester);
      var calls = 0;
      final h = Harness(
        url: stepUrl(3),
        loadCocktailData: () async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return const CocktailData(
            materials: [],
            recipes: [mojito, caipirinha, tequila],
          );
        },
      );
      await pumpForm(tester, h.app());
      await settle(tester);
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
      await tester.tap(find.text('Erneut versuchen'));
      // The fake load completes on the real event loop: rebuild (so the
      // FutureBuilder listens) and let it resolve there.
      await tester.runAsync(() async {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);
      expect(calls, 2);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Mojito'), findsOneWidget);
    });
  });

  group('layout at 360x640, text scale 1.3', () {
    for (final staff in [false, true]) {
      for (final dark in [false, true]) {
        for (final keyboard in [0.0, 300.0]) {
          for (var step = 0; step < kFormSteps; step++) {
            final role = staff ? 'staff' : 'guest';
            final theme = dark ? 'dark' : 'light';
            testWidgets('step $step, $role, $theme, keyboard $keyboard', (
              tester,
            ) async {
              tester.view.physicalSize = const Size(360, 640);
              tester.view.devicePixelRatio = 1;
              tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
              addTearDown(tester.view.reset);
              final h = Harness(isStaff: staff, url: stepUrl(step));
              await pumpForm(
                tester,
                h.app(
                  prefill: completePrefill(guestCountRange: '80-120'),
                  theme: dark ? AppTheme.dark() : AppTheme.light(),
                  textScale: 1.3,
                ),
              );
              await settle(tester);
              if (step == 3) {
                // Open the optional section too.
                await tester.ensureVisible(find.text('Beliebtheit anpassen'));
                await tester.pump();
                await tester.tap(find.text('Beliebtheit anpassen'));
                await tester.pump();
              }
              expect(tester.takeException(), isNull);
              expect(find.text(stepTitles[step]), findsOneWidget);
              final button = tester.getRect(nextButton());
              expect(button.top, greaterThan(0));
              expect(button.bottom, lessThanOrEqualTo(640 - keyboard));
            });
          }
        }
      }
    }
  });
}
