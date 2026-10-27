// Characterization tests for the order detail sheet (Task 12 refactoring).
//
// The pure part pins the status-card rules read from the pre-refactoring
// `_buildStatusCard`, `_buildActionButtons` and `_buildDeleteSection`.
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_logic.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
