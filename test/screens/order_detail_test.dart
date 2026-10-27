// Task 13: restyled order detail (staff). Pure rules first; the widget
// tests are added together with the new view.
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_logic.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
