// `context` and `mounted` are the sheet State's (OrderDetailHost): every
// use after an await is guarded by that State's `mounted`, exactly as when
// these handlers lived in the State. The lint cannot see that through the
// host indirection.
// ignore_for_file: use_build_context_synchronously
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/order.dart';
import '../../shopping_list/completion_deduction.dart';
import '../order_status_helpers.dart';
import 'dialogs.dart';
import 'order_detail_logic.dart';
import 'order_detail_services.dart';

/// The widget the controller shows its dialogs, snackbars and navigation
/// on. The sheet's State implements it, so `context` and `mounted` are
/// exactly the ones the handlers used when they lived in the State.
abstract interface class OrderDetailHost {
  BuildContext get context;
  bool get mounted;
}

/// State and handlers of the order detail sheet.
///
/// Holds what the sheet's State used to hold (status, decline reason,
/// assigned employees, date, rest/stock flags, items override and the
/// double-tap guards). [update] replaces `setState`: it runs the mutation
/// and notifies, and the sheet rebuilds as a whole on every notification,
/// exactly as `setState` did. Fields the old code assigned without
/// `setState` are still assigned without notifying.
///
/// The shopping-list handlers live in `shopping_actions.dart`
/// (an extension on this class).
class OrderDetailController extends ChangeNotifier {
  OrderDetailController({
    required this.order,
    required this.host,
    this.services = const OrderDetailServices(),
  }) : currentStatus = order.status,
       declineReason = order.declineReason,
       assignedEmployees = List.from(order.assignedEmployees),
       currentDate = order.date,
       restRecorded = order.restRecorded,
       stockApplied = order.stockApplied;

  /// The order as it was when the sheet opened.
  final SavedOrder order;
  final OrderDetailHost host;
  final OrderDetailServices services;

  BuildContext get context => host.context;
  bool get mounted => host.mounted;

  OrderStatus currentStatus;
  String declineReason;
  List<String> assignedEmployees;
  DateTime currentDate;
  bool restRecorded;
  bool stockApplied;

  /// Items as last saved from the shopping-list page (source choice), since
  /// [order] is a snapshot from when the sheet opened.
  List<Map<String, dynamic>>? itemsOverride;

  /// Guards the "Mit Claude regenerieren/erstellen" buttons against a
  /// double-tap and drives their loading spinner while a Firestore/Claude
  /// round trip is in flight.
  bool isGeneratingList = false;

  /// Guards the invoice-open button against a double-tap and drives its
  /// loading spinner while the fresh order data is fetched from Firestore.
  bool isOpeningInvoice = false;

  /// Guards the accept/decline/status-change buttons against a double-tap
  /// and drives their loading spinner while the status update is in flight.
  bool isUpdatingStatus = false;

  /// Guards the shopping-list "Bearbeiten" button against a double-tap and
  /// drives its loading spinner while cocktail data is loaded.
  bool isEditingList = false;

  /// Guards the shopping-list PDF download buttons against a double-tap and
  /// drives their loading spinner while the PDF is generated.
  bool isDownloadingPdf = false;

  /// Guards the "Einkaufsliste erstellen" button against a double-tap and
  /// drives its loading spinner while cocktail data is loaded.
  bool isOpeningShoppingList = false;

  /// Guards the offer-open buttons against a double-tap and drives their
  /// loading spinner - without this, [openOfferEditor] awaits a fresh
  /// Firestore read with no visual feedback at all, which on a slow
  /// connection looks like the button simply isn't responding.
  bool isOpeningOffer = false;

  /// Replacement for the old `setState(fn)`.
  void update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// The actions the sheet shows right now.
  Set<OrderDetailAction> get actions => availableActions(
    currentStatus,
    offerComplete: isOfferComplete(order),
    restRecorded: restRecorded,
    isEmployeeOrHigher: services.isEmployeeOrHigher(),
    isSuperAdmin: services.isSuperAdmin(),
  );

