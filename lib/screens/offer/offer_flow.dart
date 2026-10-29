import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/additional_service.dart';
import '../../models/employee.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../widgets/discount_editor.dart';
import '../forms/steps/wizard_widgets.dart' show WizardSection;
import '../shared/document_sections/common_sections.dart';
import '../shared/document_sections/document_field.dart';
import '../shared/document_sections/document_flow.dart';
import '../shared/document_sections/document_services.dart';
import '../shared/document_sections/position_dialog.dart';
import 'offer_form_state.dart';
import 'sections/offer_positions_section.dart';
import 'widgets/offer_share_dialog.dart';

/// Browser-only PDF work (printing, OneDrive), passed in by the screen.
typedef OfferPdfAction =
    Future<void> Function(BuildContext context, OfferData offer);

Future<void> _noPdfAction(BuildContext context, OfferData offer) async {}

/// The offer as a four-step flow: (1) client and date, (2) services and
/// staff, (3) positions, (4) price, discount, send. One primary action at
/// the bottom ("Weiter", last step "Senden" = share sheet); save, PDF
/// preview, OneDrive PDF and the share link are in the "…" menu.
class OfferFlow extends StatefulWidget {
  const OfferFlow({
    super.key,
    required this.order,
    this.services = const DocumentServices(),
    this.previewPdf = _noPdfAction,
    this.exportPdf = _noPdfAction,
    @visibleForTesting this.initialStep = 0,
  });

  final SavedOrder order;
  final int initialStep;
  final DocumentServices services;

  /// `Printing.layoutPdf` of the offer PDF.
  final OfferPdfAction previewPdf;

  /// Generates the PDF and uploads it (and the shopping list) to OneDrive.
  final OfferPdfAction exportPdf;

  @override
  State<OfferFlow> createState() => _OfferFlowState();
}

