import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../data/employee_repository.dart';
import '../../data/order_repository.dart';
import '../../models/employee.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../services/invoice_pdf_generator.dart';
import '../../services/microsoft_graph_service.dart';
import '../../utils/currency.dart';
import '../offer/widgets/event_type_selector.dart';
import '../offer/widgets/section_header.dart';

/// Screen to create and export an Invoice (Auftragsbestätigung) from a [SavedOrder].
/// Similar to CreateOfferScreen but for invoices, with position validation.
class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key, required this.order});

  final SavedOrder order;

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Language
  String _language = 'de';

  // Event date (editable)
  late DateTime _eventDate;

  // Controllers
  final _editorNameCtrl = TextEditingController(text: 'Mario Kantharoobarajah');
  final _eventTimeCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientContactCtrl = TextEditingController();
  late final TextEditingController _guestCountCtrl;
  final _cocktailsCtrl = TextEditingController();
  final _barDescCtrl = TextEditingController();
  final _shotsCtrl = TextEditingController();
  
  // Position controllers
  late final TextEditingController _barServiceCostCtrl;
  final _distanceKmCtrl = TextEditingController();
  final _travelCostPerKmCtrl = TextEditingController(text: '0.70');
  late final TextEditingController _thekeCostCtrl;
  late final TextEditingController _shotsCountCtrl;
  final _shotsPricePerPieceCtrl = TextEditingController(text: '1.50');
  final _shotsRemarkCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  // Extra hours (Extrastunden)
  late final TextEditingController _extraHoursCtrl;
  final _extraHourRateCtrl = TextEditingController(text: '50.00');

  // Assigned employees
  late Set<String> _selectedEmployees;

  // Event types
  final Set<EventType> _eventTypes = {};

  // Extra positions
  final List<ExtraPosition> _extraPositions = [];

  bool _isGenerating = false;
  String? _totalValidationError;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _eventDate = widget.order.date;
    _guestCountCtrl = TextEditingController(text: widget.order.personCount.toString());

    // Calculate initial bar service cost
    final travelTotal = widget.order.distanceKm * 2 * 0.70;
    final barServiceCost = widget.order.total - travelTotal - widget.order.thekeCost;
    _barServiceCostCtrl = TextEditingController(text: barServiceCost.toStringAsFixed(2));

    // Pre-fill from order data
    _cocktailsCtrl.text = widget.order.cocktails.join(', ');
    _shotsCtrl.text = widget.order.shots.join(', ');
    _barDescCtrl.text = widget.order.bar;
    _distanceKmCtrl.text = widget.order.distanceKm > 0 ? widget.order.distanceKm.toString() : '';
    _thekeCostCtrl = TextEditingController(
      text: widget.order.thekeCost > 0 ? widget.order.thekeCost.toStringAsFixed(2) : '',
    );

    // Shots position - use saved values or calculate from personCount
    final shotsCount = widget.order.offerShotsCount > 0 
        ? widget.order.offerShotsCount 
        : (widget.order.shots.isNotEmpty ? widget.order.personCount ~/ 5 : 0);
    _shotsCountCtrl = TextEditingController(
      text: shotsCount > 0 ? shotsCount.toString() : '',
    );
    _shotsPricePerPieceCtrl.text = widget.order.offerShotsPricePerPiece.toStringAsFixed(2);
    
    // Shots remark - use saved value or generate default from shot names
    if (widget.order.offerShotsRemark.isNotEmpty) {
      _shotsRemarkCtrl.text = widget.order.offerShotsRemark;
    } else if (widget.order.shots.isNotEmpty) {
      _shotsRemarkCtrl.text = 'Shots – ${widget.order.shots.join(", ")}\nAusgeschenkt in 0.4 CL Shotbechern';
    }

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

    // Load extra hours
    _extraHoursCtrl = TextEditingController(
      text: widget.order.offerExtraHours > 0 ? widget.order.offerExtraHours.toString() : '',
    );
    _extraHourRateCtrl.text = widget.order.offerExtraHourRate.toStringAsFixed(2);

    // Load assigned employees
    _selectedEmployees = Set.from(widget.order.assignedEmployees);
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
    _barServiceCostCtrl.dispose();
    _distanceKmCtrl.dispose();
    _travelCostPerKmCtrl.dispose();
    _thekeCostCtrl.dispose();
    _shotsCountCtrl.dispose();
    _shotsPricePerPieceCtrl.dispose();
    _shotsRemarkCtrl.dispose();
    _discountCtrl.dispose();
    _extraHoursCtrl.dispose();
    _extraHourRateCtrl.dispose();
    super.dispose();
  }

  void _onLanguageChanged(String lang) {
    setState(() => _language = lang);
  }

  double get _barServiceCost => double.tryParse(_barServiceCostCtrl.text.trim()) ?? 0;
  int get _distanceKm => int.tryParse(_distanceKmCtrl.text.trim()) ?? 0;
  double get _travelCostPerKm => double.tryParse(_travelCostPerKmCtrl.text.trim()) ?? 0.70;
  double get _travelCostTotal => _distanceKm * 2 * _travelCostPerKm;
  double get _thekeCost => double.tryParse(_thekeCostCtrl.text.trim()) ?? 0;
  int get _shotsCount => int.tryParse(_shotsCountCtrl.text.trim()) ?? 0;
  double get _shotsPricePerPiece => double.tryParse(_shotsPricePerPieceCtrl.text.trim()) ?? 1.50;
  double get _shotsCostTotal => _shotsCount * _shotsPricePerPiece;
  double get _discount => double.tryParse(_discountCtrl.text.trim()) ?? 0;
  double get _extraPositionsTotal => _extraPositions.fold(0.0, (sum, p) => sum + p.total);
  
  // Extra hours calculation: employees × hours × rate  
  int get _extraHours => int.tryParse(_extraHoursCtrl.text.trim()) ?? 0;
  double get _extraHourRate => double.tryParse(_extraHourRateCtrl.text.trim()) ?? 50.0;
  double get _extraHoursTotal => _selectedEmployees.length * _extraHours * _extraHourRate;

  /// Sum of all positions (without discount)
  double get _positionsSum => _barServiceCost + _travelCostTotal + _thekeCost + _shotsCostTotal + _extraHoursTotal + _extraPositionsTotal;

  /// Grand total after discount
  double get _grandTotal => _positionsSum - _discount;

  /// Validates that employees are assigned
  bool _validateEmployees() {
    if (_selectedEmployees.isEmpty) {
      setState(() {
        _employeeValidationError = 'invoice.employees_required'.tr();
      });
      return false;
    }
    _employeeValidationError = null;
    return true;
  }

  String? _employeeValidationError;

  /// Validates that total is not less than sum of positions (before discount)
  bool _validateTotal() {
    // The grand total should be at least the sum of positions minus discount
    // But discount cannot make total negative
    if (_grandTotal < 0) {
      setState(() {
        _totalValidationError = 'invoice.total_cannot_be_negative'.tr();
      });
      return false;
    }
    _totalValidationError = null;
    return true;
  }

  /// Validate all fields
  bool _validateAll() {
    final employeesValid = _validateEmployees();
    final totalValid = _validateTotal();
    return employeesValid && totalValid;
  }

  /// Get the first validation error message
  String? get _validationError => _employeeValidationError ?? _totalValidationError;

  /// Build updated order with invoice data
  SavedOrder _buildUpdatedOrder() {
    // Calculate new total from positions (without shots - they are separate)
    final newTotal = _barServiceCost + _travelCostTotal + _thekeCost;
    
    return SavedOrder(
      id: widget.order.id,
      name: widget.order.name,
      date: _eventDate,
      items: widget.order.items,
      total: newTotal,
      personCount: int.tryParse(_guestCountCtrl.text.trim()) ?? widget.order.personCount,
      drinkerType: widget.order.drinkerType,
      currency: widget.order.currency,
      status: widget.order.status,
      createdBy: widget.order.createdBy,
      createdAt: widget.order.createdAt,
      cocktails: _cocktailsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      shots: _shotsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      bar: _barDescCtrl.text.trim(),
      distanceKm: _distanceKm,
      thekeCost: _thekeCost,
      offerClientName: _clientNameCtrl.text.trim(),
      offerClientContact: _clientContactCtrl.text.trim(),
      offerEventTime: _eventTimeCtrl.text.trim(),
      offerEventTypes: _eventTypes.map((e) => e.name).toList(),
      offerDiscount: _discount,
      offerLanguage: _language,
      offerExtraPositions: _extraPositions.map((e) => e.toJson()).toList(),
      offerShotsCount: _shotsCount,
      offerShotsPricePerPiece: _shotsPricePerPiece,
      offerShotsRemark: _shotsRemarkCtrl.text.trim(),
      offerExtraHours: _extraHours,
      offerExtraHourRate: _extraHourRate,
      assignedEmployees: _selectedEmployees.toList(),
      source: widget.order.source,
      hasShoppingList: widget.order.hasShoppingList,
      formSubmissionId: widget.order.formSubmissionId,
      formCreatedAt: widget.order.formCreatedAt,
      phone: widget.order.phone,
      location: widget.order.location,
      guestCountRange: widget.order.guestCountRange,
      mobileBar: widget.order.mobileBar,
      eventType: widget.order.eventType,
      serviceType: widget.order.serviceType,
      requestedCocktails: widget.order.requestedCocktails,
    );
  }

  Future<void> _saveInvoiceData() async {
    await orderRepository.updateOfferData(
      orderId: widget.order.id,
      clientName: _clientNameCtrl.text.trim(),
      clientContact: _clientContactCtrl.text.trim(),
      eventTime: _eventTimeCtrl.text.trim(),
      eventTypes: _eventTypes.map((e) => e.name).toList(),
      discount: _discount,
      language: _language,
      eventDate: _eventDate,
      extraPositions: _extraPositions.map((e) => e.toJson()).toList(),
      shotsCount: _shotsCount,
      shotsPricePerPiece: _shotsPricePerPiece,
      shotsRemark: _shotsRemarkCtrl.text.trim(),
      extraHours: _extraHours,
      extraHourRate: _extraHourRate,
      assignedEmployees: _selectedEmployees.toList(),
    );

    // Also update the order totals
    await orderRepository.updateOrderTotals(
      orderId: widget.order.id,
      total: _barServiceCost + _travelCostTotal + _thekeCost,
      distanceKm: _distanceKm,
      thekeCost: _thekeCost,
    );
  }

  Future<void> _saveOnly() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateAll()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_validationError ?? 'common.error'.tr())),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      await _saveInvoiceData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('invoice.saved'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _previewPdf() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateAll()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_validationError ?? 'common.error'.tr())),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      await _saveInvoiceData();
      final updatedOrder = _buildUpdatedOrder();
      final pdfBytes = await InvoicePdfGenerator.generateBytes(updatedOrder, language: _language);
      if (mounted) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generatePdf() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateAll()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_validationError ?? 'common.error'.tr())),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      await _saveInvoiceData();
      final updatedOrder = _buildUpdatedOrder();
      final pdfBytes = await InvoicePdfGenerator.generateBytes(updatedOrder, language: _language);
      
      // Upload to OneDrive if supported
      final fileName = InvoicePdfGenerator.getFilename(updatedOrder);
      if (microsoftGraphService.isSupported) {
        final oneDrivePath = MicrosoftGraphService.buildOneDrivePath(
          rootFolder: 'Aufträge',
          date: updatedOrder.date,
          fileName: fileName,
        );
        await microsoftGraphService.uploadToOneDrive(
          oneDrivePath: oneDrivePath,
          bytes: pdfBytes,
        );
      }
      
      // Share/download the PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('invoice.pdf_created'.tr())),
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
        title: Text('invoice.title'.tr()),
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
                  _buildEventDetailsSection(),
                  const SizedBox(height: 20),
                  _buildServicesSection(),
                  const SizedBox(height: 20),
                  _buildPositionsSection(curr),
                  const SizedBox(height: 20),
                  _buildPricePreview(curr),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
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
        SectionHeader(label: 'invoice.editor'.tr()),
        const SizedBox(height: 8),
        SizedBox(
          width: 400,
          child: _field(
            controller: _editorNameCtrl,
            label: 'invoice.editor_name'.tr(),
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
        SectionHeader(label: 'invoice.client'.tr()),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 500;
            final fields = [
              _field(
                controller: _clientNameCtrl,
                label: 'invoice.client_name'.tr(),
                required: true,
              ),
              _field(
                controller: _clientContactCtrl,
                label: 'invoice.client_contact'.tr(),
                hint: 'invoice.client_contact_hint'.tr(),
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
        SectionHeader(label: 'invoice.event_type'.tr()),
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

  Widget _buildEventDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'invoice.event_details'.tr()),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final fields = [
              SizedBox(
                width: 200,
                child: _field(
                  controller: _guestCountCtrl,
                  label: 'invoice.guest_count'.tr(),
                  keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  required: true,
                ),
              ),
              SizedBox(
                width: 200,
                child: _field(
                  controller: _eventTimeCtrl,
                  label: 'invoice.event_time'.tr(),
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
          labelText: 'invoice.event_date'.tr(),
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
        SectionHeader(label: 'invoice.services'.tr()),
        const SizedBox(height: 8),
        _field(
          controller: _cocktailsCtrl,
          label: 'invoice.cocktails'.tr(),
          hint: 'invoice.cocktails_hint'.tr(),
        ),
        const SizedBox(height: 8),
        _field(
          controller: _barDescCtrl,
          label: 'invoice.bar_description'.tr(),
          hint: 'invoice.bar_description_hint'.tr(),
        ),
        const SizedBox(height: 8),
        _field(
          controller: _shotsCtrl,
          label: 'invoice.shots'.tr(),
          hint: 'invoice.shots_hint'.tr(),
        ),
      ],
    );
  }

  Widget _buildPositionsSection(Currency curr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'invoice.positions'.tr()),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bar Service Cost
                _field(
                  controller: _barServiceCostCtrl,
                  label: '${'invoice.bar_service_cost'.tr()} (${widget.order.currency})',
                  keyboard: TextInputType.number,
                  required: true,
                ),
                const SizedBox(height: 12),
                
                // Travel costs
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 500;
                    final fields = [
                      _field(
                        controller: _distanceKmCtrl,
                        label: 'invoice.distance_km'.tr(),
                        hint: '150',
                        keyboard: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      _field(
                        controller: _travelCostPerKmCtrl,
                        label: '${'invoice.travel_cost_per_km'.tr()} (${widget.order.currency})',
                        keyboard: TextInputType.number,
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
                        : Column(
                            children: fields.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: f,
                            )).toList(),
                          );
                  },
                ),
                const SizedBox(height: 12),
                
                // Theke cost
                SizedBox(
                  width: 250,
                  child: _field(
                    controller: _thekeCostCtrl,
                    label: '${'invoice.theke_cost'.tr()} (${widget.order.currency})',
                    hint: '0',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Shots position (only if shots are listed)
                if (_shotsCtrl.text.trim().isNotEmpty) ...[
                  Text(
                    'invoice.shots_position'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 500;
                      final fields = [
                        _field(
                          controller: _shotsCountCtrl,
                          label: 'invoice.shots_count'.tr(),
                          hint: '60',
                          keyboard: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        _field(
                          controller: _shotsPricePerPieceCtrl,
                          label: '${'invoice.shots_price_per_piece'.tr()} (${widget.order.currency})',
                          hint: '1.50',
                          keyboard: TextInputType.number,
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
                          : Column(
                              children: fields.map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: f,
                              )).toList(),
                            );
                    },
                  ),
                  const SizedBox(height: 8),
                  _field(
                    controller: _shotsRemarkCtrl,
                    label: 'invoice.shots_remark'.tr(),
                    hint: 'Shots – Aarewasser, Erdbeer Lime\nAusgeschenkt in 0.4 CL Shotbechern',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Discount
                SizedBox(
                  width: 250,
                  child: _field(
                    controller: _discountCtrl,
                    label: '${'invoice.discount'.tr()} (${widget.order.currency})',
                    hint: '0',
                    keyboard: TextInputType.number,
                  ),
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Extrastunden (Extra hours)
                _buildExtraHoursSection(),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Extra positions
                _buildExtraPositionsSection(curr),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build extra hours section with employee selection
  Widget _buildExtraHoursSection() {
    return StreamBuilder<List<Employee>>(
      stream: employeeRepository.watchEmployees(),
      builder: (context, snapshot) {
        final employees = snapshot.data ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.access_time, 
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'invoice.extra_hours_section'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Employee selection
            Text(
              'invoice.select_employees'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            if (employees.isEmpty)
              Text(
                'orders.no_employees_available'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: employees.map((employee) {
                  final isSelected = _selectedEmployees.contains(employee.name);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(employee.name),
                    avatar: CircleAvatar(
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      child: Text(
                        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedEmployees.add(employee.name);
                        } else {
                          _selectedEmployees.remove(employee.name);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            
            // Extra hours inputs
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 500;
                final fields = [
                  _field(
                    controller: _extraHoursCtrl,
                    label: 'invoice.extra_hours'.tr(),
                    hint: '0',
                    keyboard: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  _field(
                    controller: _extraHourRateCtrl,
                    label: '${'invoice.extra_hour_rate'.tr()} (${widget.order.currency})',
                    hint: '50.00',
                    keyboard: TextInputType.number,
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
                    : Column(
                        children: fields.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: f,
                        )).toList(),
                      );
              },
            ),
            
            // Show calculation if employees selected and hours > 0
            if (_selectedEmployees.isNotEmpty && _extraHours > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedEmployees.length} ${'invoice.employees'.tr()} × ${_extraHours}h × ${Currency.fromCode(widget.order.currency).format(_extraHourRate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '= ${Currency.fromCode(widget.order.currency).format(_extraHoursTotal)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Error message for missing employees
            if (_employeeValidationError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.error_outline, 
                      size: 16, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    _employeeValidationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildExtraPositionsSection(Currency curr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.add_circle_outline, 
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'invoice.extra_positions'.tr(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: _showAddExtraPositionDialog,
              icon: const Icon(Icons.add, size: 18),
              label: Text('invoice.add_position'.tr()),
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
                        Text(
                          pos.quantity > 1 ? '${pos.quantity}x ${pos.name}' : pos.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
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
                    pos.quantity > 1 
                        ? '${pos.quantity} × ${curr.format(pos.price)} = ${curr.format(pos.total)}'
                        : curr.format(pos.price),
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
    final quantityCtrl = TextEditingController(
      text: existing != null ? existing.quantity.toString() : '1',
    );
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final remarkCtrl = TextEditingController(text: existing?.remark ?? '');
    final formKey = GlobalKey<FormState>();

    return showDialog<ExtraPosition>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'invoice.add_position'.tr() : 'invoice.edit_position'.tr()),
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
                    labelText: 'invoice.position_name'.tr(),
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'invoice.field_required'.tr()
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: quantityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'invoice.position_quantity'.tr(),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'invoice.field_required'.tr();
                    if (int.tryParse(v.trim()) == null || int.parse(v.trim()) < 1) {
                      return 'invoice.invalid_number'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${'invoice.position_price'.tr()} (${widget.order.currency})',
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'invoice.field_required'.tr();
                    if (double.tryParse(v.trim()) == null) return 'invoice.invalid_number'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: remarkCtrl,
                  decoration: InputDecoration(
                    labelText: 'invoice.position_remark'.tr(),
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
                  quantity: int.parse(quantityCtrl.text.trim()),
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

  Widget _buildPricePreview(Currency curr) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'invoice.price_preview'.tr(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _PreviewRow(
              label: 'invoice.bar_service_cost'.tr(),
              value: curr.format(_barServiceCost),
            ),
            if (_distanceKm > 0)
              _PreviewRow(
                label: 'invoice.travel_cost'.tr(),
                value: '${_distanceKm * 2} km × ${curr.format(_travelCostPerKm)} = ${curr.format(_travelCostTotal)}',
              ),
            if (_thekeCost > 0)
              _PreviewRow(
                label: 'invoice.theke_cost'.tr(),
                value: curr.format(_thekeCost),
              ),
            if (_shotsCount > 0)
              _PreviewRow(
                label: 'Shots',
                value: '$_shotsCount × ${curr.format(_shotsPricePerPiece)} = ${curr.format(_shotsCostTotal)}',
              ),
            if (_extraHoursTotal > 0)
              _PreviewRow(
                label: 'invoice.extra_hours_label'.tr(),
                value: '${_selectedEmployees.length} × ${_extraHours}h × ${curr.format(_extraHourRate)} = ${curr.format(_extraHoursTotal)}',
              ),
            if (_extraPositionsTotal > 0)
              _PreviewRow(
                label: 'invoice.extra_positions'.tr(),
                value: curr.format(_extraPositionsTotal),
              ),
            const Divider(),
            _PreviewRow(
              label: 'invoice.positions_sum'.tr(),
              value: curr.format(_positionsSum),
              bold: true,
            ),
            if (_discount > 0)
              _PreviewRow(
                label: 'invoice.discount'.tr(),
                value: '-${curr.format(_discount)}',
              ),
            const Divider(),
            _PreviewRow(
              label: 'invoice.grand_total'.tr(),
              value: curr.format(_grandTotal),
              bold: true,
              highlight: true,
            ),
            if (_totalValidationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _totalValidationError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _isGenerating ? null : _saveOnly,
          icon: const Icon(Icons.save_outlined),
          label: Text('invoice.save'.tr()),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _isGenerating ? null : _previewPdf,
          icon: const Icon(Icons.visibility),
          label: Text('invoice.preview'.tr()),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _isGenerating ? null : _generatePdf,
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf),
          label: Text('invoice.generate_pdf'.tr()),
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
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty)
              ? 'invoice.field_required'.tr()
              : null
          : null,
      onChanged: (_) => setState(() {}),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
