import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env_config.dart';
import '../../models/order.dart';
import '../../services/invoice_pdf_generator.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/pdf_generator.dart';
import '../../utils/currency.dart';
import '../offer/offer_form_state.dart' show formatDocumentDate;
import '../shared/document_sections/common_sections.dart';
import '../shared/document_sections/document_field.dart';
import '../shared/document_sections/document_services.dart';
import '../shared/document_sections/position_dialog.dart';
import 'invoice_form_state.dart';
import 'sections/invoice_extra_hours_section.dart';
import 'sections/invoice_positions_section.dart';
import 'sections/invoice_preview_and_actions.dart';

/// Screen to create and export an Invoice (Auftragsbestätigung) from a
/// [SavedOrder]. Data and logic live in [InvoiceFormState]; the sections are
/// widgets in `sections/` and `../shared/document_sections/`.
class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({
    super.key,
    required this.order,
    this.services = const DocumentServices(),
  });

  final SavedOrder order;
  final DocumentServices services;

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final InvoiceFormState _form;

  @override
  void initState() {
    super.initState();
    _form = InvoiceFormState(
      widget.order,
      displayName: widget.services.displayName(),
    );
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _update(VoidCallback fn) => setState(fn);

  void _snack(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  // Confirmation dialog for PDF save
  Future<void> _confirmGeneratePdf() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('invoice.confirm_save_title'.tr()),
        content: Text('invoice.confirm_save_msg'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _generatePdf();
    }
  }

  /// Form validators, then employees and total; explains failures.
  bool _validate() {
    if (!_formKey.currentState!.validate()) return false;
    late bool valid;
    setState(() => valid = _form.validateAll());
    if (!valid) _snack(_form.validationErrorKey ?? 'common.error');
    return valid;
  }

  Future<bool> _saveInvoiceData() async {
    final saved = await _form.save(widget.services.orders);
    if (!saved) _snack('invoice.save_failed');
    return saved;
  }

  Future<void> _saveOnly() async {
    if (!_validate()) return;
    setState(() => _form.isGenerating = true);
    try {
      if (!await _saveInvoiceData()) return;
      _snack('invoice.saved');
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  Future<void> _previewPdf() async {
    if (!_validate()) return;
    setState(() => _form.isGenerating = true);
    try {
      if (!await _saveInvoiceData()) return;
      final updatedOrder = _form.buildUpdatedOrder();
      final pdfBytes = await InvoicePdfGenerator.generateBytes(
        updatedOrder,
        language: _form.language,
      );
      if (mounted) {
        // In-app preview: layoutPdf's print dialog shows nothing on iOS
        // Safari once there has been an async gap after the tap.
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text('invoice.preview'.tr())),
              body: PdfPreview(
                build: (_) async => pdfBytes,
                pdfFileName: InvoicePdfGenerator.getFilename(updatedOrder),
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  Future<void> _generatePdf() async {
    if (!_validate()) return;

    // Without a Microsoft login the OneDrive upload is silently skipped,
    // so ask first. Declining still saves and creates the link.
    if (microsoftGraphService.isSupported && EnvConfig.isOneDriveEnabled) {
      await _ensureMicrosoftLogin();
      if (!mounted) return;
    }

    setState(() => _form.isGenerating = true);
    try {
      if (!await _saveInvoiceData()) return;
      final updatedOrder = _form.buildUpdatedOrder();
      final pdfBytes = await InvoicePdfGenerator.generateBytes(
        updatedOrder,
        language: _form.language,
      );

      final fileName = InvoicePdfGenerator.getFilename(updatedOrder);
      if (microsoftGraphService.isSupported &&
          EnvConfig.isOneDriveEnabled &&
          microsoftGraphService.isLoggedIn) {
        await microsoftGraphService.uploadToOneDrive(
          oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
            rootFolder: 'Aufträge',
            date: updatedOrder.date,
            fileName: fileName,
          ),
          bytes: pdfBytes,
        );
      }

      // A 14-day share link instead of raw PDF bytes (unusable blob: URL).
      final code = await widget.services.shareLinks.createInvoiceShareLink(
        updatedOrder,
      );
      await Clipboard.setData(
        ClipboardData(text: '${Uri.base.origin}/s/$code'),
      );
      _snack('invoice.share_link_copied');
    } catch (e) {
      _snack('invoice.share_link_failed');
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  /// Saves, creates a 14-day link and opens WhatsApp with it.
  Future<void> _shareConfirmation() async {
    if (!_validate()) return;
    setState(() => _form.isGenerating = true);
    try {
      if (!await _saveInvoiceData()) return;
      final code = await widget.services.shareLinks.createInvoiceShareLink(
        _form.buildUpdatedOrder(),
      );
      final message = _form.shareMessage('${Uri.base.origin}/s/$code');
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      // Browsers block window.open after an async gap, so WhatsApp is
      // opened from a fresh tap in this dialog.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('invoice.share'.tr()),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (ctx.mounted) Navigator.of(ctx).pop();
                _snack('invoice.share_link_copied');
              },
              child: Text('invoice.copy'.tr()),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp'),
              onPressed: () {
                launchUrl(
                  Uri.parse(
                    'https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}',
                  ),
                  mode: LaunchMode.externalApplication,
                );
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      );
    } catch (e) {
      _snack('invoice.share_link_failed');
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  /// Makes sure a Microsoft account is signed in (OneDrive and calendar).
  Future<bool> _ensureMicrosoftLogin() async {
    if (!microsoftGraphService.isSupported) return false;
    if (microsoftGraphService.isLoggedIn) return true;

    final wantsLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('invoice.ms_login_title'.tr()),
        content: Text('invoice.ms_login_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: Text('invoice.ms_login_button'.tr()),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (wantsLogin != true) return false;

    final account = await microsoftGraphService.login();
    if (account == null) _snack('invoice.ms_login_failed');
    return account != null;
  }

  /// Outlook calendar entry with the confirmation PDF attached.
  Future<void> _createCalendarEntry() async {
    if (!_validate()) return;
    if (!microsoftGraphService.isSupported) {
      return _snack('invoice.calendar_unsupported');
    }
    if (!await _ensureMicrosoftLogin()) return;

    setState(() => _form.isGenerating = true);
    try {
      if (!await _saveInvoiceData()) return;
      final order = _form.buildUpdatedOrder();
      final pdfBytes = await InvoicePdfGenerator.generateBytes(
        order,
        language: _form.language,
      );
      final fileName = InvoicePdfGenerator.getFilename(order);
      final shoppingListBytes = await PdfGenerator.generateBytesFromSavedOrder(
        order,
      );
      final dateTag =
          '${order.date.year}${order.date.month.toString().padLeft(2, '0')}${order.date.day.toString().padLeft(2, '0')}';
      final shoppingListName =
          'Einkaufsliste_${order.name.replaceAll(' ', '_')}_$dateTag.pdf';

      String? documentUrl;
      String? shoppingListUrl;
      if (EnvConfig.isOneDriveEnabled) {
        documentUrl = await microsoftGraphService.uploadToOneDrive(
          oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
            rootFolder: 'Aufträge',
            date: order.date,
            fileName: fileName,
          ),
          bytes: pdfBytes,
        );
        shoppingListUrl = await microsoftGraphService.uploadToOneDrive(
          oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
            rootFolder: 'Aufträge',
            date: order.date,
            fileName: shoppingListName,
          ),
          bytes: shoppingListBytes,
        );
      }

      final eventStart = InvoiceFormState.calendarStart(order);
      final eventId = await microsoftGraphService.createCalendarEvent(
        subject: 'Blacklodge - ${InvoiceFormState.calendarCustomer(order)}',
        start: eventStart,
        end: eventStart.add(const Duration(hours: 5)),
        bodyContent: _form
            .calendarBodyLines(
              order,
              documentUrl: documentUrl,
              shoppingListUrl: shoppingListUrl,
            )
            .join('\n'),
        location: order.location,
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
      _snack(
        eventId != null ? 'invoice.calendar_created' : 'invoice.calendar_failed',
      );
    } catch (e) {
      debugPrint('Calendar entry error: $e');
      _snack('invoice.calendar_failed');
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  Future<void> _editOfferPosition({int? index}) async {
    final result = await showDocumentPositionDialog(
      context,
      prefix: 'invoice',
      currencyCode: widget.order.currency,
      defaultDate: formatDocumentDate(_form.eventDate),
      existing: index != null ? _form.offerPositions[index] : null,
    );
    if (result != null) {
      setState(() => _form.putOfferPosition(result, index: index));
    }
  }

  Future<void> _editExtraPosition({int? index}) async {
    final result = await showExtraPositionDialog(
      context,
      currencyCode: widget.order.currency,
      existing: index != null ? _form.extraPositions[index] : null,
    );
    if (result != null) {
      setState(() => _form.putExtraPosition(result, index: index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final field = DocumentFieldFactory(
      requiredKey: 'invoice.field_required',
      alignLabelWithHint: true,
      onChanged: () => setState(() {}),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('invoice.title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'de', label: Text('DE')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {_form.language},
              onSelectionChanged: (v) =>
                  setState(() => _form.changeLanguage(v.first)),
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ── Sticky action bar ──────────────────────────────────────────
            Material(
              elevation: 4,
              color: colorScheme.surface,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: InvoiceActionButtons(
                      isGenerating: _form.isGenerating,
                      onSave: _saveOnly,
                      onPreview: _previewPdf,
                      onGeneratePdf: _confirmGeneratePdf,
                      onShare: _shareConfirmation,
                      onCalendar: _createCalendarEntry,
                    ),
                  ),
                ),
              ),
            ),
            // ── Scrollable form ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DocumentOrderBanner(
                          order: widget.order,
                          currency: Currency.fromCode(widget.order.currency),
                        ),
                        const SizedBox(height: 20),
                        DocumentEditorSection(
                          prefix: 'invoice',
                          controller: _form.editorNameCtrl,
                          field: field,
                        ),
                        const SizedBox(height: 20),
                        DocumentClientSection(
                          prefix: 'invoice',
                          nameCtrl: _form.clientNameCtrl,
                          contactCtrl: _form.clientContactCtrl,
                          locationCtrl: _form.locationCtrl,
                          field: field,
                          allRequired: false,
                        ),
                        const SizedBox(height: 20),
                        DocumentEventTypeSection(
                          prefix: 'invoice',
                          selected: _form.eventTypes,
                          onChanged: (types) =>
                              setState(() => _form.setEventTypes(types)),
                        ),
                        const SizedBox(height: 20),
                        DocumentEventDetailsSection(
                          prefix: 'invoice',
                          guestCountCtrl: _form.guestCountCtrl,
                          eventTimeCtrl: _form.eventTimeCtrl,
                          eventDate: _form.eventDate,
                          onDateChanged: (d) =>
                              setState(() => _form.eventDate = d),
                          field: field,
                          timeRequired: false,
                        ),
                        const SizedBox(height: 20),
                        DocumentServiceTypeSection(
                          value: _form.serviceType,
                          onChanged: (v) =>
                              setState(() => _form.serviceType = v),
                        ),
                        const SizedBox(height: 20),
                        DocumentServicesSection(
                          prefix: 'invoice',
                          cocktailsCtrl: _form.cocktailsCtrl,
                          barDescCtrl: _form.barDescCtrl,
                          shotsCtrl: _form.shotsCtrl,
                          field: field,
                        ),
                        const SizedBox(height: 20),
                        InvoicePositionsSection(
                          form: _form,
                          update: _update,
                          field: field,
                          extraHours: InvoiceExtraHoursSection(
                            form: _form,
                            update: _update,
                            field: field,
                            employees: widget.services.watchEmployees(),
                          ),
                          onEditOfferPosition: _editOfferPosition,
                          onEditExtraPosition: _editExtraPosition,
                        ),
                        const SizedBox(height: 20),
                        InvoicePricePreview(form: _form),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