class _OfferFlowState extends State<OfferFlow>
    with DocumentStepFlow<OfferFlow> {
  late final OfferFormState _form;
  StreamSubscription<List<AdditionalService>>? _catalogSubscription;
  StreamSubscription<List<Employee>>? _employeeSubscription;
  List<Employee> _employees = const [];

  @override
  List<DocIssue> get issues => _form.issues;

  late final DocHints _hints = DocHints(hintOf: hintOf, anchorOf: anchorOf);

  @override
  void initState() {
    super.initState();
    step = widget.initialStep;
    _form = OfferFormState(
      widget.order,
      displayName: widget.services.displayName(),
    );
    // Every edit rebuilds the flow (former `onChanged: setState`).
    for (final c in _form.controllers) {
      c.addListener(_rebuild);
    }
    _catalogSubscription = widget.services.watchAdditionalServices().listen((
      services,
    ) {
      if (mounted) setState(() => _form.setCatalog(services));
    });
    _employeeSubscription = widget.services.watchEmployees().listen((list) {
      if (mounted) setState(() => _employees = list);
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _catalogSubscription?.cancel();
    _employeeSubscription?.cancel();
    for (final c in _form.controllers) {
      c.removeListener(_rebuild);
    }
    _form.dispose();
    disposeStepFlow();
    super.dispose();
  }

  void _update(VoidCallback fn) => setState(fn);

  void _snack(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  /// All steps valid? Otherwise jump to the first problem and explain.
  bool _validate() {
    final issue = checkAll();
    setState(() => _form.showValidationErrors = true);
    if (issue == null) return true;
    _snack('offer.validation_error');
    return false;
  }

  /// Saves; false (with a message) when a write failed.
  Future<bool> _save() async {
    final saved = await _form.save(widget.services.orders);
    if (!saved) _snack('offer.save_failed');
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

  Future<void> _saveOnly() async {
    if (!_validate()) return;
    await _busy(() async {
      if (!await _save()) return;
      if (!mounted) return;
      _snack('offer.saved');
      setState(() => _form.savedSuccessfully = true);
      context.go('/orders');
    });
  }

  Future<void> _previewPdf() async {
    if (!_validate()) return;
    await _busy(() async {
      if (!await _save() || !mounted) return;
      await widget.previewPdf(context, _form.buildOfferData());
    });
  }

  Future<void> _confirmGeneratePdf() async {
    final ok = await showConfirmSheet(
      context,
      title: 'invoice.confirm_save_title'.tr(),
      body: 'invoice.confirm_save_msg'.tr(),
      confirmLabel: 'common.save'.tr(),
    );
    if (!ok || !mounted || !_validate()) return;
    await _busy(() async {
      if (!await _save() || !mounted) return;
      await widget.exportPdf(context, _form.buildOfferData());
      _snack('offer.pdf_created');
    });
  }

  Future<void> _share() async {
    if (!_validate()) return;
    // Snapshot of the offer data at the time the sheet opens.
    final offerSnapshot = _form.buildOfferData();
    await showOfferShareSheet(
      context,
      clientName: _form.clientNameCtrl.text.trim(),
      editorName: _form.editorNameCtrl.text.trim(),
      selectedCocktails: splitCommaList(_form.cocktailsCtrl.text),
      loadCocktailNames: widget.services.loadCocktailNames,
      generateMiddle: widget.services.generateShareMiddle,
      createShareLink: (bullets) =>
          widget.services.shareLinks.createOfferShareLink(
            offerSnapshot,
            orderId: widget.order.id,
            bullets: bullets,
          ),
    );
  }

  Future<void> _editPosition({int? index}) async {
    final result = await showPositionSheet(
      context,
      prefix: 'offer',
      currencyCode: _form.currency.code,
      defaultDate: formatDocumentDate(_form.eventDate),
      existing: index != null ? _form.offerPositions[index] : null,
    );
    if (result != null && mounted) {
      setState(() => _form.putPosition(result, index: index));
    }
  }

  Widget _stepContent() => switch (step) {
    0 => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DocumentOrderSummary(order: widget.order, currency: _form.currency),
        DocumentSettingsSection(
          prefix: 'offer',
          language: _form.language,
          onLanguage: (l) => setState(() => _form.changeLanguage(l)),
          currency: _form.currency,
          onCurrency: (c) => setState(() => _form.currency = c),
          editorCtrl: _form.editorNameCtrl,
          hints: _hints,
        ),
        DocumentClientSection(
          prefix: 'offer',
          nameCtrl: _form.clientNameCtrl,
          contactCtrl: _form.clientContactCtrl,
          locationCtrl: _form.locationCtrl,
          hints: _hints,
        ),
        DocumentScheduleSection(
          prefix: 'offer',
          guestCountCtrl: _form.guestCountCtrl,
          eventTimeCtrl: _form.eventTimeCtrl,
          eventDate: _form.eventDate,
          onDateChanged: (d) => setState(() => _form.eventDate = d),
          hints: _hints,
        ),
        DocumentEventTypeSection(
          prefix: 'offer',
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
          onChanged: (v) => setState(() => _form.changeServiceType(v)),
          showHint: true,
        ),
        DocumentServicesSection(
          prefix: 'offer',
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
    2 => OfferPositionsSection(
      form: _form,
      update: _update,
      onEdit: _editPosition,
      hints: _hints,
    ),
    _ => _priceStep(),
  };

  Widget _priceStep() {
    final curr = _form.currency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DocTotalHero(
          label: 'offer.total'.tr(),
          total: curr.format(_form.grandTotal),
          meta: _form.clientNameCtrl.text.trim(),
        ),
        DiscountEditor(
          currency: curr,
          subtotal: _form.positionsSubtotal,
          isPercent: _form.discountIsPercent,
          valueController: _form.discountValueCtrl,
          remarkController: _form.discountRemarkCtrl,
          onTypeChanged: (v) => setState(() => _form.setDiscountType(v)),
          onChanged: _rebuild,
          hints: _hints,
        ),
        WizardSection(
          caption: 'offer.price_preview'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DocAmountRow(
                label: 'offer.positions_sum'.tr(),
                value: curr.format(_form.positionsSubtotal),
              ),
              if (_form.discountAmount > 0)
                DocAmountRow(
                  label: discountLabelText(
                    'offer.discount'.tr(),
                    _form.discountPercent,
                  ),
                  value: '-${curr.format(_form.discountAmount)}',
                ),
              const DocDivider(),
              DocAmountRow(
                label: 'offer.total'.tr(),
                value: curr.format(_form.grandTotal),
                bold: true,
              ),
            ],
          ),
        ),
        WizardSection(
          caption: 'offer.additional_info'.tr(),
          child: DocTextField(
            controller: _form.additionalInfoCtrl,
            label: 'offer.additional_info'.tr(),
            minLines: 4,
            maxLines: 8,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = step == documentStepCount - 1;
    return DocumentFlowScaffold(
      flow: this,
      saved: _form.savedSuccessfully,
      loading: _form.isGenerating,
      primaryLabel: last ? 'docflow.send'.tr() : 'common.next'.tr(),
      dimmed: !last && !stepComplete(step),
      onPrimary: last ? _share : nextStep,
      menu: [
        DocMenuAction('offer.save_only'.tr(), Icons.save_outlined, _saveOnly),
        DocMenuAction('offer.preview'.tr(), Icons.visibility, _previewPdf),
        DocMenuAction(
          'offer.generate_pdf'.tr(),
          Icons.picture_as_pdf,
          _confirmGeneratePdf,
        ),
        DocMenuAction('offer.generate_link'.tr(), Icons.link, _share),
      ],
      child: _stepContent(),
    );
  }
}

/// "Rabatt" or "Rabatt (10%)".
String discountLabelText(String base, double percent) =>
    percent > 0 ? '$base (${formatDiscountPercent(percent)}%)' : base;