  Future<void> editDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    update(() => currentDate = picked);
    await services.orders.updateOrder(order.id, {
      'date': picked.toIso8601String(),
    });
  }

  Future<void> updateStatus(OrderStatus newStatus) async {
    if (isUpdatingStatus) return;
    // Going back from completed to accepted skips the accept checks, dialog
    // and integrations: the order was already accepted before.
    final isReopening =
        newStatus == OrderStatus.accepted &&
        currentStatus == OrderStatus.completed;
    // Block accepting if no shopping list / price has been calculated
    if (newStatus == OrderStatus.accepted && !isReopening && order.total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kein Angebot annehmen ohne Einkaufsliste.\nBitte zuerst Einkaufsliste erstellen.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    // Completing is only possible from accepted; confirm first
    if (newStatus == OrderStatus.completed) {
      if (!OrderStatus.canComplete(currentStatus)) return;
      final confirmed = await showCompleteConfirmDialog(context);
      if (confirmed != true || !mounted) return;
    }
    // If accepting, show confirmation dialog first
    if (newStatus == OrderStatus.accepted && !isReopening) {
      final confirmed = await showAcceptConfirmDialog(context);
      if (confirmed != true) return;
    }
    // If declining, ask for an (optional) reason first
    String? newDeclineReason;
    if (newStatus == OrderStatus.declined) {
      newDeclineReason = await services.askDeclineReason(
        context,
        declineReason,
      );
      if (newDeclineReason == null || !mounted) return;
    }
    update(() => isUpdatingStatus = true);
    OrderDeductionPlan? deduction;
    if (newStatus == OrderStatus.completed) {
      // Stock is deducted before the status changes. If this throws, the order
      // stays accepted and a retry is safe (deterministic movement ids).
      // Going back to accepted never reverses stock and keeps stockApplied, so
      // completing again later deducts nothing a second time.
      try {
        // Plans from the order as stored now, not [order] (its items may
        // be outdated after editing the source on the shopping-list page).
        deduction = await services.deductForOrder(order.id);
        stockApplied = true;
      } catch (e) {
        debugPrint('Stock deduction failed: $e');
        if (!mounted) return;
        update(() => isUpdatingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.stock_deduct_failed'.tr()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      if (!mounted) return;
      // Shown right after booking and awaited: it is the only record of a
      // shortfall (a retry after a failed status update plans nothing).
      if (deduction.hasNotes) await showStockSummaryDialog(context, deduction);
      if (!mounted) return;
    }
    final success = await services.orders.updateStatus(
      order.id,
      newStatus.value,
      declineReason: newDeclineReason,
    );
    if (!mounted) return;
    update(() => isUpdatingStatus = false);
    if (success) {
      update(() {
        currentStatus = newStatus;
        if (newDeclineReason != null) declineReason = newDeclineReason;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'orders.status_changed'.tr(
              namedArgs: {'status': statusLabel(newStatus)},
            ),
          ),
        ),
      );
      // Trigger Microsoft integration when status becomes accepted
      if (newStatus == OrderStatus.accepted && !isReopening) {
        services.triggerMicrosoftIntegration(this);
      }
      // Ask for the leftovers right after completing; skippable, can be
      // redone via "Rest erfassen".
      if (newStatus == OrderStatus.completed) {
        // Decided from the fresh order loaded for the deduction, never from
        // [order]: after reopening, restRecorded may already be true and
        // saving again would book the leftovers twice.
        final fresh = deduction?.restRecorded;
        if (fresh == true && mounted) update(() => restRecorded = true);
        if (shouldOfferRest(freshRestRecorded: fresh)) {
          await recordRest();
        } else if (fresh == null && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('rest.state_unknown'.tr())));
        }
      }
    } else if (deduction != null) {
      // Stock is booked and stockApplied is set, only the status failed.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('orders.stock_done_status_failed'.tr()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> recordRest() async {
    final saved = await services.showRestEntry(context, order);
    if (saved && mounted) update(() => restRecorded = true);
  }

  /// Edits the reason of an already declined order without changing status.
  Future<void> editDeclineReason() async {
    final reason = await services.askDeclineReason(context, declineReason);
    if (reason == null || !mounted) return;
    final success = await services.orders.updateOrder(order.id, {
      'declineReason': reason,
    });
    if (!mounted) return;
    if (success) {
      update(() => declineReason = reason);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders.decline_reason_saved'.tr())),
      );
    }
  }

  Future<void> updateAssignedEmployees(List<String> employeeIds) async {
    final success = await services.orders.updateAssignedEmployees(
      order.id,
      employeeIds,
    );
    if (success && mounted) {
      update(() => assignedEmployees = employeeIds);
    }
  }

  /// Fetches the latest version of this order before opening its offer/
  /// invoice editor, so a change made elsewhere (e.g. by another staff
  /// member) isn't silently overwritten. On a slow connection this single
  /// Firestore read can occasionally take several seconds; capped at 4s so
  /// a bad connection falls back to the already-loaded local copy instead
  /// of leaving the user staring at a spinner for 10-15s.
  Future<SavedOrder> loadLatestOrder() async {
    final freshOrder = await services.orders
        .getOrderById(order.id)
        .timeout(const Duration(seconds: 4), onTimeout: () => null);
    return freshOrder ?? order;
  }

  Future<void> openOfferEditor() async {
    if (isOpeningOffer) return;
    update(() => isOpeningOffer = true);
    final router = GoRouter.of(context);
    final latest = await loadLatestOrder();
    if (!mounted) return;
    update(() => isOpeningOffer = false);
    Navigator.of(context).pop();
    router.push('/create-offer', extra: latest);
  }

  Future<void> openInvoiceEditor() async {
    if (isOpeningInvoice) return;
    update(() => isOpeningInvoice = true);
    final router = GoRouter.of(context);
    final latest = await loadLatestOrder();
    if (!mounted) return;
    update(() => isOpeningInvoice = false);
    Navigator.of(context).pop();
    router.push('/create-invoice', extra: latest);
  }

  /// Show message that offer needs to be completed first
  void showOfferIncompleteMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('orders.offer_incomplete'.tr()),
        action: SnackBarAction(
          label: 'orders.complete_offer'.tr(),
          onPressed: openOfferEditor,
        ),
      ),
    );
  }

  /// Try to update status, but check if offer is complete first (for accepting)
  void tryUpdateStatus(OrderStatus newStatus) {
    if (newStatus == OrderStatus.accepted && !isOfferComplete(order)) {
      showOfferIncompleteMessage();
      return;
    }
    updateStatus(newStatus);
  }

  Future<void> generateInvoice() async {
    await openInvoiceEditor();
  }

  Future<void> deleteOrder() async {
    final confirm = await showDeleteOrderDialog(
      context,
      orderName: order.name,
      delete: () => services.orders.deleteOrder(order.id),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('orders.deleted'.tr())));
    }
  }
}
