import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../config/env_config.dart';
import '../../models/additional_service.dart';
import '../../models/order.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/offer_pdf_generator.dart';
import '../../services/pdf_generator.dart';
import '../../widgets/discount_editor.dart';
import '../shared/document_sections/common_sections.dart';
import '../shared/document_sections/document_field.dart';
import '../shared/document_sections/document_services.dart';
import '../shared/document_sections/position_dialog.dart';
import 'offer_form_state.dart';
import 'sections/offer_positions_section.dart';
import 'sections/offer_sections.dart';
import 'widgets/offer_action_buttons.dart';
import 'widgets/offer_price_preview.dart';
import 'widgets/offer_share_dialog.dart';

/// Screen to create and export an Offer (Angebot) from a [SavedOrder].
/// Data and logic live in [OfferFormState]; the sections are widgets in
/// `sections/` and `../shared/document_sections/`.
class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({
    super.key,
    required this.order,
    this.services = const DocumentServices(),
  });

  final SavedOrder order;
  final DocumentServices services;

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  late final OfferFormState _form;

  /// Additional-services catalog (resolves "serviceId:variantId" entries).
  StreamSubscription<List<AdditionalService>>? _catalogSubscription;

  @override
  void initState() {
    super.initState();
    _form = OfferFormState(
      widget.order,
      displayName: widget.services.displayName(),
    );
    _catalogSubscription = widget.services.watchAdditionalServices().listen((
      services,
    ) {
      if (!mounted) return;
      setState(() => _form.setCatalog(services));
    });
  }

  @override
  void dispose() {
    _catalogSubscription?.cancel();
    _form.dispose();
    super.dispose();
  }

  void _update(VoidCallback fn) => setState(fn);

  /// Confirmation dialog for PDF save (used when offer is accepted)
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

  bool _validateOfferBeforeAction() {
    FocusScope.of(context).unfocus();
    setState(() => _form.showValidationErrors = true);

    final isFormValid = _formKey.currentState!.validate();
    final hasRequiredSections =
        _form.hasEventTypeSelection && _form.hasOfferPositions;
    final isValid = isFormValid && hasRequiredSections;

    if (!isValid && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('offer.validation_error'.tr())));
    }

    return isValid;
  }

  Future<bool> _saveOfferData() => _form.save(widget.services.orders);

  void _showSaveFailed() {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('offer.save_failed'.tr())));
    }
  }

  Future<void> _saveOnly() async {
    if (!_validateOfferBeforeAction()) return;
    setState(() => _form.isGenerating = true);
    try {
      final saved = await _saveOfferData();
      if (!saved) return _showSaveFailed();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('offer.saved'.tr())));
        // Mark as saved and navigate back to orders overview
        setState(() => _form.savedSuccessfully = true);
        context.go('/orders');
      }
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  Future<void> _previewPdf() async {
    if (!_validateOfferBeforeAction()) return;
    setState(() => _form.isGenerating = true);
    try {
      final saved = await _saveOfferData();
      if (!saved) return _showSaveFailed();
      final offer = _form.buildOfferData();
      final pdfBytes = await OfferPdfGenerator.generatePdfBytes(offer);
      if (mounted) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      }
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  Future<void> _generatePdf() async {
    if (!_validateOfferBeforeAction()) return;
    setState(() => _form.isGenerating = true);
    try {
      final saved = await _saveOfferData();
      if (!saved) return _showSaveFailed();
      final offer = _form.buildOfferData();
      final pdfBytes = await OfferPdfGenerator.generatePdfBytes(offer);

      // Upload to OneDrive if supported and in production
      final safeName = offer.orderName.replaceAll(' ', '_');
      final dateTag =
          '${offer.eventDate.year}${offer.eventDate.month.toString().padLeft(2, '0')}${offer.eventDate.day.toString().padLeft(2, '0')}';
      if (microsoftGraphService.isSupported && EnvConfig.isOneDriveEnabled) {
        final fileName = 'Angebot_${safeName}_$dateTag.pdf';
        await microsoftGraphService.uploadToOneDrive(
          oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
            rootFolder: 'Angebote',
            date: offer.eventDate,
            fileName: fileName,
          ),
          bytes: pdfBytes,
        );

        // Also upload the Einkaufsliste (shopping list) alongside the offer;
        // this never creates a calendar entry (that happens on accept).
        final shoppingListBytes =
            await PdfGenerator.generateBytesFromSavedOrder(widget.order);
        await microsoftGraphService.uploadToOneDrive(
          oneDrivePath: MicrosoftGraphService.buildOneDrivePath(
            rootFolder: 'Angebote',
            date: offer.eventDate,
            fileName: 'Einkaufsliste_${safeName}_$dateTag.pdf',
          ),
          bytes: shoppingListBytes,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('offer.pdf_created'.tr())));
      }
    } finally {
      if (mounted) setState(() => _form.isGenerating = false);
    }
  }

  Future<void> _shareOffer() async {
    if (!_validateOfferBeforeAction()) return;

    final cocktails = splitCommaList(_form.cocktailsCtrl.text);
    // Snapshot of the offer data at the time the dialog opens
    final offerSnapshot = _form.buildOfferData();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => OfferShareDialog(
        clientName: _form.clientNameCtrl.text.trim(),
        editorName: _form.editorNameCtrl.text.trim(),
        selectedCocktails: cocktails,
        createShareLink: (bullets) =>
            widget.services.shareLinks.createOfferShareLink(
              offerSnapshot,
              orderId: widget.order.id,
              bullets: bullets,
            ),
      ),
    );
  }

  Future<void> _editPosition({int? index}) async {
    final result = await showDocumentPositionDialog(
      context,
      prefix: 'offer',
      currencyCode: _form.currency.code,
      defaultDate: formatDocumentDate(_form.eventDate),
      existing: index != null ? _form.offerPositions[index] : null,
    );
    if (result != null) {
      setState(() => _form.putPosition(result, index: index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final curr = _form.currency;
    final colorScheme = Theme.of(context).colorScheme;
    final field = DocumentFieldFactory(
      requiredKey: 'offer.field_required',
      autovalidate: _form.showValidationErrors,
      onChanged: () => setState(() {}),
    );

    return PopScope(
      canPop: !_form.savedSuccessfully,
      onPopInvokedWithResult: (didPop, result) {
        if (_form.savedSuccessfully && !didPop) {
          context.go('/orders');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('offer.title'.tr()),
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
              // ── Sticky action bar ──────────────────────────────────────
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
                      child: OfferActionButtons(
                        isGenerating: _form.isGenerating,
                        onSaveOnly: _saveOnly,
                        onPreview: _previewPdf,
                        onGeneratePdf: _confirmGeneratePdf,
                        onShare: _shareOffer,
                      ),
                    ),
                  ),
                ),
              ),
              // ── Scrollable form ────────────────────────────────────────
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
                            currency: curr,
                          ),
                          const SizedBox(height: 20),
                          OfferCurrencySection(form: _form, update: _update),
                          const SizedBox(height: 20),
                          DocumentEditorSection(
                            prefix: 'offer',
                            controller: _form.editorNameCtrl,
                            field: field,
                          ),
                          const SizedBox(height: 20),
                          DocumentClientSection(
                            prefix: 'offer',
                            nameCtrl: _form.clientNameCtrl,
                            contactCtrl: _form.clientContactCtrl,
                            locationCtrl: _form.locationCtrl,
                            field: field,
                            allRequired: true,
                          ),
                          const SizedBox(height: 20),
                          DocumentEventDetailsSection(
                            prefix: 'offer',
                            guestCountCtrl: _form.guestCountCtrl,
                            eventTimeCtrl: _form.eventTimeCtrl,
                            eventDate: _form.eventDate,
                            onDateChanged: (d) =>
                                setState(() => _form.eventDate = d),
                            field: field,
                            guestValidator: (v) =>
                                OfferFormState.guestCountErrorKey(v)?.tr(),
                            timeRequired: true,
                          ),
                          const SizedBox(height: 20),
                          DocumentEventTypeSection(
                            prefix: 'offer',
                            selected: _form.eventTypes,
                            onChanged: (types) =>
                                setState(() => _form.setEventTypes(types)),
                            framed: true,
                            errorKey: _form.eventTypeErrorKey,
                          ),
                          const SizedBox(height: 20),
                          DocumentServiceTypeSection(
                            value: _form.serviceType,
                            onChanged: (v) =>
                                setState(() => _form.changeServiceType(v)),
                            showHint: true,
                          ),
                          const SizedBox(height: 20),
                          DocumentServicesSection(
                            prefix: 'offer',
                            cocktailsCtrl: _form.cocktailsCtrl,
                            barDescCtrl: _form.barDescCtrl,
                            shotsCtrl: _form.shotsCtrl,
                            field: field,
                            cocktailsValidator: (v) =>
                                _form.cocktailsErrorKey(v)?.tr(),
                          ),
                          const SizedBox(height: 20),
                          OfferEmployeesSection(
                            form: _form,
                            update: _update,
                            employees: widget.services.watchEmployees(),
                          ),
                          const SizedBox(height: 20),
                          OfferPositionsSection(
                            form: _form,
                            update: _update,
                            onEdit: _editPosition,
                          ),
                          const SizedBox(height: 20),
                          DiscountEditor(
                            currency: curr,
                            subtotal: _form.positionsSubtotal,
                            isPercent: _form.discountIsPercent,
                            valueController: _form.discountValueCtrl,
                            remarkController: _form.discountRemarkCtrl,
                            onTypeChanged: (isPercent) =>
                                setState(() => _form.setDiscountType(isPercent)),
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 20),
                          OfferPricePreview(
                            currency: curr,
                            orderTotal: _form.previewOrderTotal,
                            distanceKm: _form.distanceKm,
                            travelCostPerKm: _form.travelCostPerKm,
                            barCost: _form.barCost,
                            discount: _form.discountAmount,
                            discountPercent: _form.discountPercent,
                            positionsTotal: _form.positionsSubtotal,
                          ),
                          const SizedBox(height: 20),
                          OfferAdditionalInfoSection(form: _form),
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
      ),
    );
  }
}
