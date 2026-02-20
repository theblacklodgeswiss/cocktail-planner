import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../data/order_repository.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/offer_pdf_generator.dart';
import '../../utils/currency.dart';
import 'widgets/event_type_selector.dart';
import 'widgets/offer_action_buttons.dart';
import 'widgets/offer_price_preview.dart';
import 'widgets/section_header.dart';

/// Screen to create and export an Offer (Angebot) from a [SavedOrder].
class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({super.key, required this.order});

  final SavedOrder order;

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();

  // Language
  String _language = 'de';

  // Event date (editable)
  late DateTime _eventDate;

  // Controllers
  final _editorNameCtrl =
      TextEditingController(text: 'Mario Kantharoobarajah');
  final _eventTimeCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientContactCtrl = TextEditingController();
  late final TextEditingController _guestCountCtrl;
  final _cocktailsCtrl = TextEditingController();
  final _barDescCtrl = TextEditingController();
  final _shotsCtrl = TextEditingController();
  late final TextEditingController _orderTotalCtrl;
  final _distanceKmCtrl = TextEditingController();
  final _travelCostPerKmCtrl = TextEditingController(text: '0.70');
  final _barCostCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  late final TextEditingController _additionalInfoCtrl;

  // Event types
  final Set<EventType> _eventTypes = {};

  // Extra positions
  final List<ExtraPosition> _extraPositions = [];

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _eventDate = widget.order.date;
    _guestCountCtrl =
        TextEditingController(text: widget.order.personCount.toString());
    _orderTotalCtrl =
        TextEditingController(text: widget.order.total.toStringAsFixed(2));

    // Pre-fill from order data
    _cocktailsCtrl.text = widget.order.cocktails.join(', ');
    _shotsCtrl.text = widget.order.shots.join(', ');
    _barDescCtrl.text = widget.order.bar;
    _distanceKmCtrl.text =
        widget.order.distanceKm > 0 ? widget.order.distanceKm.toString() : '';
    _barCostCtrl.text = widget.order.thekeCost > 0
        ? widget.order.thekeCost.toStringAsFixed(2)
        : '';

    // Load saved offer data from order
    _clientNameCtrl.text = widget.order.offerClientName;
    _clientContactCtrl.text = widget.order.offerClientContact;
    _eventTimeCtrl.text = widget.order.offerEventTime;
    _discountCtrl.text = widget.order.offerDiscount > 0
        ? widget.order.offerDiscount.toStringAsFixed(2)
        : '';
    _language = widget.order.offerLanguage;

    // Load event types
    for (final typeStr in widget.order.offerEventTypes) {
      final type = EventType.values.where((e) => e.name == typeStr).firstOrNull;
      if (type != null) _eventTypes.add(type);
    }

    // Load extra positions
    for (final posData in widget.order.offerExtraPositions) {
      _extraPositions.add(ExtraPosition.fromJson(posData));
    }

    // Set additional info based on language
    _additionalInfoCtrl = TextEditingController(
      text: _language == 'en'
          ? OfferData.defaultAdditionalInfoEn
          : OfferData.defaultAdditionalInfoDe,
    );
  }

  @override
  void dispose() {
    _editorNameCtrl.dispose();
    _eventTimeCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientContactCtrl.dispose();
    _guestCountCtrl.dispose();
    _cocktailsCtrl.dispose();
    _barDescCtrl.dispose();
    _shotsCtrl.dispose();
    _orderTotalCtrl.dispose();
    _distanceKmCtrl.dispose();
    _travelCostPerKmCtrl.dispose();
    _barCostCtrl.dispose();
    _discountCtrl.dispose();
    _additionalInfoCtrl.dispose();
    super.dispose();
  }

  void _onLanguageChanged(String lang) {
    setState(() {
      _language = lang;
      _additionalInfoCtrl.text = lang == 'en'
          ? OfferData.defaultAdditionalInfoEn
          : OfferData.defaultAdditionalInfoDe;
    });
  }

  OfferData _buildOfferData() {
    final cocktails = _cocktailsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final shots = _shotsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return OfferData(
      orderName: widget.order.name,
      eventDate: _eventDate,
      eventTime: _eventTimeCtrl.text.trim(),
      currency: widget.order.currency,
      guestCount: int.tryParse(_guestCountCtrl.text.trim()) ??
          widget.order.personCount,
      editorName: _editorNameCtrl.text.trim(),
      clientName: _clientNameCtrl.text.trim(),
      clientContact: _clientContactCtrl.text.trim(),
      eventTypes: Set.of(_eventTypes),
      cocktails: cocktails,
      shots: shots,
      barDescription: _barDescCtrl.text.trim(),
      orderTotal:
          double.tryParse(_orderTotalCtrl.text.trim()) ?? widget.order.total,
      distanceKm: int.tryParse(_distanceKmCtrl.text.trim()) ?? 0,
      travelCostPerKm:
          double.tryParse(_travelCostPerKmCtrl.text.trim()) ?? 0.70,
      barCost: double.tryParse(_barCostCtrl.text.trim()) ?? 0,
      discount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
      additionalInfo: _additionalInfoCtrl.text,
      language: _language,
      extraPositions: List.of(_extraPositions),
    );
  }

  Future<void> _saveOfferData() async {
    await orderRepository.updateOfferData(
      orderId: widget.order.id,
      clientName: _clientNameCtrl.text.trim(),
      clientContact: _clientContactCtrl.text.trim(),
      eventTime: _eventTimeCtrl.text.trim(),
      eventTypes: _eventTypes.map((e) => e.name).toList(),
      discount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
      language: _language,
      eventDate: _eventDate,
      extraPositions: _extraPositions.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> _previewPdf() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isGenerating = true);
    try {
      await _saveOfferData();
      final offer = _buildOfferData();
      final pdfBytes = await OfferPdfGenerator.generatePdfBytes(offer);
      if (mounted) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generatePdf() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isGenerating = true);
    try {
      await _saveOfferData();
      final offer = _buildOfferData();
      final pdfBytes = await OfferPdfGenerator.generatePdfBytes(offer);
      
      // Upload to OneDrive if supported
      final safeName = offer.orderName.replaceAll(' ', '_');
      final dateTag = '${offer.eventDate.year}${offer.eventDate.month.toString().padLeft(2, '0')}${offer.eventDate.day.toString().padLeft(2, '0')}';
      if (microsoftGraphService.isSupported) {
        final fileName = 'Angebot_${safeName}_$dateTag.pdf';
        final oneDrivePath = MicrosoftGraphService.buildOneDrivePath(
          rootFolder: 'Angebote',
          date: offer.eventDate,
          fileName: fileName,
        );
        await microsoftGraphService.uploadToOneDrive(
          oneDrivePath: oneDrivePath,
          bytes: pdfBytes,
        );
      }
      
      // Share/download the PDF
      final safeNameLower = offer.orderName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'angebot_${safeNameLower}_$dateTag.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('offer.pdf_created'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _printPdf() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isGenerating = true);
    try {
      await _saveOfferData();
      final offer = _buildOfferData();
      final pdfBytes = await OfferPdfGenerator.generatePdfBytes(offer);
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name:
              'angebot_${offer.orderName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}.pdf',
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final curr = Currency.fromCode(widget.order.currency);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
              selected: {_language},
              onSelectionChanged: (v) => _onLanguageChanged(v.first),
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderInfoBanner(colorScheme, curr),
                  const SizedBox(height: 20),
                  _buildEditorSection(),
                  const SizedBox(height: 20),
                  _buildClientSection(),
                  const SizedBox(height: 20),
                  _buildEventTypeSection(),
                  const SizedBox(height: 20),
                  _buildGuestCountSection(),
                  const SizedBox(height: 20),
                  _buildServicesSection(),
                  const SizedBox(height: 20),
                  _buildPricingSection(curr),
                  const SizedBox(height: 20),
                  _buildAdditionalInfoSection(),
                  const SizedBox(height: 32),
                  OfferActionButtons(
                    isGenerating: _isGenerating,
                    onPreview: _previewPdf,
                    onGeneratePdf: _generatePdf,
                    onPrint: _printPdf,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoBanner(ColorScheme colorScheme, Currency curr) {
    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: Text(widget.order.name),
        subtitle: Text(
          '${widget.order.date.day.toString().padLeft(2, '0')}.${widget.order.date.month.toString().padLeft(2, '0')}.${widget.order.date.year}'
          ' • ${curr.format(widget.order.total)}',
        ),
      ),
    );
  }

  Widget _buildEditorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.editor'.tr()),
        const SizedBox(height: 8),
        SizedBox(
          width: 400,
          child: _field(
            controller: _editorNameCtrl,
            label: 'offer.editor_name'.tr(),
            required: true,
          ),
        ),
      ],
    );
  }

  Widget _buildClientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.client'.tr()),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 500;
            final fields = [
              _field(
                controller: _clientNameCtrl,
                label: 'offer.client_name'.tr(),
                required: true,
              ),
              _field(
                controller: _clientContactCtrl,
                label: 'offer.client_contact'.tr(),
                hint: 'offer.client_contact_hint'.tr(),
              ),
            ];
            return wide
                ? Row(
                    children: fields
                        .map((f) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: f,
                              ),
                            ))
                        .toList(),
                  )
                : Column(children: fields);
          },
        ),
      ],
    );
  }

  Widget _buildEventTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.event_type'.tr()),
        const SizedBox(height: 8),
        EventTypeSelector(
          selectedTypes: _eventTypes,
          onChanged: (newTypes) => setState(() {
            _eventTypes.clear();
            _eventTypes.addAll(newTypes);
          }),
        ),
      ],
    );
  }

  Widget _buildGuestCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.guest_count'.tr()),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final fields = [
              SizedBox(
                width: 200,
                child: _field(
                  controller: _guestCountCtrl,
                  label: 'offer.guest_count'.tr(),
                  keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  required: true,
                ),
              ),
              SizedBox(
                width: 200,
                child: _field(
                  controller: _eventTimeCtrl,
                  label: 'offer.event_time'.tr(),
                  hint: '17:30',
                ),
              ),
              SizedBox(
                width: 200,
                child: _buildDatePicker(),
              ),
            ];
            return wide
                ? Row(
                    children: fields
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: f,
                            ))
                        .toList(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: fields
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: f,
                            ))
                        .toList(),
                  );
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _eventDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() => _eventDate = picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'offer.event_date'.tr(),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          '${_eventDate.day.toString().padLeft(2, '0')}.${_eventDate.month.toString().padLeft(2, '0')}.${_eventDate.year}',
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.services'.tr()),
        const SizedBox(height: 8),
        _field(
          controller: _cocktailsCtrl,
          label: 'offer.cocktails'.tr(),
          hint: 'offer.cocktails_hint'.tr(),
        ),
        const SizedBox(height: 8),
        _field(
          controller: _barDescCtrl,
          label: 'offer.bar_description'.tr(),
          hint: 'offer.bar_description_hint'.tr(),
        ),
        const SizedBox(height: 8),
        _field(
          controller: _shotsCtrl,
          label: 'offer.shots'.tr(),
          hint: 'offer.shots_hint'.tr(),
        ),
      ],
    );
  }

  Widget _buildPricingSection(Currency curr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.pricing'.tr()),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 500;
            final row1 = [
              _field(
                controller: _orderTotalCtrl,
                label: '${'offer.order_total'.tr()} (${widget.order.currency})',
                keyboard: TextInputType.number,
                required: true,
              ),
              _field(
                controller: _distanceKmCtrl,
                label: 'offer.distance_km'.tr(),
                hint: '150',
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ];
            final row2 = [
              _field(
                controller: _travelCostPerKmCtrl,
                label:
                    '${'offer.travel_cost_per_km'.tr()} (${widget.order.currency})',
                keyboard: TextInputType.number,
              ),
              _field(
                controller: _barCostCtrl,
                label: '${'offer.bar_cost'.tr()} (${widget.order.currency})',
                hint: '0',
                keyboard: TextInputType.number,
              ),
            ];
            if (wide) {
              return Column(
                children: [
                  Row(
                    children: row1
                        .map((f) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: f,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: row2
                        .map((f) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: f,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              );
            }
            return Column(
              children: [...row1, ...row2]
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: f,
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          child: _field(
            controller: _discountCtrl,
            label: '${'offer.discount'.tr()} (${widget.order.currency})',
            hint: '0',
            keyboard: TextInputType.number,
          ),
        ),
        const SizedBox(height: 16),
        // Extra positions section
        _buildExtraPositionsSection(curr),
        const SizedBox(height: 12),
        OfferPricePreview(
          currency: curr,
          orderTotal: double.tryParse(_orderTotalCtrl.text.trim()) ?? 0,
          distanceKm: int.tryParse(_distanceKmCtrl.text.trim()) ?? 0,
          travelCostPerKm:
              double.tryParse(_travelCostPerKmCtrl.text.trim()) ?? 0.70,
          barCost: double.tryParse(_barCostCtrl.text.trim()) ?? 0,
          discount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
          extraPositionsTotal: _extraPositions.fold(0.0, (sum, p) => sum + p.price),
        ),
      ],
    );
  }

  Widget _buildExtraPositionsSection(Currency curr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle_outline, 
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'offer.extra_positions'.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _showAddExtraPositionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('offer.add_position'.tr()),
                ),
              ],
            ),
            if (_extraPositions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._extraPositions.asMap().entries.map((entry) {
                final index = entry.key;
                final pos = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pos.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            if (pos.remark.isNotEmpty)
                              Text(
                                pos.remark,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        curr.format(pos.price),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditExtraPositionDialog(index),
                        tooltip: 'common.edit'.tr(),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 18, 
                            color: Theme.of(context).colorScheme.error),
                        onPressed: () => setState(() => _extraPositions.removeAt(index)),
                        tooltip: 'common.delete'.tr(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAddExtraPositionDialog() async {
    final result = await _showExtraPositionDialog();
    if (result != null) {
      setState(() => _extraPositions.add(result));
    }
  }

  Future<void> _showEditExtraPositionDialog(int index) async {
    final result = await _showExtraPositionDialog(existing: _extraPositions[index]);
    if (result != null) {
      setState(() => _extraPositions[index] = result);
    }
  }

  Future<ExtraPosition?> _showExtraPositionDialog({ExtraPosition? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final remarkCtrl = TextEditingController(text: existing?.remark ?? '');
    final formKey = GlobalKey<FormState>();

    return showDialog<ExtraPosition>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'offer.add_position'.tr() : 'offer.edit_position'.tr()),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'offer.position_name'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'offer.field_required'.tr()
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${'offer.position_price'.tr()} (${widget.order.currency})',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'offer.field_required'.tr();
                    if (double.tryParse(v.trim()) == null) return 'offer.invalid_number'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: remarkCtrl,
                  decoration: InputDecoration(
                    labelText: 'offer.position_remark'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ExtraPosition(
                  name: nameCtrl.text.trim(),
                  price: double.parse(priceCtrl.text.trim()),
                  remark: remarkCtrl.text.trim(),
                ));
              }
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.additional_info'.tr()),
        const SizedBox(height: 8),
        TextFormField(
          controller: _additionalInfoCtrl,
          maxLines: 8,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'offer.additional_info'.tr(),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
              ? 'offer.field_required'.tr()
              : null
          : null,
      onChanged: (_) => setState(() {}),
    );
  }
}
