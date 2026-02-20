import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cocktail_repository.dart';
import '../models/offer.dart';
import '../models/order.dart';
import '../services/offer_pdf_generator.dart';
import '../utils/currency.dart';

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

  // Bearbeiter
  final _editorNameCtrl =
      TextEditingController(text: 'Mario Kantharoobarajah');
  final _eventTimeCtrl = TextEditingController();

  // Auftraggeber
  final _clientNameCtrl = TextEditingController();
  final _clientContactCtrl = TextEditingController();

  // Event
  final Set<EventType> _eventTypes = {};
  late final TextEditingController _guestCountCtrl;

  // Cocktails / Bar / Shots
  final _cocktailsCtrl = TextEditingController();
  final _barDescCtrl = TextEditingController();
  final _shotsCtrl = TextEditingController();

  // Pricing (orderTotal from order, already includes travel & theke)
  late final TextEditingController _orderTotalCtrl;
  final _distanceKmCtrl = TextEditingController();
  final _travelCostPerKmCtrl = TextEditingController(text: '0.70');
  final _barCostCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  // Additional info
  late final TextEditingController _additionalInfoCtrl;

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _guestCountCtrl =
        TextEditingController(text: widget.order.personCount.toString());
    _orderTotalCtrl =
        TextEditingController(text: widget.order.total.toStringAsFixed(2));
    
    // Pre-fill from order data
    _cocktailsCtrl.text = widget.order.cocktails.join(', ');
    _shotsCtrl.text = widget.order.shots.join(', ');
    _barDescCtrl.text = widget.order.bar;
    _distanceKmCtrl.text = widget.order.distanceKm > 0 
        ? widget.order.distanceKm.toString() 
        : '';
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
      eventDate: widget.order.date,
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
    );
  }

  Future<void> _generatePdf() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isGenerating = true);
    try {
      // Save offer data to order first
      await cocktailRepository.updateOrderOfferData(
        orderId: widget.order.id,
        clientName: _clientNameCtrl.text.trim(),
        clientContact: _clientContactCtrl.text.trim(),
        eventTime: _eventTimeCtrl.text.trim(),
        eventTypes: _eventTypes.map((e) => e.name).toList(),
        discount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
        language: _language,
      );
      
      final offer = _buildOfferData();
      await OfferPdfGenerator.generateAndDownload(offer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('offer.pdf_created'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final curr = Currency.fromCode(widget.order.currency);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('offer.title'.tr()),
        actions: [
          // Language switch
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
                  // Order info banner
                  Card(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(widget.order.name),
                      subtitle: Text(
                        '${widget.order.date.day.toString().padLeft(2, '0')}.${widget.order.date.month.toString().padLeft(2, '0')}.${widget.order.date.year}'
                        ' • ${curr.format(widget.order.total)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Bearbeiter ────────────────────────────────────────────
                  _SectionHeader(label: 'offer.editor'.tr()),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 400,
                    child: _field(
                      controller: _editorNameCtrl,
                      label: 'offer.editor_name'.tr(),
                      required: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Auftraggeber ──────────────────────────────────────────
                  _SectionHeader(label: 'offer.client'.tr()),
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
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: f,
                                        ),
                                      ))
                                  .toList(),
                            )
                          : Column(children: fields);
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Anlass ────────────────────────────────────────────────
                  _SectionHeader(label: 'offer.event_type'.tr()),
                  const SizedBox(height: 8),
                  _buildEventTypeSelector(),
                  const SizedBox(height: 20),

                  // ── Gästeanzahl ───────────────────────────────────────────
                  _SectionHeader(label: 'offer.guest_count'.tr()),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 500;
                      final fields = [
                        SizedBox(
                          width: 200,
                          child: _field(
                            controller: _guestCountCtrl,
                            label: 'offer.guest_count'.tr(),
                            keyboard: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
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
                      ];
                      return wide
                          ? Row(
                              children: fields
                                  .map((f) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 16),
                                        child: f,
                                      ))
                                  .toList(),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: fields
                                  .map((f) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: f,
                                      ))
                                  .toList(),
                            );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Cocktails / Bar / Shots ───────────────────────────────
                  _SectionHeader(label: 'offer.services'.tr()),
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
                  const SizedBox(height: 20),

                  // ── Pricing ───────────────────────────────────────────────
                  _SectionHeader(label: 'offer.pricing'.tr()),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 500;
                      final row1 = [
                        _field(
                          controller: _orderTotalCtrl,
                          label:
                              '${'offer.order_total'.tr()} (${widget.order.currency})',
                          keyboard: TextInputType.number,
                          required: true,
                        ),
                        _field(
                          controller: _distanceKmCtrl,
                          label: 'offer.distance_km'.tr(),
                          hint: '150',
                          keyboard: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
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
                          label:
                              '${'offer.bar_cost'.tr()} (${widget.order.currency})',
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
                                          padding:
                                              const EdgeInsets.only(right: 8),
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
                                          padding:
                                              const EdgeInsets.only(right: 8),
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
                              .toList());
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 200,
                    child: _field(
                      controller: _discountCtrl,
                      label:
                          '${'offer.discount'.tr()} (${widget.order.currency})',
                      hint: '0',
                      keyboard: TextInputType.number,
                    ),
                  ),

                  // Live price preview
                  const SizedBox(height: 12),
                  _buildPricePreview(curr),
                  const SizedBox(height: 20),

                  // ── Zusatzinformation ─────────────────────────────────────
                  _SectionHeader(label: 'offer.additional_info'.tr()),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _additionalInfoCtrl,
                    maxLines: 8,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'offer.additional_info'.tr(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Generate PDF ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isGenerating ? null : _generatePdf,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text('offer.generate_pdf'.tr()),
                    ),
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

  Widget _buildEventTypeSelector() {
    final types = [
      (EventType.birthday, 'offer.event_birthday'.tr()),
      (EventType.wedding, 'offer.event_wedding'.tr()),
      (EventType.company, 'offer.event_company'.tr()),
      (EventType.babyshower, 'offer.event_babyshower'.tr()),
      (EventType.other, 'offer.event_other'.tr()),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: types.map((t) {
        final selected = _eventTypes.contains(t.$1);
        return FilterChip(
          label: Text(t.$2),
          selected: selected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _eventTypes.add(t.$1);
              } else {
                _eventTypes.remove(t.$1);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildPricePreview(Currency curr) {
    final orderTotal =
        double.tryParse(_orderTotalCtrl.text.trim()) ?? 0;
    final km = int.tryParse(_distanceKmCtrl.text.trim()) ?? 0;
    final perKm =
        double.tryParse(_travelCostPerKmCtrl.text.trim()) ?? 0.70;
    final barCost = double.tryParse(_barCostCtrl.text.trim()) ?? 0;
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final travel = km * 2 * perKm;
    // barServiceCost is orderTotal minus travel and theke (already included)
    final barService = orderTotal - travel - barCost;
    final total = orderTotal - discount;

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'offer.price_preview'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _previewRow('offer.bar_service_cost'.tr(), curr.format(barService)),
            if (km > 0)
              _previewRow('offer.travel_cost'.tr(),
                  '${km * 2} km × ${curr.format(perKm)} = ${curr.format(travel)}'),
            if (barCost > 0)
              _previewRow('offer.bar_cost'.tr(), curr.format(barCost)),
            if (discount > 0)
              _previewRow('offer.discount'.tr(), '-${curr.format(discount)}'),
            const Divider(),
            _previewRow('offer.total'.tr(), curr.format(total), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null),
          Text(value,
              style: bold
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null),
        ],
      ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
