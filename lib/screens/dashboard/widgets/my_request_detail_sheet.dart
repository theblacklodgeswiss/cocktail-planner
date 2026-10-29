import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../models/order.dart';
import '../../../services/auth_service.dart';
import '../../../services/invoice_pdf_generator.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../orders/order_detail_sheet.dart';
import 'my_request_detail_view.dart';

/// Shows a read-only summary of a customer's own submitted request. Unlike
/// `order_detail_sheet.dart`'s `showOrderDetails` (staff tooling: offer
/// generation, status transitions, employee assignment, deletion), this
/// exposes nothing actionable - a customer cannot edit or delete a request
/// from here.
Future<void> showMyRequestDetails(BuildContext context, SavedOrder request) {
  return showAppSheet<void>(
    context,
    builder: (_) => MyRequestDetailSheet(request: request),
  );
}

class MyRequestDetailSheet extends StatefulWidget {
  const MyRequestDetailSheet({super.key, required this.request});

  final SavedOrder request;

  @override
  State<MyRequestDetailSheet> createState() => _MyRequestDetailSheetState();
}

class _MyRequestDetailSheetState extends State<MyRequestDetailSheet> {
  bool _opening = false;

  SavedOrder get request => widget.request;

  /// Renders the order confirmation locally from the customer's own order
  /// (no share link needed, so it never expires).
  Future<void> _openConfirmation() async {
    setState(() => _opening = true);
    try {
      final bytes = await InvoicePdfGenerator.generateBytes(request);
      // sharePdf downloads/opens the file on web; layoutPdf's print
      // dialog silently does nothing on iOS Safari after an async gap.
      await Printing.sharePdf(
        bytes: bytes,
        filename: InvoicePdfGenerator.getFilename(request),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('dashboard.confirmation_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyRequestDetailView(
      request: request,
      showStaffAction: authService.isEmployeeOrHigher,
      confirmationLoading: _opening,
      onConfirmation: _opening ? null : _openConfirmation,
      onOpenOrder: () {
        // Close this sheet, then open the staff order view with the
        // navigator's context (this sheet's own context is gone after the
        // pop).
        final navigator = Navigator.of(context);
        navigator.pop();
        showOrderDetails(navigator.context, request);
      },
    );
  }
}
