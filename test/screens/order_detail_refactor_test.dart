// Characterization tests for the order detail sheet (Task 12 refactoring).
//
// The pure part pins the status-card rules read from the pre-refactoring
// `_buildStatusCard`, `_buildActionButtons` and `_buildDeleteSection`.
//
// The flow part drives the status transitions with injected fakes. The old
// sheet could not be pumped in the VM (it imported the dart:js_interop
// Microsoft code), so these run against the extracted
// OrderDetailController, whose handler bodies were moved verbatim.
import 'dart:async';

import 'package:cocktail_planer/models/employee.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_controller.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_logic.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_view.dart';
import 'package:cocktail_planer/screens/orders/order_status_helpers.dart';
import 'package:cocktail_planer/screens/shopping_list/completion_deduction.dart';
import 'package:cocktail_planer/utils/currency.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_detail_test_harness.dart';

typedef A = OrderDetailAction;

SavedOrder order({
  OrderStatus status = OrderStatus.quote,
  double total = 100,
  bool offerComplete = true,
}) => SavedOrder(
  id: 'o1',
  name: 'Party',
  date: DateTime(2027, 5, 1),
  items: const [],
  total: total,
  personCount: 20,
  drinkerType: 'normal',
  currency: 'CHF',
  status: status,
  offerClientName: offerComplete ? 'Anna' : '',
  offerClientContact: 'anna@x.ch',
  offerEventTime: '18:00',
  offerEventTypes: const ['wedding'],
);

/// Role flags as the sheet reads them from AuthService.
enum Role {
  none(false, false),
  employee(true, false),
  admin(true, false),
  superAdmin(true, true);

  const Role(this.isEmployeeOrHigher, this.isSuperAdmin);
  final bool isEmployeeOrHigher;
  final bool isSuperAdmin;
}

