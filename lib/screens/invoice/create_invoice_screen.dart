import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../config/env_config.dart';
import '../../models/order.dart';
import '../../services/invoice_pdf_generator.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/pdf_generator.dart';
import '../../ui/widgets/app_sheet.dart';
import '../shared/document_sections/document_services.dart';
import 'invoice_flow.dart';
import 'invoice_form_state.dart';

/// Screen to create and export an Invoice (Auftragsbestätigung) from a
/// [SavedOrder].
///
/// A thin wrapper: the four-step flow is [InvoiceFlow]; this file only adds
/// the browser-only parts (PDF preview, Microsoft login, OneDrive, Outlook
/// calendar), which cannot be imported by VM tests.
class CreateInvoiceScreen extends StatelessWidget {
  const CreateInvoiceScreen({
    super.key,
    required this.order,
    this.services = const DocumentServices(),
  });

  final SavedOrder order;
  final DocumentServices services;

  void _snack(BuildContext context, String key) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  Future<void> _previewPdf(
    BuildContext context,
    SavedOrder invoice,
    String language,
  ) async {
    final pdfBytes = await InvoicePdfGenerator.generateBytes(
      invoice,
      language: language,
    );
    if (!context.mounted) return;
    // In-app preview: layoutPdf's print dialog shows nothing on iOS Safari
    // once there has been an async gap after the tap.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('invoice.preview'.tr())),
          body: PdfPreview(
            build: (_) async => pdfBytes,
            pdfFileName: InvoicePdfGenerator.getFilename(invoice),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
          ),
        ),
      ),
    );
  }

  /// Without a Microsoft login the OneDrive upload is silently skipped, so
  /// ask first. Declining still saves and creates the link.
  Future<void> _beforeExport(BuildContext context) async {
    if (microsoftGraphService.isSupported && EnvConfig.isOneDriveEnabled) {
      await _ensureMicrosoftLogin(context);
    }
  }

  Future<void> _uploadPdf(
    BuildContext context,
    SavedOrder invoice,
    String language,
  ) async {
    final pdfBytes = await InvoicePdfGenerator.generateBytes(
      invoice,
      language: language,
    );
    if (microsoftGraphService.isSupported &&
        EnvConfig.isOneDriveEnabled &&
        microsoftGraphService.isLoggedIn) {
      await microsoftGraphService.uploadToOneDrive(
        oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
          rootFolder: 'Aufträge',
          date: invoice.date,
          fileName: InvoicePdfGenerator.getFilename(invoice),
        ),
        bytes: pdfBytes,
      );
    }
  }

  /// Makes sure a Microsoft account is signed in (OneDrive and calendar);
  /// asks in a sheet first. True when signed in afterwards.
  Future<bool> _ensureMicrosoftLogin(BuildContext context) async {
    if (!microsoftGraphService.isSupported) return false;
    if (microsoftGraphService.isLoggedIn) return true;
    final wantsLogin = await showConfirmSheet(
      context,
      title: 'invoice.ms_login_title'.tr(),
      body: 'invoice.ms_login_message'.tr(),
      confirmLabel: 'invoice.ms_login_button'.tr(),
    );
    if (!wantsLogin) return false;
    final account = await microsoftGraphService.login();
    if (account == null && context.mounted) {
      _snack(context, 'invoice.ms_login_failed');
    }
    return account != null;
  }

  /// Outlook entry with the confirmation PDF and the shopping list
  /// (uploaded to OneDrive for the links, attached to the event).
  Future<void> _createCalendarEntry(
    BuildContext context,
    SavedOrder invoice,
    InvoiceFormState form,
  ) async {
    final pdfBytes = await InvoicePdfGenerator.generateBytes(
      invoice,
      language: form.language,
    );
    final fileName = InvoicePdfGenerator.getFilename(invoice);
    final shoppingListBytes = await PdfGenerator.generateBytesFromSavedOrder(
      invoice,
    );
    final d = invoice.date;
    final dateTag =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final shoppingListName =
        'Einkaufsliste_${invoice.name.replaceAll(' ', '_')}_$dateTag.pdf';

    String? documentUrl;
    String? shoppingListUrl;
    if (EnvConfig.isOneDriveEnabled) {
      documentUrl = await microsoftGraphService.uploadToOneDrive(
        oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
          rootFolder: 'Aufträge',
          date: d,
          fileName: fileName,
        ),
        bytes: pdfBytes,
      );
      shoppingListUrl = await microsoftGraphService.uploadToOneDrive(
        oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
          rootFolder: 'Aufträge',
          date: d,
          fileName: shoppingListName,
        ),
        bytes: shoppingListBytes,
      );
    }

    final start = InvoiceFormState.calendarStart(invoice);
    final eventId = await microsoftGraphService.createCalendarEvent(
      subject: 'Blacklodge - ${InvoiceFormState.calendarCustomer(invoice)}',
      start: start,
      end: start.add(const Duration(hours: 5)),
      bodyContent: form
          .calendarBodyLines(
            invoice,
            documentUrl: documentUrl,
            shoppingListUrl: shoppingListUrl,
          )
          .join('\n'),
      location: invoice.location,
    );
    if (eventId != null && eventId != 'unknown') {
      await microsoftGraphService.addCalendarAttachment(
        eventId: eventId,
        fileName: fileName,
        bytes: pdfBytes,
      );
      await microsoftGraphService.addCalendarAttachment(
        eventId: eventId,
        fileName: shoppingListName,
        bytes: shoppingListBytes,
      );
    }
    if (context.mounted) {
      _snack(
        context,
        eventId != null ? 'invoice.calendar_created' : 'invoice.calendar_failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) => InvoiceFlow(
    order: order,
    services: services,
    previewPdf: _previewPdf,
    beforeExport: _beforeExport,
    uploadPdf: _uploadPdf,
    calendarSupported: () => microsoftGraphService.isSupported,
    ensureLogin: _ensureMicrosoftLogin,
    createCalendarEntry: _createCalendarEntry,
  );
}
