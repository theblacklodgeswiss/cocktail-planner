import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../config/env_config.dart';
import '../../data/order_repository.dart';
import '../../data/employee_repository.dart';
import '../../models/offer.dart';
import '../../models/employee.dart';
import '../../models/order.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/offer_pdf_generator.dart';
import '../../utils/currency.dart';
import '../../utils/order_option_labels.dart';
import 'widgets/event_type_selector.dart';
import 'widgets/offer_action_buttons.dart';
import 'widgets/offer_price_preview.dart';
import 'widgets/offer_share_dialog.dart';
import 'widgets/section_header.dart';

/// Screen to create and export an Offer (Angebot) from a [SavedOrder].
class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({super.key, required this.order});

  final SavedOrder order;

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
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

  final _formKey = GlobalKey<FormState>();

  // Language
  String _language = 'de';
  late Currency _currency;

  // Event date (editable)
  late DateTime _eventDate;
  late String _serviceType;

  // Controllers
  late final _editorNameCtrl = TextEditingController(text: 'Inthusan Gunasiri');
  final _eventTimeCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientContactCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  late final TextEditingController _guestCountCtrl;
  final _cocktailsCtrl = TextEditingController();
  final _barDescCtrl = TextEditingController();
  final _shotsCtrl = TextEditingController();
  late final TextEditingController _orderTotalCtrl;
  final _distanceKmCtrl = TextEditingController();
  final _travelCostPerKmCtrl = TextEditingController(text: '0.70');
  final _barCostCtrl = TextEditingController();
  late final TextEditingController _firstPositionTextCtrl;
  late final TextEditingController _firstPositionRemarkCtrl;
  late final TextEditingController _additionalInfoCtrl;

  // Event types
  final Set<EventType> _eventTypes = {};

  // Assigned employees (names)
  late Set<String> _selectedEmployees;

  // Offer positions (all positions: standard + custom)
  // Replaces the old _extraPositions — these are saved as offerPositions in Firebase.
  final List<ExtraPosition> _offerPositions = [];

  bool _isGenerating = false;
  bool _showValidationErrors = false;
  bool _savedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _eventDate = widget.order.date;
    _currency = Currency.fromCode(widget.order.currency);
    _guestCountCtrl = TextEditingController(
      text: widget.order.personCount.toString(),
    );
    _orderTotalCtrl = TextEditingController(
      text: widget.order.total.toStringAsFixed(2),
    );

    // Pre-fill from order data
    // For form orders, cocktails may be in requestedCocktails (not yet in cocktails)
    final cocktailSource = widget.order.cocktails.isNotEmpty
        ? widget.order.cocktails
        : widget.order.requestedCocktails;
    _cocktailsCtrl.text = cocktailSource.join(', ');
    _shotsCtrl.text = widget.order.shots.join(', ');
    _barDescCtrl.text = widget.order.bar;
    _distanceKmCtrl.text = widget.order.distanceKm > 0
        ? widget.order.distanceKm.toString()
        : '';
    _travelCostPerKmCtrl.text = widget.order.offerTravelCostPerKm > 0
        ? widget.order.offerTravelCostPerKm.toStringAsFixed(2)
        : '0.70';
    _barCostCtrl.text = widget.order.offerBarCost > 0
        ? widget.order.offerBarCost.toStringAsFixed(2)
        : (widget.order.thekeCost > 0
              ? widget.order.thekeCost.toStringAsFixed(2)
              : '');

    // Load saved offer data from order, or use order name/phone/time as fallback
    _clientNameCtrl.text = widget.order.offerClientName.isEmpty
        ? widget.order.name
        : widget.order.offerClientName;
    _clientContactCtrl.text = widget.order.offerClientContact.isEmpty
        ? widget.order.phone
        : widget.order.offerClientContact;
    _locationCtrl.text = widget.order.location;
    _eventTimeCtrl.text = widget.order.offerEventTime.isEmpty
        ? widget.order.eventTime
        : widget.order.offerEventTime;
    _language = widget.order.offerLanguage;

    // Load event types
    for (final typeStr in widget.order.offerEventTypes) {
      final type = EventType.values.where((e) => e.name == typeStr).firstOrNull;
      if (type != null) _eventTypes.add(type);
    }

    // Load assigned employees from order
    _selectedEmployees = Set.from(widget.order.assignedEmployees);

    // Set service type
    _serviceType = _normalizeServiceType(
      widget.order.serviceType.isNotEmpty
          ? widget.order.serviceType
          : 'cocktail_barservice',
    );

    _firstPositionTextCtrl = TextEditingController(
      text: widget.order.offerFirstPositionText.trim().isNotEmpty
          ? widget.order.offerFirstPositionText.trim()
          : _defaultServicePositionText(serviceType: _serviceType),
    );
    _firstPositionRemarkCtrl = TextEditingController(
      text: widget.order.offerFirstPositionRemark.trim().isNotEmpty
          ? widget.order.offerFirstPositionRemark.trim()
          : _defaultServicePositionRemark(serviceType: _serviceType),
    );

    // Set additional info based on language
    _additionalInfoCtrl = TextEditingController(
      text: _language == 'en'
          ? OfferData.defaultAdditionalInfoEn
          : OfferData.defaultAdditionalInfoDe,
    );

    if (widget.order.offerPositions.isNotEmpty) {
      for (final posData in widget.order.offerPositions) {
        _offerPositions.add(ExtraPosition.fromJson(posData));
      }
    } else {
      final legacyCustomPositions = widget.order.offerExtraPositions
          .map((posData) => ExtraPosition.fromJson(posData))
          .where((position) => position.name.trim().isNotEmpty)
          .toList();
      _offerPositions.addAll(
        _buildGeneratedOfferPositions(customPositions: legacyCustomPositions),
      );
    }
    _ensureRequestDerivedOfferPositions();
    _migrateLegacyDiscountToPosition();
    _syncLegacyServicePositionControllers();
  }

  @override
  void dispose() {
    _editorNameCtrl.dispose();
    _eventTimeCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientContactCtrl.dispose();
    _locationCtrl.dispose();
    _guestCountCtrl.dispose();
    _cocktailsCtrl.dispose();
    _barDescCtrl.dispose();
    _shotsCtrl.dispose();
    _orderTotalCtrl.dispose();
    _distanceKmCtrl.dispose();
    _travelCostPerKmCtrl.dispose();
    _barCostCtrl.dispose();
    _firstPositionTextCtrl.dispose();
    _firstPositionRemarkCtrl.dispose();
    _additionalInfoCtrl.dispose();
    super.dispose();
  }

  String _defaultServicePositionText({String? serviceType, String? language}) {
    final resolvedServiceType = serviceType ?? _serviceType;
    final isEn = (language ?? _language) == 'en';
    return switch (resolvedServiceType) {
      'cocktail_barservice' =>
        isEn ? 'Cocktail & Bar Service' : 'Cocktail- & Barservice',
      'cocktail_service' =>
        isEn ? 'Cocktail Service only' : 'Nur Cocktailservice',
      'mocktail_service' =>
        isEn ? 'Mocktail Service only' : 'Nur Mocktailservice',
      'bar_service' => isEn ? 'Bar Service only' : 'Nur Barservice',
      _ => isEn ? 'Cocktail & Bar Service' : 'Cocktail- & Barservice',
    };
  }

  String _defaultServicePositionRemark({
    String? serviceType,
    String? language,
  }) {
    final resolvedLanguage = language ?? _language;
    final isEn = resolvedLanguage == 'en';
    final serviceLabel = _defaultServicePositionText(
      serviceType: serviceType,
      language: resolvedLanguage,
    );

    final supervisorItems = widget.order.items
        .where((item) => item['category'] == 'supervisor')
        .toList();
    final supervisorSummary = supervisorItems
        .map(
          (item) =>
              "${item['quantity']}x ${item['name'].replaceAll(' (5h)', '')}",
        )
        .join(', ');

    final count = supervisorItems.fold<int>(
      0,
      (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
    );
    final fallbackCount = _selectedEmployees.isNotEmpty
        ? _selectedEmployees.length
        : 3;
    final finalCount = count > 0 ? count : fallbackCount;

    final rolesText = supervisorSummary.isNotEmpty
        ? (isEn ? 'Incl. $supervisorSummary' : 'Inkl. $supervisorSummary')
        : (isEn ? '$finalCount Barkeepers' : '$finalCount Barkeeper');

    return isEn
        ? '- $rolesText\n- Max. 5h $serviceLabel\n- Unlimitiert Cocktails (s. oben)\n- served in 0.3L hard plastic cups'
        : '- $rolesText\n- Max. 5h $serviceLabel\n- Unlimitiert Cocktails (s. oben)\n- ausgeschenkt in 0.3L Hartplastikbechern';
  }

  String _resolvedServicePositionText() {
    if (_offerPositions.isNotEmpty &&
        _offerPositions.first.name.trim().isNotEmpty) {
      return _offerPositions.first.name.trim();
    }
    final current = _firstPositionTextCtrl.text.trim();
    return current.isNotEmpty ? current : _defaultServicePositionText();
  }

  String _resolvedServicePositionRemark() {
    if (_offerPositions.isNotEmpty &&
        _offerPositions.first.remark.trim().isNotEmpty) {
      return _offerPositions.first.remark.trim();
    }
    final current = _firstPositionRemarkCtrl.text.trim();
    return current.isNotEmpty ? current : _defaultServicePositionRemark();
  }

  void _syncLegacyServicePositionControllers() {
    if (_offerPositions.isEmpty) {
      _firstPositionTextCtrl.text = _defaultServicePositionText();
      _firstPositionRemarkCtrl.text = _defaultServicePositionRemark();
      return;
    }

    _firstPositionTextCtrl.text = _offerPositions.first.name;
    _firstPositionRemarkCtrl.text = _offerPositions.first.remark;
  }

  String _discountPositionName() => _language == 'en' ? 'Discount' : 'Rabatt';

  String _discountPositionRemark() {
    final existing = widget.order.offerDiscountRemark.trim();
    if (existing.isNotEmpty) {
      return existing;
    }
    return _language == 'en'
        ? 'Family/Friend discount'
        : 'Familie/Freunde Rabatt';
  }

  bool get _requiresCocktails => _serviceType != 'bar_service';

  bool get _hasEventTypeSelection => _eventTypes.isNotEmpty;

  bool get _hasOfferPositions => _offerPositions.isNotEmpty;

  String? get _eventTypeError =>
      _showValidationErrors && !_hasEventTypeSelection
      ? 'offer.event_type_required'.tr()
      : null;

  String? get _positionsError => _showValidationErrors && !_hasOfferPositions
      ? 'offer.positions_required'.tr()
      : null;

  String? _validateGuestCount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'offer.field_required'.tr();
    }
    final guestCount = int.tryParse(value.trim());
    if (guestCount == null || guestCount <= 0) {
      return 'offer.invalid_number'.tr();
    }
    return null;
  }

  String? _validateCocktails(String? value) {
    if (!_requiresCocktails) {
      return null;
    }
    final cocktails =
        value
            ?.split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];
    if (cocktails.isEmpty) {
      return 'offer.cocktails_required'.tr();
    }
    return null;
  }

  bool _validateOfferBeforeAction() {
    FocusScope.of(context).unfocus();
    setState(() => _showValidationErrors = true);

    final isFormValid = _formKey.currentState!.validate();
    final hasRequiredSections = _hasEventTypeSelection && _hasOfferPositions;
    final isValid = isFormValid && hasRequiredSections;

    if (!isValid && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('offer.validation_error'.tr())));
    }

    return isValid;
  }

  Widget _buildSectionErrorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isDiscountPosition(ExtraPosition position) {
    final normalized = position.name.trim().toLowerCase();
    return position.total < 0 &&
        (normalized == 'rabatt' || normalized == 'discount');
  }

  void _migrateLegacyDiscountToPosition() {
    if (widget.order.offerDiscount <= 0) {
      return;
    }

    final hasDiscountPosition = _offerPositions.any(_isDiscountPosition);
    if (hasDiscountPosition) {
      return;
    }

    final dateStr =
        '${_eventDate.day.toString().padLeft(2, '0')}.${_eventDate.month.toString().padLeft(2, '0')}.${_eventDate.year}';

    _offerPositions.add(
      ExtraPosition(
        date: dateStr,
        name: _discountPositionName(),
        price: -widget.order.offerDiscount,
        quantity: 1,
        remark: _discountPositionRemark(),
      ),
    );
  }

  void _syncPrimaryPositionDefaults({
    required String previousText,
    required String nextText,
    required String previousRemark,
    required String nextRemark,
  }) {
    if (_offerPositions.isEmpty) return;

    final firstPosition = _offerPositions.first;
    final currentText = firstPosition.name.trim();
    final currentRemark = firstPosition.remark.trim();
    final shouldSyncText = currentText.isEmpty || currentText == previousText;
    final shouldSyncRemark =
        currentRemark.isEmpty || currentRemark == previousRemark;

    if (!shouldSyncText && !shouldSyncRemark) return;

    _offerPositions[0] = firstPosition.copyWith(
      name: shouldSyncText ? nextText : null,
      remark: shouldSyncRemark ? nextRemark : null,
    );
  }

  List<ExtraPosition> _buildGeneratedOfferPositions({
    List<ExtraPosition> customPositions = const [],
  }) {
    final dateStr =
        '${_eventDate.day.toString().padLeft(2, '0')}.${_eventDate.month.toString().padLeft(2, '0')}.${_eventDate.year}';
    final orderTotal =
        double.tryParse(_orderTotalCtrl.text.trim()) ?? widget.order.total;
    final distanceKm = int.tryParse(_distanceKmCtrl.text.trim()) ?? 0;
    final travelCostPerKm =
        double.tryParse(_travelCostPerKmCtrl.text.trim()) ?? 0.70;
    final barCost = double.tryParse(_barCostCtrl.text.trim()) ?? 0;
    final travelTotal = distanceKm * travelCostPerKm;
    final barServiceCost = orderTotal - travelTotal - barCost;

    final generated = <ExtraPosition>[
      ExtraPosition(
        date: dateStr,
        name: _firstPositionTextCtrl.text.trim().isNotEmpty
            ? _firstPositionTextCtrl.text.trim()
            : _defaultServicePositionText(),
        price: barServiceCost,
        quantity: 1,
        remark: _firstPositionRemarkCtrl.text.trim().isNotEmpty
            ? _firstPositionRemarkCtrl.text.trim()
            : _defaultServicePositionRemark(),
      ),
      if (distanceKm > 0)
        ExtraPosition(
          date: dateStr,
          name: _language == 'en' ? 'Travel Costs' : 'Reisekosten',
          price: travelCostPerKm,
          quantity: distanceKm,
          remark: _language == 'en'
              ? 'Travel from Allschwil CH to ${_locationCtrl.text.trim()}'
              : 'Reisekosten von Allschwil CH nach ${_locationCtrl.text.trim()}',
        ),
      ExtraPosition(
        date: dateStr,
        name: _language == 'en' ? 'Extra hours' : 'Extrastunden',
        price: 50,
        quantity: 0,
        remark: _language == 'en'
            ? '50 ${_currency.code}/Barkeeper/h extra'
            : '50 ${_currency.code}/Barkeeper/Std. extra',
      ),
      if (barCost > 0)
        ExtraPosition(
          date: dateStr,
          name: _language == 'en' ? 'Bar Counter' : 'Theke',
          price: barCost,
          quantity: 1,
          remark: _language == 'en'
              ? 'Mobile bar counter provided'
              : 'Mobile Theke wird gestellt',
        ),
      ...customPositions,
    ];

    final existingKeys = generated
        .map((position) => _positionNameKey(position.name))
        .toSet();
    for (final requestPosition in _buildRequestDerivedOfferPositions()) {
      final key = _positionNameKey(requestPosition.name);
      if (existingKeys.add(key)) {
        generated.add(requestPosition);
      }
    }

    return generated;
  }

  String _normalizeServiceType(String serviceType) {
    return switch (serviceType) {
      'cocktailservice' => 'cocktail_service',
      'barservice' => 'bar_service',
      _ => serviceType,
    };
  }

  void _onServiceTypeChanged(String value) {
    final previousDefault = _defaultServicePositionText(
      serviceType: _serviceType,
    );
    final previousRemarkDefault = _defaultServicePositionRemark(
      serviceType: _serviceType,
    );
    final nextDefault = _defaultServicePositionText(serviceType: value);
    final nextRemarkDefault = _defaultServicePositionRemark(serviceType: value);
    final currentText = _firstPositionTextCtrl.text.trim();
    final currentRemark = _firstPositionRemarkCtrl.text.trim();
    final shouldSyncTextDefault =
        currentText.isEmpty || currentText == previousDefault;
    final shouldSyncRemarkDefault =
        currentRemark.isEmpty || currentRemark == previousRemarkDefault;

    setState(() {
      _serviceType = value;
      if (shouldSyncTextDefault) {
        _firstPositionTextCtrl.text = nextDefault;
      }
      if (shouldSyncRemarkDefault) {
        _firstPositionRemarkCtrl.text = nextRemarkDefault;
      }
      _syncPrimaryPositionDefaults(
        previousText: previousDefault,
        nextText: nextDefault,
        previousRemark: previousRemarkDefault,
        nextRemark: nextRemarkDefault,
      );
      _syncLegacyServicePositionControllers();
    });
  }

  void _onLanguageChanged(String lang) {
    final previousDefault = _defaultServicePositionText(
      serviceType: _serviceType,
      language: _language,
    );
    final previousRemarkDefault = _defaultServicePositionRemark(
      serviceType: _serviceType,
      language: _language,
    );
    final currentText = _firstPositionTextCtrl.text.trim();
    final currentRemark = _firstPositionRemarkCtrl.text.trim();
    final shouldSyncTextDefault =
        currentText.isEmpty || currentText == previousDefault;
    final shouldSyncRemarkDefault =
        currentRemark.isEmpty || currentRemark == previousRemarkDefault;

    setState(() {
      _language = lang;
      _additionalInfoCtrl.text = lang == 'en'
          ? OfferData.defaultAdditionalInfoEn
          : OfferData.defaultAdditionalInfoDe;
      if (shouldSyncTextDefault) {
        _firstPositionTextCtrl.text = _defaultServicePositionText(
          serviceType: _serviceType,
          language: lang,
        );
      }
      if (shouldSyncRemarkDefault) {
        _firstPositionRemarkCtrl.text = _defaultServicePositionRemark(
          serviceType: _serviceType,
          language: lang,
        );
      }
      _syncPrimaryPositionDefaults(
        previousText: previousDefault,
        nextText: _defaultServicePositionText(
          serviceType: _serviceType,
          language: lang,
        ),
        previousRemark: previousRemarkDefault,
        nextRemark: _defaultServicePositionRemark(
          serviceType: _serviceType,
          language: lang,
        ),
      );
      _syncLegacyServicePositionControllers();
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
      currency: _currency.code,
      guestCount:
          int.tryParse(_guestCountCtrl.text.trim()) ?? widget.order.personCount,
      editorName: _editorNameCtrl.text.trim(),
      clientName: _clientNameCtrl.text.trim(),
      clientContact: _clientContactCtrl.text.trim(),
      eventLocation: _locationCtrl.text.trim(),
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
      discount: 0,
      discountRemark: '',
      additionalInfo: _additionalInfoCtrl.text,
      language: _language,
      serviceType: _serviceType,
      servicePositionText: _resolvedServicePositionText(),
      servicePositionRemark: _resolvedServicePositionRemark(),
      extraPositions: List.of(_offerPositions),
      offerPositions: List.of(_offerPositions),
      assignedEmployees: _selectedEmployees.toList(),
      supervisorItems: widget.order.items
          .where((item) => item['category'] == 'supervisor')
          .toList(),
      barDrinks: widget.order.barDrinks,
      alcoholPurchase: widget.order.alcoholPurchase,
      additionalServices: widget.order.additionalServices,
      remarks: widget.order.remarks,
    );
  }

  Future<bool> _saveOfferData() async {
    final offerSaved = await orderRepository.updateOfferData(
      orderId: widget.order.id,
      clientName: _clientNameCtrl.text.trim(),
      clientContact: _clientContactCtrl.text.trim(),
      eventTime: _eventTimeCtrl.text.trim(),
      eventTypes: _eventTypes.map((e) => e.name).toList(),
      discount: 0,
      discountRemark: '',
      language: _language,
      eventDate: _eventDate,
      extraPositions: _offerPositions.map((e) => e.toJson()).toList(),
      offerPositions: _offerPositions.map((e) => e.toJson()).toList(),
      assignedEmployees: _selectedEmployees.toList(),
      serviceType: _serviceType,
      firstPositionText: _resolvedServicePositionText(),
      firstPositionRemark: _resolvedServicePositionRemark(),
      distanceKm: int.tryParse(_distanceKmCtrl.text.trim()) ?? 0,
      travelCostPerKm:
          double.tryParse(_travelCostPerKmCtrl.text.trim()) ?? 0.70,
      barCost: double.tryParse(_barCostCtrl.text.trim()) ?? 0,
      location: _locationCtrl.text.trim(),
      currency: _currency.code,
    );

    if (!offerSaved) {
      return false;
    }

    // Also update cocktails, shots, and bar description
    return orderRepository.updateOrderCocktailsAndBar(
      orderId: widget.order.id,
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
    );
  }

  Future<void> _saveOnly() async {
    if (!_validateOfferBeforeAction()) return;
    setState(() => _isGenerating = true);
    try {
      final saved = await _saveOfferData();
      if (!saved) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('offer.save_failed'.tr())));
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('offer.saved'.tr())));
        // Mark as saved and navigate back to orders overview
        setState(() => _savedSuccessfully = true);
        context.go('/orders');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _previewPdf() async {
    if (!_validateOfferBeforeAction()) return;
    setState(() => _isGenerating = true);
    try {
      final saved = await _saveOfferData();
      if (!saved) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('offer.save_failed'.tr())));
        }
        return;
      }
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
    if (!_validateOfferBeforeAction()) return;
    setState(() => _isGenerating = true);
    try {
      final saved = await _saveOfferData();
      if (!saved) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('offer.save_failed'.tr())));
        }
        return;
      }
      final offer = _buildOfferData();
      final pdfBytes = await OfferPdfGenerator.generatePdfBytes(offer);

      // Upload to OneDrive if supported and in production
      final safeName = offer.orderName.replaceAll(' ', '_');
      final dateTag =
          '${offer.eventDate.year}${offer.eventDate.month.toString().padLeft(2, '0')}${offer.eventDate.day.toString().padLeft(2, '0')}';
      if (microsoftGraphService.isSupported && EnvConfig.isOneDriveEnabled) {
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
      final safeNameLower = offer.orderName.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '_',
      );
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'angebot_${safeNameLower}_$dateTag.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('offer.pdf_created'.tr())));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _printPdf() async {
    if (!_validateOfferBeforeAction()) return;
    setState(() => _isGenerating = true);
    try {
      final saved = await _saveOfferData();
      if (!saved) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('offer.save_failed'.tr())));
        }
        return;
      }
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

  Future<void> _shareOffer() async {
    if (!_validateOfferBeforeAction()) return;

    final cocktails = _cocktailsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Build a snapshot of the offer data at the time the dialog opens
    final offerSnapshot = _buildOfferData();
    final safeNameLower = offerSnapshot.orderName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '_',
    );
    final dateTag =
        '${offerSnapshot.eventDate.year}${offerSnapshot.eventDate.month.toString().padLeft(2, '0')}${offerSnapshot.eventDate.day.toString().padLeft(2, '0')}';
    final pdfFilename = 'angebot_${safeNameLower}_$dateTag.pdf';

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => OfferShareDialog(
        clientName: _clientNameCtrl.text.trim(),
        editorName: _editorNameCtrl.text.trim(),
        selectedCocktails: cocktails,
        generatePdfBytes: () =>
            OfferPdfGenerator.generatePdfBytes(offerSnapshot),
        pdfFilename: pdfFilename,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curr = _currency;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_savedSuccessfully,
      onPopInvokedWithResult: (didPop, result) {
        if (_savedSuccessfully && !didPop) {
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
                      child: OfferActionButtons(
                        isGenerating: _isGenerating,
                        onSaveOnly: _saveOnly,
                        onPreview: _previewPdf,
                        onGeneratePdf: _confirmGeneratePdf,
                        onPrint: _printPdf,
                        onShare: _shareOffer,
                      ),
                    ),
                  ),
                ),
              ),
              // ── Scrollable form ───────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOrderInfoBanner(colorScheme, curr),
                          const SizedBox(height: 20),
                          _buildCurrencySection(),
                          const SizedBox(height: 20),
                          _buildEditorSection(),
                          const SizedBox(height: 20),
                          _buildClientSection(),
                          const SizedBox(height: 20),
                          _buildGuestCountSection(),
                          const SizedBox(height: 20),
                          _buildEventTypeSection(),
                          const SizedBox(height: 20),
                          _buildServiceTypeSection(),
                          const SizedBox(height: 20),
                          _buildServicesSection(),
                          const SizedBox(height: 20),
                          _buildEmployeeSelectionSection(),
                          const SizedBox(height: 20),
                          _buildOfferPositionsSection(curr),
                          const SizedBox(height: 20),
                          OfferPricePreview(
                            currency: curr,
                            orderTotal:
                                double.tryParse(_orderTotalCtrl.text.trim()) ??
                                0,
                            distanceKm:
                                int.tryParse(_distanceKmCtrl.text.trim()) ?? 0,
                            travelCostPerKm:
                                double.tryParse(
                                  _travelCostPerKmCtrl.text.trim(),
                                ) ??
                                0.70,
                            barCost:
                                double.tryParse(_barCostCtrl.text.trim()) ?? 0,
                            discount: 0,
                            positionsTotal: _offerPositions.fold<double>(
                              0.0,
                              (sum, position) => sum + position.total,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildAdditionalInfoSection(),
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
      ), // Scaffold
    ); // PopScope
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

  Widget _buildCurrencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'shopping.currency'.tr()),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<Currency>(
            segments: Currency.values
                .map(
                  (currency) => ButtonSegment<Currency>(
                    value: currency,
                    label: Text(currency.code),
                  ),
                )
                .toList(),
            selected: {_currency},
            onSelectionChanged: (selection) {
              setState(() {
                _currency = selection.first;
              });
            },
          ),
        ),
      ],
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
                required: true,
              ),
            ];
            return Column(
              children: [
                wide
                    ? Row(
                        children: fields
                            .map(
                              (f) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: f,
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : Column(
                        children: fields
                            .map(
                              (f) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: f,
                              ),
                            )
                            .toList(),
                      ),
                const SizedBox(height: 8),
                _field(
                  controller: _locationCtrl,
                  label: 'orders.location'.tr(),
                  hint: 'z.B. Musterstrasse 123, 3000 Bern',
                  required: true,
                ),
              ],
            );
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: _eventTypeError != null
                  ? Theme.of(context).colorScheme.error
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: EventTypeSelector(
            selectedTypes: _eventTypes,
            onChanged: (newTypes) => setState(() {
              _eventTypes.clear();
              _eventTypes.addAll(newTypes);
            }),
          ),
        ),
        if (_eventTypeError != null) _buildSectionErrorText(_eventTypeError!),
      ],
    );
  }

  /// Build employee selection section (choose barkeepers)
  Widget _buildEmployeeSelectionSection() {
    return StreamBuilder<List<Employee>>(
      stream: employeeRepository.watchEmployees(),
      builder: (context, snapshot) {
        final employees = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(label: 'invoice.extra_hours_section'.tr()),
            const SizedBox(height: 8),
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                        employee.name.isNotEmpty
                            ? employee.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
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
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildGuestCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'offer.event_details'.tr()),
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
                  validator: _validateGuestCount,
                ),
              ),
              SizedBox(
                width: 200,
                child: _field(
                  controller: _eventTimeCtrl,
                  label: 'offer.event_time'.tr(),
                  hint: '17:30',
                  required: true,
                ),
              ),
              SizedBox(width: 200, child: _buildDatePicker()),
            ];
            return wide
                ? Row(
                    children: fields
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: f,
                          ),
                        )
                        .toList(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: fields
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: f,
                          ),
                        )
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
          validator: _validateCocktails,
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

  Widget _buildServiceTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: 'orders.service_type'.tr()),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButton<String>(
            value: _serviceType,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: 'cocktail_barservice',
                child: Text('orders.service_cocktail_bar'.tr()),
              ),
              DropdownMenuItem(
                value: 'cocktail_service',
                child: Text('orders.service_cocktail_only'.tr()),
              ),
              DropdownMenuItem(
                value: 'mocktail_service',
                child: Text('orders.service_mocktail_only'.tr()),
              ),
              DropdownMenuItem(
                value: 'bar_service',
                child: Text('orders.service_bar_only'.tr()),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                _onServiceTypeChanged(value);
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'offer.positions_manage_hint'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  // ── Offer positions ─────────────────────────────────────────────────────

  /// Auto-generate all offer positions from the current form values.
  void _generateOfferPositions() {
    final autoNames = {
      _defaultServicePositionText(),
      'Reisekosten',
      'Travel Costs',
      'Extrastunden',
      'Extra hours',
      'Theke',
      'Bar Counter',
    };
    final existingCustom = _offerPositions
        .asMap()
        .entries
        .where(
          (entry) => entry.key > 0 && !autoNames.contains(entry.value.name),
        )
        .map((entry) => entry.value)
        .toList();

    setState(() {
      _offerPositions
        ..clear()
        ..addAll(
          _buildGeneratedOfferPositions(customPositions: existingCustom),
        );
      _syncLegacyServicePositionControllers();
    });
  }

  Widget _buildPositionMetaChip({
    required IconData icon,
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildOfferPositionsSection(Currency curr) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _positionsError != null
              ? Theme.of(context).colorScheme.error
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 620;
                final titleRow = Row(
                  children: [
                    Icon(
                      Icons.list_alt,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'offer.positions_list'.tr(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                );
                final actionButtons = [
                  OutlinedButton.icon(
                    onPressed: _generateOfferPositions,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text('offer.rebuild_positions'.tr()),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _showOfferPositionDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('offer.add_position'.tr()),
                  ),
                ];

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow,
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: actionButtons),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    ...[
                      actionButtons.first,
                      const SizedBox(width: 8),
                      actionButtons.last,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'offer.positions_help'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            if (_positionsError != null)
              _buildSectionErrorText(_positionsError!),
            if (_offerPositions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'offer.positions_empty'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              ..._offerPositions.asMap().entries.map((entry) {
                final index = entry.key;
                final pos = entry.value;
                final isTbd = pos.quantity == 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 460;
                          final titleInfo = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pos.name,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '#${index + 1}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                              ),
                            ],
                          );
                          final totalInfo = Column(
                            crossAxisAlignment: isCompact
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            children: [
                              Text(
                                'offer.total'.tr(),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Text(
                                isTbd ? 'tbd' : curr.format(pos.total),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          );
                          final actionButtons = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () =>
                                    _showOfferPositionDialog(index: index),
                                tooltip: 'common.edit'.tr(),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 30,
                                  height: 30,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _offerPositions.removeAt(index);
                                    _syncLegacyServicePositionControllers();
                                  });
                                },
                                tooltip: 'common.delete'.tr(),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 30,
                                  height: 30,
                                ),
                              ),
                            ],
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: titleInfo),
                                    const SizedBox(width: 6),
                                    actionButtons,
                                  ],
                                ),
                                const SizedBox(height: 6),
                                totalInfo,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: titleInfo),
                              const SizedBox(width: 8),
                              totalInfo,
                              actionButtons,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (pos.date.isNotEmpty)
                            _buildPositionMetaChip(
                              icon: Icons.calendar_today,
                              label: pos.date,
                            ),
                          _buildPositionMetaChip(
                            icon: Icons.numbers,
                            label:
                                '${'offer.position_quantity'.tr()}: ${isTbd ? 'tbd' : pos.quantity}',
                          ),
                          _buildPositionMetaChip(
                            icon: Icons.attach_money,
                            label:
                                '${'offer.position_price'.tr()}: ${isTbd ? 'tbd' : curr.format(pos.price)}',
                          ),
                        ],
                      ),
                      if (pos.remark.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          pos.remark,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
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

  String _positionNameKey(String value) => value.trim().toLowerCase();

  List<ExtraPosition> _buildRequestDerivedOfferPositions() {
    final isEn = _language == 'en';
    final dateStr =
        '${_eventDate.day.toString().padLeft(2, '0')}.${_eventDate.month.toString().padLeft(2, '0')}.${_eventDate.year}';
    final rows = <ExtraPosition>[];

    if (widget.order.barDrinks.isNotEmpty) {
      rows.add(
        ExtraPosition(
          date: dateStr,
          name: isEn ? 'Bar Drinks' : 'Bargetränke',
          quantity: 1,
          price: 0,
          remark: formatOrderBarDrinkLabels(
            widget.order.barDrinks,
            isEnglish: isEn,
          ).join(', '),
        ),
      );
    }

    for (final alcohol in widget.order.alcoholPurchase) {
      rows.add(
        ExtraPosition(
          date: dateStr,
          name: formatOrderAlcoholLabel(alcohol, isEnglish: isEn),
          quantity: 1,
          price: 0,
          remark: isUsageBasedAlcoholOption(alcohol)
              ? (isEn ? 'Usage-based billing' : 'Nach Verbrauch abgerechnet')
              : '',
        ),
      );
    }

    for (final service in widget.order.additionalServices) {
      rows.add(
        ExtraPosition(
          date: dateStr,
          name: formatOrderAdditionalServiceLabel(
            service,
            isEnglish: isEn,
            currencyCode: _currency.code,
          ),
          quantity: 1,
          price: 0,
          remark: widget.order.remarks,
        ),
      );
    }

    final deduped = <ExtraPosition>[];
    final seen = <String>{};
    for (final row in rows) {
      final key = _positionNameKey(row.name);
      if (seen.add(key)) {
        deduped.add(row);
      }
    }
    return deduped;
  }

  void _ensureRequestDerivedOfferPositions() {
    final existing = _offerPositions
        .map((position) => _positionNameKey(position.name))
        .toSet();
    for (final row in _buildRequestDerivedOfferPositions()) {
      final key = _positionNameKey(row.name);
      if (existing.add(key)) {
        _offerPositions.add(row);
      }
    }
  }

  Future<void> _showOfferPositionDialog({int? index}) async {
    final existing = index != null ? _offerPositions[index] : null;
    final defaultDate =
        '${_eventDate.day.toString().padLeft(2, '0')}.${_eventDate.month.toString().padLeft(2, '0')}.${_eventDate.year}';

    final dateCtrl = TextEditingController(
      text: existing?.date.isNotEmpty == true ? existing!.date : defaultDate,
    );
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final quantityCtrl = TextEditingController(
      text: existing != null ? existing.quantity.toString() : '1',
    );
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final remarkCtrl = TextEditingController(text: existing?.remark ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<ExtraPosition>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null
              ? 'offer.add_position'.tr()
              : 'offer.edit_position'.tr(),
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Datum',
                      hintText: 'dd.MM.yyyy',
                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'offer.position_name'.tr(),
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'offer.field_required'.tr()
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: quantityCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'offer.position_quantity'.tr(),
                            prefixIcon: const Icon(Icons.numbers, size: 18),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                '${'offer.position_price'.tr()} (${_currency.code})',
                            prefixIcon: const Icon(
                              Icons.attach_money,
                              size: 18,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'offer.field_required'.tr();
                            }
                            if (double.tryParse(v.trim()) == null) {
                              return 'offer.invalid_number'.tr();
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: remarkCtrl,
                    decoration: InputDecoration(
                      labelText: 'offer.position_remark'.tr(),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
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
                Navigator.pop(
                  ctx,
                  ExtraPosition(
                    date: dateCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    quantity: int.tryParse(quantityCtrl.text.trim()) ?? 1,
                    price: double.tryParse(priceCtrl.text.trim()) ?? 0,
                    remark: remarkCtrl.text.trim(),
                  ),
                );
              }
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _offerPositions[index] = result;
        } else {
          _offerPositions.add(result);
        }
        _syncLegacyServicePositionControllers();
      });
    }
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
          decoration: InputDecoration(hintText: 'offer.additional_info'.tr()),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    FormFieldValidator<String>? validator,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      autovalidateMode: _showValidationErrors
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty)
                    ? 'offer.field_required'.tr()
                    : null
              : null),
      onChanged: (_) => setState(() {}),
    );
  }
}
