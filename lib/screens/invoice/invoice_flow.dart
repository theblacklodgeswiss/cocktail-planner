import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/employee.dart';
import '../../models/order.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../utils/currency.dart';
import '../shared/document_sections/discount_editor.dart';
import '../forms/steps/wizard_widgets.dart' show FieldHint;
import '../offer/offer_form_state.dart' show formatDocumentDate;
import '../shared/document_sections/common_sections.dart';
import '../shared/document_sections/document_field.dart';
import '../shared/document_sections/document_flow.dart';
import '../shared/document_sections/document_services.dart';
import '../shared/document_sections/position_dialog.dart';
import 'invoice_form_state.dart';
import 'sections/invoice_positions_section.dart';
import 'sections/invoice_preview_and_actions.dart';

/// Browser-only work on the built invoice (PDF preview, OneDrive upload).
typedef InvoicePdfAction =
    Future<void> Function(
      BuildContext context,
      SavedOrder invoice,
      String language,
    );

/// Creates the Outlook entry for the saved invoice (PDF, uploads,
/// attachments) and returns the message key of the result.
typedef InvoiceCalendarAction =
    Future<String> Function(
      BuildContext context,
      SavedOrder invoice,
      InvoiceFormState form,
    );

Future<void> _noPdf(BuildContext c, SavedOrder o, String l) async {}
/// Shows a message key in the flow (above its bottom area).
typedef DocNotify = void Function(String messageKey);

Future<void> _noPrepare(BuildContext c, DocNotify n) async {}
Future<bool> _noLogin(BuildContext c, DocNotify n) async => false;
bool _unsupported() => false;
Future<String> _noCalendar(
  BuildContext c,
  SavedOrder o,
  InvoiceFormState f,
) async => 'invoice.calendar_failed';

/// The order confirmation (Auftragsbestätigung) as a four-step flow:
/// (1) client and date, (2) services and staff, (3) positions, (4) price,
/// discount and "PDF speichern" (save, upload, copy the 14-day link). Save,
/// preview, WhatsApp share and the calendar entry are in the "…" menu.
class InvoiceFlow extends StatefulWidget {
  const InvoiceFlow({
    super.key,
    required this.order,
    this.services = const DocumentServices(),
    this.previewPdf = _noPdf,
    this.beforeExport = _noPrepare,
    this.uploadPdf = _noPdf,
    this.calendarSupported = _unsupported,
    this.ensureLogin = _noLogin,
    this.createCalendarEntry = _noCalendar,
    @visibleForTesting this.initialStep = 0,
  });

  final SavedOrder order;
  final int initialStep;
  final DocumentServices services;
  final InvoicePdfAction previewPdf;

  /// Before "PDF speichern": offers the Microsoft login (OneDrive).
  final Future<void> Function(BuildContext context, DocNotify notify)
  beforeExport;

  /// Generates the PDF and uploads it to OneDrive (when signed in).
  final InvoicePdfAction uploadPdf;
  final bool Function() calendarSupported;
  final Future<bool> Function(BuildContext context, DocNotify notify)
  ensureLogin;
  final InvoiceCalendarAction createCalendarEntry;

  @override
  State<InvoiceFlow> createState() => _InvoiceFlowState();
}

