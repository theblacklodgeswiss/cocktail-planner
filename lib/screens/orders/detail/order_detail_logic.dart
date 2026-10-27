import '../../../models/order.dart';

/// The actions the order detail sheet offers, independent of how they are
/// rendered. Task 13 restyles the sheet; the rules which action is shown
/// for which status and role live here.
enum OrderDetailAction {
  /// Header: "Angebot finalisieren" (always shown).
  finalizeOffer,

  /// Header: "Rechnung" (accepted and completed).
  invoice,

  /// Status card: tap the decline reason to edit it (declined only).
  editDeclineReason,

  /// Status card: "Angebot vervollständigen" (quote with an incomplete
  /// offer). Replaces every status button.
  completeOffer,

  /// Status card: "Rest erfassen" (completed, leftovers not recorded yet,
  /// staff only).
  recordRest,

  /// Status card: accepted -> completed.
  complete,

  /// Status card: completed -> accepted (reopen; never touches stock).
  backToAccepted,

  /// Status card: quote/declined -> accepted. Disabled while the order
  /// total is 0 (see [acceptBlockedByTotal]).
  accept,

  /// Status card: quote/accepted -> declined.
  decline,

  /// Status card: accepted/declined -> quote.
  backToQuote,

  /// Bottom: "Auftrag löschen" (super admin only).
  delete,
}

/// Whether every field the offer needs is filled (client name, contact,
/// event time and at least one event type).
bool isOfferComplete(SavedOrder order) {
  return order.offerClientName.isNotEmpty &&
      order.offerClientContact.isNotEmpty &&
      order.offerEventTime.isNotEmpty &&
      order.offerEventTypes.isNotEmpty;
}

/// Accepting is blocked (button disabled, "Erst Einkaufsliste erstellen"
/// hint) while no shopping list / price has been calculated.
bool acceptBlockedByTotal(double total) => total <= 0;

/// The actions the detail sheet shows for [status].
///
/// Characterizes the pre-redesign `_buildStatusCard`, `_buildActionButtons`
/// and `_buildDeleteSection` conditions one to one:
/// - [OrderDetailAction.finalizeOffer] always.
/// - [OrderDetailAction.invoice] for accepted and completed.
/// - [OrderDetailAction.editDeclineReason] for declined.
/// - quote with an incomplete offer: only [OrderDetailAction.completeOffer]
///   instead of the status buttons.
/// - otherwise:
///   - [OrderDetailAction.recordRest] when completed, not [restRecorded] and
///     [isEmployeeOrHigher];
///   - [OrderDetailAction.complete] when accepted;
///   - [OrderDetailAction.backToAccepted] when completed;
///   - [OrderDetailAction.accept] when quote or declined;
///   - [OrderDetailAction.decline] when quote or accepted;
///   - [OrderDetailAction.backToQuote] when accepted or declined.
/// - [OrderDetailAction.delete] when [isSuperAdmin].
///
/// `stockApplied`, the shopping list and the form origin do not change the
/// status actions (they only affect the shopping-list section).
Set<OrderDetailAction> availableActions(
  OrderStatus status, {
  required bool offerComplete,
  required bool restRecorded,
  required bool isEmployeeOrHigher,
  required bool isSuperAdmin,
}) {
  final actions = <OrderDetailAction>{OrderDetailAction.finalizeOffer};
  if (status == OrderStatus.accepted || status == OrderStatus.completed) {
    actions.add(OrderDetailAction.invoice);
  }
  if (status == OrderStatus.declined) {
    actions.add(OrderDetailAction.editDeclineReason);
  }
  if (!offerComplete && status == OrderStatus.quote) {
    actions.add(OrderDetailAction.completeOffer);
  } else {
    if (status == OrderStatus.completed &&
        !restRecorded &&
        isEmployeeOrHigher) {
      actions.add(OrderDetailAction.recordRest);
    }
    if (status == OrderStatus.accepted) {
      actions.add(OrderDetailAction.complete);
    }
    if (status == OrderStatus.completed) {
      actions.add(OrderDetailAction.backToAccepted);
    }
    if (status != OrderStatus.accepted && status != OrderStatus.completed) {
      actions.add(OrderDetailAction.accept);
    }
    if (status != OrderStatus.declined && status != OrderStatus.completed) {
      actions.add(OrderDetailAction.decline);
    }
    if (status != OrderStatus.quote && status != OrderStatus.completed) {
      actions.add(OrderDetailAction.backToQuote);
    }
  }
  if (isSuperAdmin) actions.add(OrderDetailAction.delete);
  return actions;
}
