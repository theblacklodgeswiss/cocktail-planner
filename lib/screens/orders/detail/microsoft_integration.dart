// `context` and `mounted` are the sheet State's (OrderDetailHost): every
// use after an await is guarded by that State's `mounted`, exactly as when
// these handlers lived in the State. The lint cannot see that through the
// host indirection.
// ignore_for_file: use_build_context_synchronously
// Browser-only: imports microsoft_graph_service (dart:js_interop). Only
// order_detail_sheet.dart imports this file, so the rest of the detail
// sheet stays testable in the VM.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../config/env_config.dart';
import '../../../services/invoice_pdf_generator.dart';
import '../../../services/microsoft_graph_service.dart';
import '../../../services/pdf_generator.dart';
import '../../../ui/tokens.dart';
import '../../../utils/currency.dart';
import 'order_detail_controller.dart';

/// After accepting: uploads the shopping list and the order confirmation
/// to OneDrive and creates a calendar event with both attached, with a
/// progress dialog on the sheet of [c].
Future<void> runMicrosoftIntegration(OrderDetailController c) async {
  if (!microsoftGraphService.isSupported) return;

  // Skip OneDrive uploads in development environment
  if (!EnvConfig.isOneDriveEnabled) {
    if (c.mounted) {
      ScaffoldMessenger.of(
        c.context,
      ).showSnackBar(SnackBar(content: Text('orders.dev_mode_no_upload'.tr())));
    }
    return;
  }

  final statusNotifier = ValueNotifier<String>(
    'orders.ms_step_generating_shopping_list'.tr(),
  );

  // Show progress dialog
  showDialog(
    context: c.context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<String>(
          valueListenable: statusNotifier,
          builder: (_, status, child) => Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: AppSpace.s16),
              Expanded(child: Text(status)),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    // Fetch fresh order data to get the current event date
    final freshOrder = await c.services.orders.getOrderById(c.order.id);
    final order = freshOrder ?? c.order;

    final safeName = order.name.replaceAll(' ', '_');
    final dateTag =
        '${order.date.year}${order.date.month.toString().padLeft(2, '0')}${order.date.day.toString().padLeft(2, '0')}';
    String? einkaufslisteUrl;
    String? auftragsbestaetigungUrl;

    // 1. Generate Einkaufsliste (Shopping List) PDF
    final shoppingListBytes = await PdfGenerator.generateBytesFromSavedOrder(
      order,
    );
    final shoppingListFileName = 'Einkaufsliste_${safeName}_$dateTag.pdf';

    // 2. Upload Einkaufsliste to OneDrive
    statusNotifier.value = 'orders.ms_step_uploading_shopping_list'.tr();
    final shoppingListPath = MicrosoftGraphService.buildOneDrivePath(
      rootFolder: 'Aufträge',
      date: order.date,
      fileName: shoppingListFileName,
    );
    einkaufslisteUrl = await microsoftGraphService.uploadToOneDrive(
      oneDrivePath: shoppingListPath,
      bytes: shoppingListBytes,
    );

    // 3. Generate Auftragsbestätigung (Order Confirmation) PDF
    statusNotifier.value = 'orders.ms_step_generating_invoice'.tr();
    final invoiceBytes = await InvoicePdfGenerator.generateBytes(order);
    final invoiceFileName = InvoicePdfGenerator.getFilename(order);

    // 4. Upload Auftragsbestätigung to OneDrive
    statusNotifier.value = 'orders.ms_step_uploading_invoice'.tr();
    final invoicePath = MicrosoftGraphService.buildOneDrivePath(
      rootFolder: 'Aufträge',
      date: order.date,
      fileName: invoiceFileName,
    );
    auftragsbestaetigungUrl = await microsoftGraphService.uploadToOneDrive(
      oneDrivePath: invoicePath,
      bytes: invoiceBytes,
    );

    // 5. Create calendar event with document links
    statusNotifier.value = 'orders.ms_step_creating_calendar'.tr();

    // Parse event time (e.g. "17:30") and combine with date
    DateTime eventStart = order.date;
    if (order.offerEventTime.isNotEmpty) {
      final timeParts = order.offerEventTime.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        eventStart = DateTime(
          order.date.year,
          order.date.month,
          order.date.day,
          hour,
          minute,
        );
      }
    }
    final eventEnd = eventStart.add(const Duration(hours: 5));
    final employeeNames = c.assignedEmployees.isNotEmpty
        ? c.assignedEmployees.join(', ')
        : 'TBD';

    // Build event body with document links
    final customer = order.offerClientName.isNotEmpty
        ? order.offerClientName
        : order.name;
    final bodyLines = <String>[
      'Auftrag: $customer',
      if (order.location.isNotEmpty) 'Adresse: ${order.location}',
      'Personen: ${order.personCount}',
      'Mitarbeiter: $employeeNames',
      // order.total is the undiscounted positions sum.
      'Gesamtbetrag: ${Currency.fromCode(order.currency).format(order.total - order.offerDiscount)}',
      '',
      '--- Dokumente ---',
    ];
    if (einkaufslisteUrl != null) {
      bodyLines.add('Einkaufsliste: $einkaufslisteUrl');
    }
    if (auftragsbestaetigungUrl != null) {
      bodyLines.add('Auftragsbestätigung: $auftragsbestaetigungUrl');
    }

    final eventId = await microsoftGraphService.createCalendarEvent(
      subject: 'Blacklodge - $customer',
      start: eventStart,
      end: eventEnd,
      bodyContent: bodyLines.join('\n'),
      location: order.location,
    );

    // 6. Add PDF attachments to calendar event
    if (eventId != null && eventId != 'unknown') {
      statusNotifier.value = 'orders.ms_step_adding_attachments'.tr();
      await microsoftGraphService.addCalendarAttachment(
        eventId: eventId,
        fileName: shoppingListFileName,
        bytes: shoppingListBytes,
      );
      await microsoftGraphService.addCalendarAttachment(
        eventId: eventId,
        fileName: invoiceFileName,
        bytes: invoiceBytes,
      );
    }

    final uploadSuccess =
        einkaufslisteUrl != null || auftragsbestaetigungUrl != null;
    final calendarSuccess = eventId != null;

    // Close progress dialog
    if (c.mounted) Navigator.of(c.context).pop();

    if (c.mounted && (uploadSuccess || calendarSuccess)) {
      ScaffoldMessenger.of(c.context).showSnackBar(
        SnackBar(content: Text('orders.microsoft_integration_success'.tr())),
      );
    } else if (c.mounted) {
      ScaffoldMessenger.of(c.context).showSnackBar(
        SnackBar(content: Text('orders.microsoft_integration_failed'.tr())),
      );
    }
  } catch (e) {
    debugPrint('Microsoft integration error: $e');
    // Close progress dialog
    if (c.mounted) Navigator.of(c.context).pop();
    if (c.mounted) {
      ScaffoldMessenger.of(c.context).showSnackBar(
        SnackBar(content: Text('orders.microsoft_integration_failed'.tr())),
      );
    }
  }
}