class _InvoiceFlowState extends State<InvoiceFlow>
    with DocumentStepFlow<InvoiceFlow> {
  late final InvoiceFormState _form;
  StreamSubscription<List<Employee>>? _employeeSubscription;
  List<Employee> _employees = const [];

  @override
  List<DocIssue> get issues => _form.issues;

  late final DocHints _hints = DocHints(hintOf: hintOf, anchorOf: anchorOf);

  @override
  void initState() {
    super.initState();
    step = widget.initialStep;
    _form = InvoiceFormState(
      widget.order,
      displayName: widget.services.displayName(),
    );
    for (final c in _form.controllers) {
      c.addListener(_rebuild);
    }
    _employeeSubscription = widget.services.watchEmployees().listen((list) {
      if (mounted) setState(() => _employees = list);
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _employeeSubscription?.cancel();
    for (final c in _form.controllers) {
      c.removeListener(_rebuild);
    }
    _form.dispose();
    disposeStepFlow();
    super.dispose();
  }

  void _update(VoidCallback fn) => setState(fn);

  void _snack(String key) => showSnack(key);

  bool _validate() {
    final issue = checkAll();
    if (issue == null) return true;
    _snack(issue.messageKey);
    return false;
  }

  Future<bool> _save() async {
    final saved = await _form.save(widget.services.orders);
    if (!saved) _snack('invoice.save_failed');
    return saved;
  }

  Future<void> _busy(Future<void> Function() body) async {
    setState(() => _form.isGenerating = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  String _link(String code) => '${Uri.base.origin}/s/$code';

  Future<void> _saveOnly() async {
    if (!_validate()) return;
    await _busy(() async {
      if (await _save()) _snack('invoice.saved');
    });
  }

  Future<void> _previewPdf() async {
    if (!_validate()) return;
    await _busy(() async {
      if (!await _save() || !mounted) return;
      await widget.previewPdf(
        context,
        _form.buildUpdatedOrder(),
        _form.language,
      );
    });
  }

  Future<void> _confirmGeneratePdf() async {
    final ok = await showConfirmSheet(
      context,
      title: 'invoice.confirm_save_title'.tr(),
      body: 'invoice.confirm_save_msg'.tr(),
      confirmLabel: 'common.save'.tr(),
    );
    if (ok && mounted) await _generatePdf();
  }

  /// Saves, uploads the PDF and copies a fresh 14-day link.
  Future<void> _generatePdf() async {
    if (!_validate()) return;
    await widget.beforeExport(context, _snack);
    if (!mounted) return;
    await _busy(() async {
      try {
        if (!await _save() || !mounted) return;
        final built = _form.buildUpdatedOrder();
        await widget.uploadPdf(context, built, _form.language);
        final code = await widget.services.shareLinks.createInvoiceShareLink(
          built,
        );
        await Clipboard.setData(ClipboardData(text: _link(code)));
        _snack('invoice.share_link_copied');
      } catch (e) {
        _snack('invoice.share_link_failed');
      }
    });
  }

  /// Saves, creates a link and offers it for WhatsApp in a sheet.
  Future<void> _share() async {
    if (!_validate()) return;
    await _busy(() async {
      try {
        if (!await _save()) return;
        final code = await widget.services.shareLinks.createInvoiceShareLink(
          _form.buildUpdatedOrder(),
        );
        final message = _form.shareMessage(_link(code));
        await Clipboard.setData(ClipboardData(text: message));
        if (!mounted) return;
        // Browsers block window.open after an async gap, so WhatsApp is
        // opened from a fresh tap in this sheet.
        await showAppSheet<void>(
          context,
          builder: (sheet) => _InvoiceShareSheet(
            message: message,
            onCopied: () => _snack('invoice.share_link_copied'),
          ),
        );
      } catch (e) {
        _snack('invoice.share_link_failed');
      }
    });
  }

  Future<void> _calendar() async {
    if (!_validate()) return;
    if (!widget.calendarSupported()) {
      return _snack('invoice.calendar_unsupported');
    }
    if (!await widget.ensureLogin(context, _snack) || !mounted) return;
    await _busy(() async {
      try {
        if (!await _save() || !mounted) return;
        _snack(
          await widget.createCalendarEntry(
            context,
            _form.buildUpdatedOrder(),
            _form,
          ),
        );
      } catch (e) {
        debugPrint('Calendar entry error: $e');
        _snack('invoice.calendar_failed');
      }
    });
  }

  Future<void> _editOfferPosition({int? index}) async {
    final result = await showPositionSheet(
      context,
      prefix: 'invoice',
      currencyCode: widget.order.currency,
      defaultDate: formatDocumentDate(_form.eventDate),
      existing: index != null ? _form.offerPositions[index] : null,
    );
    if (result != null && mounted) {
      setState(() => _form.putOfferPosition(result, index: index));
    }
  }

  Future<void> _editExtraPosition({int? index}) async {
    final result = await showPositionSheet(
      context,
      prefix: 'invoice',
      currencyCode: widget.order.currency,
      existing: index != null ? _form.extraPositions[index] : null,
      extra: true,
    );
    if (result != null && mounted) {
      setState(() => _form.putExtraPosition(result, index: index));
    }
  }

  Widget _stepContent() {
    final curr = Currency.fromCode(widget.order.currency);
    return switch (step) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocumentOrderSummary(order: widget.order, currency: curr),
          DocumentSettingsSection(
            prefix: 'invoice',
            language: _form.language,
            onLanguage: (l) => setState(() => _form.changeLanguage(l)),
            editorCtrl: _form.editorNameCtrl,
            hints: _hints,
          ),
          DocumentClientSection(
            prefix: 'invoice',
            nameCtrl: _form.clientNameCtrl,
            contactCtrl: _form.clientContactCtrl,
            locationCtrl: _form.locationCtrl,
            hints: _hints,
          ),
          DocumentScheduleSection(
            prefix: 'invoice',
            guestCountCtrl: _form.guestCountCtrl,
            eventTimeCtrl: _form.eventTimeCtrl,
            eventDate: _form.eventDate,
            onDateChanged: (d) => setState(() => _form.eventDate = d),
            hints: _hints,
          ),
          DocumentEventTypeSection(
            prefix: 'invoice',
            selected: _form.eventTypes,
            onChanged: (t) => setState(() => _form.setEventTypes(t)),
            hints: _hints,
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocumentServiceTypeSection(
            value: _form.serviceType,
            onChanged: (v) => setState(() => _form.serviceType = v),
          ),
          DocumentServicesSection(
            prefix: 'invoice',
            cocktailsCtrl: _form.cocktailsCtrl,
            barDescCtrl: _form.barDescCtrl,
            shotsCtrl: _form.shotsCtrl,
            hints: _hints,
            loadCatalog: widget.services.loadCocktailNames,
          ),
          DocumentEmployeesSection(
            employees: _employees,
            selected: _form.selectedEmployees,
            onToggle: (n, s) => setState(() => _form.toggleEmployee(n, s)),
            hints: _hints,
          ),
        ],
      ),
      2 => InvoicePositionsSection(
        form: _form,
        update: _update,
        hints: _hints,
        onEditOfferPosition: _editOfferPosition,
        onEditExtraPosition: _editExtraPosition,
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: anchorOf('total'),
            child: DocTotalHero(
              label: 'invoice.grand_total'.tr(),
              total: curr.format(_form.grandTotal),
              meta: _form.clientNameCtrl.text.trim(),
            ),
          ),
          FieldHint(hintOf('total')),
          DiscountEditor(
            currency: curr,
            subtotal: _form.subtotal,
            isPercent: _form.discountIsPercent,
            valueController: _form.discountValueCtrl,
            remarkController: _form.discountRemarkCtrl,
            onTypeChanged: (v) => setState(() => _form.setDiscountType(v)),
            onChanged: _rebuild,
            hints: _hints,
          ),
          InvoiceBreakdown(form: _form),
          const SizedBox(height: AppSpace.s8),
        ],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final last = step == documentStepCount - 1;
    return DocumentFlowScaffold(
      flow: this,
      loading: _form.isGenerating,
      primaryLabel: last ? 'invoice.generate_pdf'.tr() : 'common.next'.tr(),
      dimmed: !last && !stepComplete(step),
      onPrimary: last ? _confirmGeneratePdf : nextStep,
      menu: [
        DocMenuAction('invoice.save'.tr(), Icons.save_outlined, _saveOnly),
        DocMenuAction('invoice.preview'.tr(), Icons.visibility, _previewPdf),
        DocMenuAction('invoice.share'.tr(), Icons.share, _share),
        DocMenuAction('invoice.create_calendar'.tr(), Icons.event, _calendar),
        DocMenuAction(
          'invoice.generate_pdf'.tr(),
          Icons.picture_as_pdf,
          _confirmGeneratePdf,
        ),
      ],
      child: _stepContent(),
    );
  }
}

/// Message with the link, "WhatsApp" and "Kopieren" (was a dialog).
class _InvoiceShareSheet extends StatelessWidget {
  const _InvoiceShareSheet({required this.message, required this.onCopied});

  final String message;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'invoice.share'.tr(),
          style: AppText.heroTitle.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s8),
        SelectableText(message, style: AppText.body.copyWith(color: p.text)),
        const SizedBox(height: AppSpace.s24),
        PrimaryButton(
          label: 'WhatsApp',
          onPressed: () {
            launchUrl(
              Uri.parse(
                'https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}',
              ),
              mode: LaunchMode.externalApplication,
            );
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: AppSpace.s8),
        SecondaryButton(
          label: 'invoice.copy'.tr(),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: message));
            if (context.mounted) Navigator.of(context).pop();
            onCopied();
          },
        ),
      ],
    );
  }
}
