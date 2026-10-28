// Task 13: restyled order detail (staff): the pure primary/menu rules and
// the widget behavior of the new sheet (one primary action, delete via
// confirm sheet, double-tap guard, decline-reason sheet, no overflow).
import 'package:cocktail_planer/models/employee.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_logic.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_view.dart';
import 'package:cocktail_planer/screens/shopping_list/completion_deduction.dart';
import 'package:cocktail_planer/ui/app_theme.dart';
import 'package:cocktail_planer/ui/widgets/app_sheet.dart';
import 'package:cocktail_planer/ui/widgets/buttons.dart';
import 'package:cocktail_planer/utils/currency.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_detail_test_harness.dart';

typedef A = OrderDetailAction;

Set<A> actionsFor(
  OrderStatus status, {
  bool offerComplete = true,
  bool restRecorded = false,
  bool staff = true,
  bool superAdmin = false,
}) => availableActions(
  status,
  offerComplete: offerComplete,
  restRecorded: restRecorded,
  isEmployeeOrHigher: staff,
  isSuperAdmin: superAdmin,
);

A? primary(OrderStatus s, {bool offerComplete = true, bool rest = false}) =>
    primaryAction(
      s,
      actionsFor(s, offerComplete: offerComplete, restRecorded: rest),
    );