Set<A> actions(
  OrderStatus status, {
  Role role = Role.employee,
  bool offerComplete = true,
  bool restRecorded = false,
}) => availableActions(
  status,
  offerComplete: offerComplete,
  restRecorded: restRecorded,
  isEmployeeOrHigher: role.isEmployeeOrHigher,
  isSuperAdmin: role.isSuperAdmin,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('availableActions (pure, characterizes old _buildStatusCard)', () {
    test('quote, offer complete: finalize, accept, decline', () {
      expect(actions(OrderStatus.quote), {
        A.finalizeOffer,
        A.accept,
        A.decline,
      });
    });

    test('quote, offer incomplete: only "Angebot vervollständigen"', () {
      expect(actions(OrderStatus.quote, offerComplete: false), {
        A.finalizeOffer,
        A.completeOffer,
      });
    });

    test('accepted: invoice, complete, decline, back to quote', () {
      expect(actions(OrderStatus.accepted), {
        A.finalizeOffer,
        A.invoice,
        A.complete,
        A.decline,
        A.backToQuote,
      });
    });

    test('declined: edit reason, accept, back to quote (no decline)', () {
      expect(actions(OrderStatus.declined), {
        A.finalizeOffer,
        A.editDeclineReason,
        A.accept,
        A.backToQuote,
      });
    });

    test('completed, rest open: invoice, record rest, back to accepted', () {
      expect(actions(OrderStatus.completed), {
        A.finalizeOffer,
        A.invoice,
        A.recordRest,
        A.backToAccepted,
      });
    });

    test('completed, rest recorded: no "Rest erfassen"', () {
      expect(actions(OrderStatus.completed, restRecorded: true), {
        A.finalizeOffer,
        A.invoice,
        A.backToAccepted,
      });
    });

    test('an incomplete offer only matters for quote', () {
      for (final s in [
        OrderStatus.accepted,
        OrderStatus.declined,
        OrderStatus.completed,
      ]) {
        expect(actions(s, offerComplete: false), actions(s), reason: s.name);
      }
    });

    test('restRecorded only matters for completed', () {
      for (final s in [
        OrderStatus.quote,
        OrderStatus.accepted,
        OrderStatus.declined,
      ]) {
        expect(actions(s, restRecorded: true), actions(s), reason: s.name);
      }
    });

    test('role matrix: delete only for super admin, rest only for staff', () {
      for (final s in OrderStatus.values) {
        for (final complete in [true, false]) {
          for (final rest in [true, false]) {
            for (final role in Role.values) {
              final got = actions(
                s,
                role: role,
                offerComplete: complete,
                restRecorded: rest,
              );
              final why = '$s complete=$complete rest=$rest $role';
              expect(got.contains(A.delete), role.isSuperAdmin, reason: why);
              expect(
                got.contains(A.recordRest),
                s == OrderStatus.completed && !rest && role.isEmployeeOrHigher,
                reason: why,
              );
              // Everything else is independent of the role.
              final others = Set.of(got)..removeAll([A.delete, A.recordRest]);
              final base = Set.of(
                actions(s, offerComplete: complete, restRecorded: rest),
              )..removeAll([A.delete, A.recordRest]);
              expect(others, base, reason: why);
            }
          }
        }
      }
    });

    test('complete only from accepted, reopen only from completed', () {
      for (final s in OrderStatus.values) {
        expect(actions(s).contains(A.complete), s == OrderStatus.accepted);
        expect(
          actions(s).contains(A.complete),
          OrderStatus.canComplete(s),
          reason: s.name,
        );
        expect(
          actions(s).contains(A.backToAccepted),
          s == OrderStatus.completed,
        );
      }
    });

    test('isOfferComplete needs name, contact, time and an event type', () {
      expect(isOfferComplete(order()), isTrue);
      expect(isOfferComplete(order(offerComplete: false)), isFalse);
      final base = order();
      SavedOrder copy({
        String? name,
        String? contact,
        String? time,
        List<String>? types,
      }) => SavedOrder(
        id: base.id,
        name: base.name,
        date: base.date,
        items: base.items,
        total: base.total,
        personCount: base.personCount,
        drinkerType: base.drinkerType,
        currency: base.currency,
        status: base.status,
        offerClientName: name ?? base.offerClientName,
        offerClientContact: contact ?? base.offerClientContact,
        offerEventTime: time ?? base.offerEventTime,
        offerEventTypes: types ?? base.offerEventTypes,
      );
      expect(isOfferComplete(copy(contact: '')), isFalse);
      expect(isOfferComplete(copy(time: '')), isFalse);
      expect(isOfferComplete(copy(types: const [])), isFalse);
    });

    test('accept is blocked while the total is 0 or less', () {
      expect(acceptBlockedByTotal(0), isTrue);
      expect(acceptBlockedByTotal(-1), isTrue);
      expect(acceptBlockedByTotal(0.01), isFalse);
    });
  });

  group('status flows (OrderDetailController with fakes)', () {
    late DetailFakes fakes;
    late OrderDetailController c;
    late int notifications;

    setUp(() {
      fakes = DetailFakes();
      notifications = 0;
    });

    Future<void> pumpHost(WidgetTester tester, SavedOrder order) async {
      await pumpDetailApp(
        tester,
        detailApp(
          ControllerHost(
            order: order,
            services: fakes.services,
            onCreated: (created) {
              c = created;
              c.addListener(() => notifications++);
            },
          ),
        ),
      );
    }

    Future<void> tapText(WidgetTester tester, String key) async {
      await tester.tap(find.text(key.tr()).last);
      await tester.pumpAndSettle();
    }

    testWidgets('complete: confirm -> deduct -> summary -> status -> rest', (
      tester,
    ) async {
      fakes.plan = const OrderDeductionPlan(
        shortfalls: [DeductionShortfall(name: 'Rum', quantity: 2)],
        restRecorded: false,
      );
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));

      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      expect(find.text('orders.complete_confirm_title'.tr()), findsOneWidget);
      expect(fakes.log, isEmpty);

      await tapText(tester, 'orders.complete');
      // Deducted before the status changes; the summary waits for OK.
      expect(fakes.log, ['deduct:o1']);
      expect(find.text('orders.stock_summary_title'.tr()), findsOneWidget);
      expect(c.stockApplied, isTrue);
      expect(c.isUpdatingStatus, isTrue);

      await tapText(tester, 'common.ok');
      expect(fakes.log, ['deduct:o1', 'updateStatus:completed', 'rest']);
      expect(c.currentStatus, OrderStatus.completed);
      expect(c.isUpdatingStatus, isFalse);
      expect(c.restRecorded, isTrue);
      expect(notifications, greaterThan(0));
    });

    testWidgets('complete without notes: no summary dialog', (tester) async {
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      await tapText(tester, 'orders.complete');
      expect(find.text('orders.stock_summary_title'.tr()), findsNothing);
      expect(fakes.log, ['deduct:o1', 'updateStatus:completed', 'rest']);
    });

    testWidgets('complete: rest sheet skipped keeps restRecorded false', (
      tester,
    ) async {
      fakes.restSaved = false;
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      await tapText(tester, 'orders.complete');
      expect(fakes.log.last, 'rest');
      expect(c.restRecorded, isFalse);
    });

    testWidgets('complete: fresh restRecorded true -> no rest sheet', (
      tester,
    ) async {
      fakes.plan = const OrderDeductionPlan(
        alreadyApplied: true,
        restRecorded: true,
      );
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      await tapText(tester, 'orders.complete');
      expect(fakes.log, ['deduct:o1', 'updateStatus:completed']);
      expect(c.restRecorded, isTrue);
    });

    testWidgets('complete: fresh restRecorded unknown -> snackbar only', (
      tester,
    ) async {
      fakes.plan = const OrderDeductionPlan();
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      await tapText(tester, 'orders.complete');
      expect(fakes.log, ['deduct:o1', 'updateStatus:completed']);
      // Queued behind the "Status geändert" snackbar.
      expect(
        find.text(
          'orders.status_changed'.tr(
            namedArgs: {'status': statusLabel(OrderStatus.completed)},
          ),
        ),
        findsOneWidget,
      );
      ScaffoldMessenger.of(
        tester.element(find.text('host page')),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text('rest.state_unknown'.tr()), findsOneWidget);
      expect(c.restRecorded, isFalse);
    });

    testWidgets('complete: cancel the confirm dialog changes nothing', (
      tester,
    ) async {
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      await tapText(tester, 'common.cancel');
      expect(fakes.log, isEmpty);
      expect(c.currentStatus, OrderStatus.accepted);
      expect(c.isUpdatingStatus, isFalse);
    });

    testWidgets('complete only from accepted (no dialog otherwise)', (
      tester,
    ) async {
      for (final s in [
        OrderStatus.quote,
        OrderStatus.declined,
        OrderStatus.completed,
      ]) {
        await pumpHost(tester, detailOrder(status: s));
        await c.updateStatus(OrderStatus.completed);
        await tester.pumpAndSettle();
        expect(find.text('ui.cancel'.tr()), findsNothing, reason: s.name);
        expect(fakes.log, isEmpty, reason: s.name);
        expect(c.currentStatus, s);
      }
    });

    testWidgets('complete: deduction fails -> no status change', (
      tester,
    ) async {
      fakes.deductError = Exception('offline');
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      await tapText(tester, 'orders.complete');
      expect(fakes.log, ['deduct:o1']);
      expect(find.text('orders.stock_deduct_failed'.tr()), findsOneWidget);
      expect(c.currentStatus, OrderStatus.accepted);
      expect(c.stockApplied, isFalse);
      expect(c.isUpdatingStatus, isFalse);
    });

    testWidgets('complete: status update fails after the deduction', (
      tester,
    ) async {
      fakes.repo.statusResult = false;
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      await tapText(tester, 'orders.complete');
      expect(fakes.log, ['deduct:o1', 'updateStatus:completed']);
      expect(find.text('orders.stock_done_status_failed'.tr()), findsOneWidget);
      expect(c.currentStatus, OrderStatus.accepted);
      expect(c.stockApplied, isTrue);
      expect(c.isUpdatingStatus, isFalse);
    });

    testWidgets('double-tap guard: a second update while busy is ignored', (
      tester,
    ) async {
      fakes.deductCompleter = Completer();
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      unawaited(c.updateStatus(OrderStatus.completed));
      await tester.pumpAndSettle();
      await tapText(tester, 'orders.complete');
      expect(c.isUpdatingStatus, isTrue);

      await c.updateStatus(OrderStatus.completed);
      await c.updateStatus(OrderStatus.declined);
      await tester.pumpAndSettle();
      expect(find.text('ui.cancel'.tr()), findsNothing);
      expect(fakes.log, ['deduct:o1']);

      fakes.deductCompleter!.complete(
        const OrderDeductionPlan(restRecorded: true),
      );
      await tester.pumpAndSettle();
      expect(fakes.log, ['deduct:o1', 'updateStatus:completed']);
    });

    testWidgets('accept with total 0: snackbar, no dialog, no update', (
      tester,
    ) async {
      await pumpHost(tester, detailOrder(total: 0));
      await c.updateStatus(OrderStatus.accepted);
      await tester.pumpAndSettle();
      expect(find.text('ui.cancel'.tr()), findsNothing);
      expect(
        find.textContaining('Kein Angebot annehmen ohne Einkaufsliste'),
        findsOneWidget,
      );
      expect(fakes.log, isEmpty);
    });

    testWidgets('accept: confirm -> status -> Microsoft integration', (
      tester,
    ) async {
      await pumpHost(tester, detailOrder());
      unawaited(c.updateStatus(OrderStatus.accepted));
      await tester.pumpAndSettle();
      expect(find.text('invoice.confirm_save_title'.tr()), findsOneWidget);
      await tapText(tester, 'common.save');
      expect(fakes.log, ['updateStatus:accepted', 'microsoft']);
      expect(c.currentStatus, OrderStatus.accepted);
      expect(
        find.text(
          'orders.status_changed'.tr(
            namedArgs: {'status': statusLabel(OrderStatus.accepted)},
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('accept: cancel the confirm dialog changes nothing', (
      tester,
    ) async {
      await pumpHost(tester, detailOrder());
      unawaited(c.updateStatus(OrderStatus.accepted));
      await tester.pumpAndSettle();
      await tapText(tester, 'common.cancel');
      expect(fakes.log, isEmpty);
      expect(c.currentStatus, OrderStatus.quote);
    });

    testWidgets('tryUpdateStatus(accepted) with an incomplete offer', (
      tester,
    ) async {
      await pumpHost(tester, detailOrder(offerComplete: false));
      c.tryUpdateStatus(OrderStatus.accepted);
      await tester.pumpAndSettle();
      expect(find.text('ui.cancel'.tr()), findsNothing);
      expect(find.text('orders.offer_incomplete'.tr()), findsOneWidget);
      expect(fakes.log, isEmpty);
    });

    testWidgets('decline: cancel via injected prompt changes nothing', (
      tester,
    ) async {
      fakes.declineReasonAnswer = (_) => null;
      await pumpHost(tester, detailOrder(status: OrderStatus.accepted));
      await c.updateStatus(OrderStatus.declined);
      await tester.pumpAndSettle();
      expect(fakes.reasonPrompts, ['']);
      expect(fakes.log, isEmpty);
      expect(c.currentStatus, OrderStatus.accepted);
    });

    testWidgets('decline: saves the reason with the status', (tester) async {
      fakes.declineReasonAnswer = (_) => 'Zu teuer';
      await pumpHost(
        tester,
        detailOrder(status: OrderStatus.accepted, declineReason: 'alt'),
      );
      await c.updateStatus(OrderStatus.declined);
      await tester.pumpAndSettle();
      expect(fakes.reasonPrompts, ['alt']);
      expect(fakes.repo.statusCalls, [('o1', 'declined', 'Zu teuer')]);
      expect(fakes.log, ['updateStatus:declined']);
      expect(c.currentStatus, OrderStatus.declined);
      expect(c.declineReason, 'Zu teuer');
    });

    testWidgets('decline: an empty reason still declines', (tester) async {
      fakes.declineReasonAnswer = (_) => '';
      await pumpHost(tester, detailOrder());
      await c.updateStatus(OrderStatus.declined);
      await tester.pumpAndSettle();
      expect(fakes.repo.statusCalls, [('o1', 'declined', '')]);
      expect(c.currentStatus, OrderStatus.declined);
    });

    testWidgets('reopen (completed -> accepted): no dialog, no stock, no MS', (
      tester,
    ) async {
      await pumpHost(
        tester,
        detailOrder(status: OrderStatus.completed, stockApplied: true),
      );
      await c.updateStatus(OrderStatus.accepted);
      await tester.pumpAndSettle();
      expect(fakes.log, ['updateStatus:accepted']);
      expect(c.currentStatus, OrderStatus.accepted);
      expect(c.stockApplied, isTrue);
    });

    testWidgets('reopen with total 0 is still allowed', (tester) async {
      await pumpHost(
        tester,
        detailOrder(status: OrderStatus.completed, total: 0),
      );
      await c.updateStatus(OrderStatus.accepted);
      await tester.pumpAndSettle();
      expect(fakes.log, ['updateStatus:accepted']);
    });

    testWidgets('back to quote: no dialog, no stock, no MS', (tester) async {
      await pumpHost(tester, detailOrder(status: OrderStatus.declined));
      await c.updateStatus(OrderStatus.quote);
      await tester.pumpAndSettle();
      expect(fakes.log, ['updateStatus:quote']);
      expect(fakes.repo.statusCalls.single.$3, isNull);
      expect(c.currentStatus, OrderStatus.quote);
    });

    testWidgets('editDeclineReason updates only the reason', (tester) async {
      fakes.declineReasonAnswer = (_) => 'neu';
      await pumpHost(
        tester,
        detailOrder(status: OrderStatus.declined, declineReason: 'alt'),
      );
      await c.editDeclineReason();
      await tester.pumpAndSettle();
      expect(fakes.reasonPrompts, ['alt']);
      expect(fakes.repo.updateCalls.single.$2, {'declineReason': 'neu'});
      expect(fakes.repo.statusCalls, isEmpty);
      expect(c.declineReason, 'neu');
      expect(c.currentStatus, OrderStatus.declined);
      expect(find.text('orders.decline_reason_saved'.tr()), findsOneWidget);
    });

    testWidgets('recordRest marks rest recorded only when saved', (
      tester,
    ) async {
      await pumpHost(tester, detailOrder(status: OrderStatus.completed));
      fakes.restSaved = false;
      await c.recordRest();
      expect(c.restRecorded, isFalse);
      fakes.restSaved = true;
      await c.recordRest();
      expect(c.restRecorded, isTrue);
      expect(fakes.log, ['rest', 'rest']);
    });

    testWidgets('updateAssignedEmployees keeps the list only on success', (
      tester,
    ) async {
      await pumpHost(tester, detailOrder(assignedEmployees: ['Mario']));
      fakes.repo.assignResult = false;
      await c.updateAssignedEmployees(['Mario', 'Prince']);
      expect(c.assignedEmployees, ['Mario']);
      fakes.repo.assignResult = true;
      await c.updateAssignedEmployees(['Prince']);
      expect(c.assignedEmployees, ['Prince']);
    });

    testWidgets('deleteOrder: failure keeps the dialog open with an error', (
      tester,
    ) async {
      fakes.repo.deleteResult = false;
      await pumpHost(tester, detailOrder());
      unawaited(c.deleteOrder());
      await tester.pumpAndSettle();
      expect(find.text('orders.delete_confirm_title'.tr()), findsOneWidget);
      await tapText(tester, 'common.delete');
      expect(fakes.log, ['delete:o1']);
      expect(find.text('orders.delete_failed'.tr()), findsOneWidget);
      await tapText(tester, 'common.cancel');
      expect(find.text('ui.cancel'.tr()), findsNothing);
      expect(find.text('host page'), findsOneWidget);
    });

    testWidgets('actions getter reads role and flags from the services', (
      tester,
    ) async {
      await pumpHost(tester, detailOrder(status: OrderStatus.completed));
      expect(c.actions, contains(OrderDetailAction.recordRest));
      expect(c.actions, isNot(contains(OrderDetailAction.delete)));
      fakes.superAdmin = true;
      fakes.staff = false;
      expect(c.actions, contains(OrderDetailAction.delete));
      expect(c.actions, isNot(contains(OrderDetailAction.recordRest)));
    });
  });

  group('OrderDetailView (sheet with fakes)', () {
    late DetailFakes fakes;
    late List<(String, Object?)> pushed;

    setUp(() {
      fakes = DetailFakes();
      pushed = [];
    });

    Future<void> pumpSheet(
      WidgetTester tester,
      SavedOrder order, {
      double width = 1000,
    }) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDetailApp(
        tester,
        detailApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => OrderDetailView(
                      order: order,
                      colorScheme: Theme.of(context).colorScheme,
                      currency: Currency.fromCode(order.currency),
                      services: fakes.services,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          pushed: pushed,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    bool shown(String key) => find.text(key.tr()).evaluate().isNotEmpty;

    bool enabled(WidgetTester tester, String key) {
      final button = find.ancestor(
        of: find.text(key.tr()),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      return tester.widget<ButtonStyleButton>(button.first).enabled;
    }

    const statusKeys = [
      'orders.accept',
      'orders.decline',
      'orders.complete',
      'orders.back_to_accepted',
      'orders.status_quote',
      'rest.record',
      'orders.complete_offer',
      'orders.invoice',
      'orders.delete_order',
    ];

    Set<String> visible() => {
      for (final k in statusKeys)
        if (shown(k)) k,
    };

    testWidgets('quote: finalize, accept, decline', (tester) async {
      await pumpSheet(tester, detailOrder());
      expect(shown('orders.finalize_offer'), isTrue);
      expect(visible(), {'orders.accept', 'orders.decline'});
      expect(enabled(tester, 'orders.accept'), isTrue);
    });

    testWidgets('narrow (< 700 px): vertical header, same actions', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        detailOrder(status: OrderStatus.accepted),
        width: 420,
      );
      expect(tester.takeException(), isNull);
      expect(shown('orders.finalize_offer'), isTrue);
      expect(shown('orders.regenerate_with_claude'), isTrue);
      expect(visible(), {
        'orders.invoice',
        'orders.complete',
        'orders.decline',
        'orders.status_quote',
      });
    });

    testWidgets('quote with total 0: accept disabled with hint', (
      tester,
    ) async {
      await pumpSheet(tester, detailOrder(total: 0));
      expect(enabled(tester, 'orders.accept'), isFalse);
      expect(find.text('Erst Einkaufsliste erstellen'), findsOneWidget);
    });

    testWidgets('quote with incomplete offer: only "Angebot öffnen"', (
      tester,
    ) async {
      await pumpSheet(tester, detailOrder(offerComplete: false));
      expect(visible(), {'orders.complete_offer'});
      expect(find.text('orders.offer_incomplete'.tr()), findsOneWidget);
    });

    testWidgets('accepted: invoice, complete, decline, back to quote', (
      tester,
    ) async {
      await pumpSheet(tester, detailOrder(status: OrderStatus.accepted));
      expect(visible(), {
        'orders.invoice',
        'orders.complete',
        'orders.decline',
        'orders.status_quote',
      });
    });

    testWidgets('declined: reason row, accept, back to quote', (tester) async {
      await pumpSheet(tester, detailOrder(status: OrderStatus.declined));
      expect(visible(), {'orders.accept', 'orders.status_quote'});
      expect(find.text('orders.decline_reason_add'.tr()), findsOneWidget);
    });

    testWidgets('completed: invoice, record rest, back to accepted', (
      tester,
    ) async {
      await pumpSheet(tester, detailOrder(status: OrderStatus.completed));
      expect(visible(), {
        'orders.invoice',
        'rest.record',
        'orders.back_to_accepted',
      });
    });

    testWidgets('completed for a non-staff role: no "Rest erfassen"', (
      tester,
    ) async {
      fakes.staff = false;
      await pumpSheet(tester, detailOrder(status: OrderStatus.completed));
      expect(visible(), {'orders.invoice', 'orders.back_to_accepted'});
    });

    testWidgets('super admin sees delete; deleting closes the sheet', (
      tester,
    ) async {
      fakes.superAdmin = true;
      await pumpSheet(tester, detailOrder());
      expect(shown('orders.delete_order'), isTrue);
      await tester.tap(find.text('orders.delete_order'.tr()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('common.delete'.tr()));
      await tester.pumpAndSettle();
      expect(fakes.log, ['delete:o1']);
      expect(find.byType(OrderDetailView), findsNothing);
      expect(find.text('orders.deleted'.tr()), findsOneWidget);
    });

    testWidgets('complete through the UI updates the status card', (
      tester,
    ) async {
      fakes.plan = const OrderDeductionPlan(restRecorded: false);
      await pumpSheet(tester, detailOrder(status: OrderStatus.accepted));
      await tester.tap(find.text('orders.complete'.tr()));
      await tester.pumpAndSettle();
      // Confirm dialog: its FilledButton has the same label.
      await tester.tap(find.text('orders.complete'.tr()).last);
      await tester.pumpAndSettle();
      expect(fakes.log, ['deduct:o1', 'updateStatus:completed', 'rest']);
      expect(
        find.text(
          '${'orders.status'.tr()}: ${statusLabel(OrderStatus.completed)}',
        ),
        findsOneWidget,
      );
      // Rest saved by the fake sheet -> "Rest erfassen" gone.
      expect(visible(), {'orders.invoice', 'orders.back_to_accepted'});
    });

    testWidgets('status buttons are disabled while an update runs', (
      tester,
    ) async {
      fakes.deductCompleter = Completer();
      await pumpSheet(tester, detailOrder(status: OrderStatus.accepted));
      await tester.tap(find.text('orders.complete'.tr()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('orders.complete'.tr()).last);
      await tester.pump();
      expect(enabled(tester, 'orders.complete'), isFalse);
      expect(enabled(tester, 'orders.decline'), isFalse);
      expect(enabled(tester, 'orders.status_quote'), isFalse);
      fakes.deductCompleter!.complete(
        const OrderDeductionPlan(restRecorded: true),
      );
      await tester.pumpAndSettle();
      expect(fakes.log, ['deduct:o1', 'updateStatus:completed']);
      expect(enabled(tester, 'orders.back_to_accepted'), isTrue);
    });

    testWidgets('decline reason row edits the reason in place', (tester) async {
      fakes.declineReasonAnswer = (_) => 'Zu teuer';
      await pumpSheet(tester, detailOrder(status: OrderStatus.declined));
      await tester.tap(find.text('orders.decline_reason_add'.tr()));
      await tester.pumpAndSettle();
      expect(
        find.text('${'orders.decline_reason'.tr()}: Zu teuer'),
        findsOneWidget,
      );
    });

    testWidgets('finalize offer opens /create-offer with the order', (
      tester,
    ) async {
      await pumpSheet(tester, detailOrder());
      await tester.tap(find.text('orders.finalize_offer'.tr()));
      await tester.pumpAndSettle();
      expect(fakes.log, ['getOrderById:o1']);
      expect(pushed.single.$1, '/create-offer');
      expect((pushed.single.$2! as SavedOrder).id, 'o1');
      expect(find.byType(OrderDetailView), findsNothing);
    });

    testWidgets('invoice opens /create-invoice with the fresh order', (
      tester,
    ) async {
      fakes.repo.fresh = detailOrder(status: OrderStatus.accepted, total: 7);
      await pumpSheet(tester, detailOrder(status: OrderStatus.accepted));
      await tester.tap(find.text('orders.invoice'.tr()));
      await tester.pumpAndSettle();
      expect(pushed.single.$1, '/create-invoice');
      expect((pushed.single.$2! as SavedOrder).total, 7);
    });

    testWidgets('form details only for form orders; tile only with items', (
      tester,
    ) async {
      await pumpSheet(tester, detailOrder());
      expect(find.text('orders.form_details'.tr()), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('form order with items shows details and the list tile', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        detailOrder(
          source: OrderSource.form,
          items: const [
            {'name': 'Rum', 'quantity': 1, 'price': 10},
          ],
        ),
      );
      expect(find.text('orders.form_details'.tr()), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      expect(
        find.textContaining('1 ${'orders.articles'.tr()}'),
        findsOneWidget,
      );
    });

    testWidgets('employee chips come from watchEmployees and save', (
      tester,
    ) async {
      fakes.employees = const [Employee(id: 'e1', name: 'Mario')];
      await pumpSheet(tester, detailOrder());
      await tester.tap(find.widgetWithText(FilterChip, 'Mario'));
      await tester.pumpAndSettle();
      expect(fakes.repo.assignCalls, [
        ['Mario'],
      ]);
    });
  });
}