void main() {
  group('primaryAction (one per status)', () {
    test('quote -> accept', () => expect(primary(OrderStatus.quote), A.accept));
    test(
      'quote with incomplete offer -> complete offer',
      () => expect(
        primary(OrderStatus.quote, offerComplete: false),
        A.completeOffer,
      ),
    );
    test(
      'accepted -> complete',
      () => expect(primary(OrderStatus.accepted), A.complete),
    );
    test(
      'completed, rest open -> record rest',
      () => expect(primary(OrderStatus.completed), A.recordRest),
    );
    test(
      'completed, rest recorded -> none',
      () => expect(primary(OrderStatus.completed, rest: true), isNull),
    );
    test(
      'declined -> none (reopen lives in the menu)',
      () => expect(primary(OrderStatus.declined), isNull),
    );
    test('completed without staff role -> none', () {
      expect(
        primaryAction(
          OrderStatus.completed,
          actionsFor(OrderStatus.completed, staff: false),
        ),
        isNull,
      );
    });
  });

  group('menuActions', () {
    test('never contains the primary action or the inline reason edit', () {
      for (final s in OrderStatus.values) {
        final all = actionsFor(s, superAdmin: true);
        final p = primaryAction(s, all);
        final menu = menuActions(s, all);
        if (p != null) expect(menu.contains(p), isFalse, reason: s.name);
        expect(menu.contains(A.editDeclineReason), isFalse);
      }
    });

    test('declined: accept and back to quote are in the menu', () {
      final menu = menuActions(
        OrderStatus.declined,
        actionsFor(OrderStatus.declined),
      );
      expect(menu, containsAll([A.accept, A.backToQuote, A.finalizeOffer]));
    });

    test('delete only for super admin, always last', () {
      for (final s in OrderStatus.values) {
        expect(
          menuActions(s, actionsFor(s)).contains(A.delete),
          isFalse,
          reason: s.name,
        );
        final menu = menuActions(s, actionsFor(s, superAdmin: true));
        expect(menu.last, A.delete, reason: s.name);
      }
    });

    test('every available action is primary, in the menu or inline', () {
      for (final s in OrderStatus.values) {
        final all = actionsFor(s, superAdmin: true);
        final covered = {
          ...menuActions(s, all),
          if (primaryAction(s, all) != null) primaryAction(s, all)!,
          A.editDeclineReason,
        };
        expect(covered.containsAll(all), isTrue, reason: s.name);
      }
    });
  });

  group('OrderDetailView (restyled sheet)', () {
    late DetailFakes fakes;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
    });

    setUp(() => fakes = DetailFakes());

    Future<void> pumpSheet(
      WidgetTester tester,
      SavedOrder order, {
      bool dark = false,
      double scale = 1.0,
      double keyboard = 0,
    }) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.reset);
      await pumpDetailApp(
        tester,
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
                    services: fakes.services,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          textScale: scale,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
    }

    final primaryCases = <String, (SavedOrder, int)>{
      'quote': (detailOrder(), 1),
      'quote, offer incomplete': (detailOrder(offerComplete: false), 1),
      'accepted': (detailOrder(status: OrderStatus.accepted), 1),
      'completed, rest open': (detailOrder(status: OrderStatus.completed), 1),
      'completed, rest recorded': (
        detailOrder(status: OrderStatus.completed, restRecorded: true),
        0,
      ),
      'declined': (detailOrder(status: OrderStatus.declined), 0),
    };
    for (final entry in primaryCases.entries) {
      testWidgets('primary action count: ${entry.key}', (tester) async {
        await pumpSheet(tester, entry.value.$1);
        expect(find.byType(PrimaryButton), findsNWidgets(entry.value.$2));
      });
    }

    testWidgets('delete only for super admin', (tester) async {
      await pumpSheet(tester, detailOrder());
      await openMenu(tester);
      expect(find.text('orders.delete_order'.tr()), findsNothing);
    });

    testWidgets('super admin deletes via the destructive confirm sheet', (
      tester,
    ) async {
      fakes.superAdmin = true;
      await pumpSheet(tester, detailOrder());
      await openMenu(tester);
      await tester.tap(find.text('orders.delete_order'.tr()));
      await tester.pumpAndSettle();
      expect(find.text('orders.delete_confirm_title'.tr()), findsOneWidget);
      final confirm = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'common.delete'.tr()),
      );
      expect(confirm.destructive, isTrue);
      expect(fakes.log, isEmpty);

      await tester.tap(find.text('ui.cancel'.tr()));
      await tester.pumpAndSettle();
      expect(fakes.log, isEmpty);
      expect(find.byType(OrderDetailView), findsOneWidget);

      await openMenu(tester);
      await tester.tap(find.text('orders.delete_order'.tr()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.delete'.tr()));
      await tester.pumpAndSettle();
      expect(fakes.log, ['delete:o1']);
      expect(find.byType(OrderDetailView), findsNothing);
    });

    testWidgets('a failed delete keeps the sheet and shows the error', (
      tester,
    ) async {
      fakes.superAdmin = true;
      fakes.repo.deleteResult = false;
      await pumpSheet(tester, detailOrder());
      await openMenu(tester);
      await tester.tap(find.text('orders.delete_order'.tr()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.delete'.tr()));
      await tester.pumpAndSettle();
      expect(find.text('orders.delete_failed'.tr()), findsOneWidget);
      expect(find.byType(OrderDetailView), findsOneWidget);
    });

    testWidgets('double tap on Abschliessen completes once', (tester) async {
      await pumpSheet(tester, detailOrder(status: OrderStatus.accepted));
      final button = find.widgetWithText(PrimaryButton, 'orders.complete'.tr());
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('orders.complete_confirm_title'.tr()), findsOneWidget);
      await tester.tap(find.text('orders.complete'.tr()).last);
      await tester.pumpAndSettle();
      expect(fakes.log.where((e) => e.startsWith('deduct')).length, 1);
      expect(fakes.log.where((e) => e.startsWith('updateStatus')).length, 1);
    });

    testWidgets('decline reason sheet saves through the real sheet', (
      tester,
    ) async {
      await pumpSheet(tester, detailOrder(status: OrderStatus.declined));
      await tester.tap(find.text('orders.decline_reason_add'.tr()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Zu teuer ');
      await tester.tap(find.text('common.save'.tr()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fakes.repo.updateCalls.single.$2, {'declineReason': 'Zu teuer'});
      expect(
        find.text('${'orders.decline_reason'.tr()}: Zu teuer'),
        findsOneWidget,
      );
    });

    testWidgets('decline reason sheet cancel writes nothing', (tester) async {
      await pumpSheet(tester, detailOrder(status: OrderStatus.declined));
      await tester.tap(find.text('orders.decline_reason_add'.tr()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'x');
      await tester.tap(find.text('ui.cancel'.tr()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fakes.repo.updateCalls, isEmpty);
    });

    testWidgets('declining a quote asks for the reason and stores it', (
      tester,
    ) async {
      await pumpSheet(tester, detailOrder());
      await openMenu(tester);
      await tester.tap(find.text('orders.decline'.tr()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Zu teuer');
      await tester.tap(find.text('common.save'.tr()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fakes.repo.statusCalls.single, ('o1', 'declined', 'Zu teuer'));
    });

    for (final dark in [false, true]) {
      for (final status in OrderStatus.values) {
        testWidgets(
          'no overflow at 360x640, text x1.3, ${dark ? 'dark' : 'light'}, '
          '${status.name}',
          (tester) async {
            fakes.superAdmin = true;
            fakes.employees = const [
              Employee(id: 'e1', name: 'Mario'),
              Employee(id: 'e2', name: 'Alexandra Mustermann'),
            ];
            fakes.plan = const OrderDeductionPlan(restRecorded: true);
            await pumpSheet(
              tester,
              detailOrder(
                status: status,
                source: OrderSource.form,
                declineReason: 'Zu teuer, der Kunde hat ein anderes Angebot',
                items: const [
                  {'name': 'Rum', 'quantity': 1, 'price': 10},
                ],
              ),
              dark: dark,
              scale: 1.3,
            );
            expect(tester.takeException(), isNull);
            await tester.drag(find.byType(ListView), const Offset(0, -800));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (find.byIcon(Icons.more_horiz).evaluate().isNotEmpty) {
              await openMenu(tester);
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }

    testWidgets('decline reason sheet fits with the keyboard open', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        detailOrder(status: OrderStatus.declined),
        scale: 1.3,
        keyboard: 300,
        dark: true,
      );
      await tester.tap(find.text('orders.decline_reason_add'.tr()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
