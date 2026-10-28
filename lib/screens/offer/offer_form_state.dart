import 'package:flutter/widgets.dart';

import '../../data/order_repository.dart';
import '../../models/additional_service.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../utils/currency.dart';
import '../../utils/order_option_labels.dart';
import '../../widgets/discount_editor.dart';

/// Splits a comma-separated list field ("Mojito, Hugo") into trimmed,
/// non-empty entries.
List<String> splitCommaList(String text) =>
    text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

/// Formats a date as "dd.MM.yyyy" (positions and date field).
String formatDocumentDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// All data of the offer screen: controllers, selections, the positions and
/// every derived value (price, discount, defaults). Mutators do not notify;
/// the screen calls them inside `setState`, exactly like the former inline
/// code. Moved verbatim from `_CreateOfferScreenState`.
class OfferFormState {
  OfferFormState(this.order, {String? displayName})
    : editorNameCtrl = TextEditingController(
        text: displayName ?? 'Inthusan Gunasiri',
      ) {
    _initializeControllers();
  }

  final SavedOrder order;

  // Language
  String language = 'de';
  late Currency currency;

  // Event date (editable)
  late DateTime eventDate;
  late String serviceType;

  // Controllers
  final TextEditingController editorNameCtrl;
  final eventTimeCtrl = TextEditingController();
  final clientNameCtrl = TextEditingController();
  final clientContactCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  late final TextEditingController guestCountCtrl;
  final cocktailsCtrl = TextEditingController();
  final barDescCtrl = TextEditingController();
  final shotsCtrl = TextEditingController();
  late final TextEditingController orderTotalCtrl;
  final distanceKmCtrl = TextEditingController();
  final travelCostPerKmCtrl = TextEditingController(text: '0.70');
  final barCostCtrl = TextEditingController();
  late final TextEditingController firstPositionTextCtrl;
  late final TextEditingController firstPositionRemarkCtrl;
  late final TextEditingController additionalInfoCtrl;

  // Discount (Rabatt): percentage of the positions subtotal or fixed amount
  bool discountIsPercent = true;
  final discountValueCtrl = TextEditingController();
  final discountRemarkCtrl = TextEditingController();

  // Event types
  final Set<EventType> eventTypes = {};

  // Assigned employees (names)
  late Set<String> selectedEmployees;

  /// All offer positions (standard + custom), saved as offerPositions.
  final List<ExtraPosition> offerPositions = [];

  bool isGenerating = false;
  bool showValidationErrors = false;
  bool savedSuccessfully = false;

  /// Additional-services catalog for resolving composite
  /// "serviceId:variantId" entries (see [setCatalog]).
  List<AdditionalService> catalog = [];

  /// Every controller, in the order [dispose] releases them.
  List<TextEditingController> get controllers => [
    editorNameCtrl,
    eventTimeCtrl,
    clientNameCtrl,
    clientContactCtrl,
    locationCtrl,
    guestCountCtrl,
    cocktailsCtrl,
    barDescCtrl,
    shotsCtrl,
    orderTotalCtrl,
    distanceKmCtrl,
    travelCostPerKmCtrl,
    barCostCtrl,
    firstPositionTextCtrl,
    firstPositionRemarkCtrl,
    additionalInfoCtrl,
    discountValueCtrl,
    discountRemarkCtrl,
  ];

  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
  }

  void _initializeControllers() {
    eventDate = order.date;
    currency = Currency.fromCode(order.currency);
    guestCountCtrl = TextEditingController(text: order.personCount.toString());
    orderTotalCtrl = TextEditingController(
      text: order.total.toStringAsFixed(2),
    );

    // For form orders, cocktails may be in requestedCocktails.
    final cocktailSource = order.cocktails.isNotEmpty
        ? order.cocktails
        : order.requestedCocktails;
    cocktailsCtrl.text = cocktailSource.join(', ');
    shotsCtrl.text = order.shots.join(', ');
    barDescCtrl.text = order.bar;
    distanceKmCtrl.text = order.distanceKm > 0
        ? order.distanceKm.toString()
        : '';
    travelCostPerKmCtrl.text = order.offerTravelCostPerKm > 0
        ? order.offerTravelCostPerKm.toStringAsFixed(2)
        : '0.70';
    barCostCtrl.text = order.offerBarCost > 0
        ? order.offerBarCost.toStringAsFixed(2)
        : (order.thekeCost > 0 ? order.thekeCost.toStringAsFixed(2) : '');

    // Saved offer data, or order name/phone/time as fallback
    clientNameCtrl.text = order.offerClientName.isEmpty
        ? order.name
        : order.offerClientName;
    clientContactCtrl.text = order.offerClientContact.isEmpty
        ? order.phone
        : order.offerClientContact;
    locationCtrl.text = order.location;
    eventTimeCtrl.text = order.offerEventTime.isEmpty
        ? order.eventTime
        : order.offerEventTime;
    language = order.offerLanguage;

    // Prefer the admin's own saved event types; else the customer's occasion.
    for (final typeStr in order.offerEventTypes) {
      final type = EventType.values.where((e) => e.name == typeStr).firstOrNull;
      if (type != null) eventTypes.add(type);
    }
    if (eventTypes.isEmpty && order.eventType.isNotEmpty) {
      final customerType = EventType.values
          .where((e) => e.name == order.eventType)
          .firstOrNull;
      if (customerType != null) eventTypes.add(customerType);
    }

    selectedEmployees = Set.from(order.assignedEmployees);

    serviceType = normalizeServiceType(
      order.serviceType.isNotEmpty ? order.serviceType : 'cocktail_barservice',
    );

    firstPositionTextCtrl = TextEditingController(
      text: order.offerFirstPositionText.trim().isNotEmpty
          ? order.offerFirstPositionText.trim()
          : defaultServicePositionText(serviceType: serviceType),
    );
    firstPositionRemarkCtrl = TextEditingController(
      text: order.offerFirstPositionRemark.trim().isNotEmpty
          ? order.offerFirstPositionRemark.trim()
          : defaultServicePositionRemark(serviceType: serviceType),
    );

    additionalInfoCtrl = TextEditingController(
      text: language == 'en'
          ? OfferData.defaultAdditionalInfoEn
          : OfferData.defaultAdditionalInfoDe,
    );

    if (order.offerPositions.isNotEmpty) {
      for (final posData in order.offerPositions) {
        offerPositions.add(ExtraPosition.fromJson(posData));
      }
    } else {
      final legacyCustomPositions = order.offerExtraPositions
          .map((posData) => ExtraPosition.fromJson(posData))
          .where((position) => position.name.trim().isNotEmpty)
          .toList();
      offerPositions.addAll(
        buildGeneratedOfferPositions(customPositions: legacyCustomPositions),
      );
    }
    ensureRequestDerivedOfferPositions();
    _initializeDiscount();
    syncLegacyServicePositionControllers();
  }

  String defaultServicePositionText({String? serviceType, String? language}) {
    final resolvedServiceType = serviceType ?? this.serviceType;
    final isEn = (language ?? this.language) == 'en';
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

  String defaultServicePositionRemark({String? serviceType, String? language}) {
    final resolvedLanguage = language ?? this.language;
    final isEn = resolvedLanguage == 'en';
    final serviceLabel = defaultServicePositionText(
      serviceType: serviceType,
      language: resolvedLanguage,
    );

    final supervisorItems = order.items
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
    final fallbackCount = selectedEmployees.isNotEmpty
        ? selectedEmployees.length
        : 3;
    final finalCount = count > 0 ? count : fallbackCount;

    final rolesText = supervisorSummary.isNotEmpty
        ? (isEn ? 'Incl. $supervisorSummary' : 'Inkl. $supervisorSummary')
        : (isEn ? '$finalCount Barkeepers' : '$finalCount Barkeeper');

    return isEn
        ? '- $rolesText\n- Max. 5h $serviceLabel\n- Unlimitiert Cocktails (s. oben)\n- served in 0.3L hard plastic cups'
        : '- $rolesText\n- Max. 5h $serviceLabel\n- Unlimitiert Cocktails (s. oben)\n- ausgeschenkt in 0.3L Hartplastikbechern';
  }

  String resolvedServicePositionText() {
    if (offerPositions.isNotEmpty &&
        offerPositions.first.name.trim().isNotEmpty) {
      return offerPositions.first.name.trim();
    }
    final current = firstPositionTextCtrl.text.trim();
    return current.isNotEmpty ? current : defaultServicePositionText();
  }

  String resolvedServicePositionRemark() {
    if (offerPositions.isNotEmpty &&
        offerPositions.first.remark.trim().isNotEmpty) {
      return offerPositions.first.remark.trim();
    }
    final current = firstPositionRemarkCtrl.text.trim();
    return current.isNotEmpty ? current : defaultServicePositionRemark();
  }

  void syncLegacyServicePositionControllers() {
    if (offerPositions.isEmpty) {
      firstPositionTextCtrl.text = defaultServicePositionText();
      firstPositionRemarkCtrl.text = defaultServicePositionRemark();
      return;
    }

    firstPositionTextCtrl.text = offerPositions.first.name;
    firstPositionRemarkCtrl.text = offerPositions.first.remark;
  }

  bool get requiresCocktails => serviceType != 'bar_service';

  bool get hasEventTypeSelection => eventTypes.isNotEmpty;

  bool get hasOfferPositions => offerPositions.isNotEmpty;

  /// Translation key of the event type hint, or null.
  String? get eventTypeErrorKey => showValidationErrors && !hasEventTypeSelection
      ? 'offer.event_type_required'
      : null;

  /// Translation key of the positions hint, or null.
  String? get positionsErrorKey => showValidationErrors && !hasOfferPositions
      ? 'offer.positions_required'
      : null;

  /// Translation key of the guest count error, or null.
  static String? guestCountErrorKey(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'offer.field_required';
    }
    final guestCount = int.tryParse(value.trim());
    if (guestCount == null || guestCount <= 0) {
      return 'offer.invalid_number';
    }
    return null;
  }

  /// Translation key of the cocktails error, or null.
  String? cocktailsErrorKey(String? value) {
    if (!requiresCocktails) {
      return null;
    }
    final cocktails = value == null ? const <String>[] : splitCommaList(value);
    if (cocktails.isEmpty) {
      return 'offer.cocktails_required';
    }
    return null;
  }

  /// Offers saved before the dedicated discount field kept it as a negative
  /// "Rabatt" position; that position is lifted into the discount field.
  void _initializeDiscount() {
    discountRemarkCtrl.text = order.offerDiscountRemark;
    if (order.offerDiscountPercent > 0) {
      discountIsPercent = true;
      discountValueCtrl.text = formatDiscountPercent(
        order.offerDiscountPercent,
      );
      return;
    }
    if (order.offerDiscount > 0) {
      discountIsPercent = false;
      discountValueCtrl.text = order.offerDiscount.toStringAsFixed(2);
      return;
    }

    final legacyIndex = offerPositions.indexWhere(isLegacyDiscountPosition);
    if (legacyIndex == -1) return;
    final legacy = offerPositions.removeAt(legacyIndex);
    discountIsPercent = false;
    discountValueCtrl.text = (-legacy.total).toStringAsFixed(2);
    if (discountRemarkCtrl.text.trim().isEmpty) {
      discountRemarkCtrl.text = legacy.remark;
    }
  }

  double get positionsSubtotal =>
      offerPositions.fold<double>(0.0, (sum, p) => sum + p.total);

  double get discountInput =>
      DiscountEditor.parseValue(discountValueCtrl.text) ?? 0;

  double get discountPercent =>
      discountIsPercent ? discountInput.clamp(0, 100).toDouble() : 0;

  double get discountAmount => resolveDiscountAmount(
    subtotal: positionsSubtotal,
    percent: discountPercent,
    amount: discountIsPercent ? 0 : discountInput,
  );

  /// Percentage persisted next to the amount (0 = fixed amount or none).
  double get storedDiscountPercent => discountAmount > 0 ? discountPercent : 0;

  /// What the offer PDF shows as total (`OfferData.grandTotal` with
  /// positions; offers always have positions here).
  double get grandTotal => positionsSubtotal - discountAmount;

  // Price preview inputs (the preview falls back to 0, not order.total).
  double get previewOrderTotal => double.tryParse(orderTotalCtrl.text.trim()) ?? 0;
  int get distanceKm => int.tryParse(distanceKmCtrl.text.trim()) ?? 0;
  double get travelCostPerKm =>
      double.tryParse(travelCostPerKmCtrl.text.trim()) ?? 0.70;
  double get barCost => double.tryParse(barCostCtrl.text.trim()) ?? 0;

  void setDiscountType(bool isPercent) {
    discountIsPercent = isPercent;
    discountValueCtrl.clear();
  }

  void setEventTypes(Set<EventType> types) {
    eventTypes
      ..clear()
      ..addAll(types);
  }

  void toggleEmployee(String name, bool selected) {
    if (selected) {
      selectedEmployees.add(name);
    } else {
      selectedEmployees.remove(name);
    }
  }

  void _syncPrimaryPositionDefaults({
    required String previousText,
    required String nextText,
    required String previousRemark,
    required String nextRemark,
  }) {
    if (offerPositions.isEmpty) return;

    final firstPosition = offerPositions.first;
    final currentText = firstPosition.name.trim();
    final currentRemark = firstPosition.remark.trim();
    final shouldSyncText = currentText.isEmpty || currentText == previousText;
    final shouldSyncRemark =
        currentRemark.isEmpty || currentRemark == previousRemark;

    if (!shouldSyncText && !shouldSyncRemark) return;

    offerPositions[0] = firstPosition.copyWith(
      name: shouldSyncText ? nextText : null,
      remark: shouldSyncRemark ? nextRemark : null,
    );
  }

  List<ExtraPosition> buildGeneratedOfferPositions({
    List<ExtraPosition> customPositions = const [],
  }) {
    final dateStr = formatDocumentDate(eventDate);
    final orderTotal =
        double.tryParse(orderTotalCtrl.text.trim()) ?? order.total;
    final distanceKm = int.tryParse(distanceKmCtrl.text.trim()) ?? 0;
    final travelCostPerKm =
        double.tryParse(travelCostPerKmCtrl.text.trim()) ?? 0.70;
    final barCost = double.tryParse(barCostCtrl.text.trim()) ?? 0;
    final travelTotal = distanceKm * travelCostPerKm;
    final barServiceCost = orderTotal - travelTotal - barCost;

    final generated = <ExtraPosition>[
      ExtraPosition(
        date: dateStr,
        name: firstPositionTextCtrl.text.trim().isNotEmpty
            ? firstPositionTextCtrl.text.trim()
            : defaultServicePositionText(),
        price: barServiceCost,
        quantity: 1,
        remark: firstPositionRemarkCtrl.text.trim().isNotEmpty
            ? firstPositionRemarkCtrl.text.trim()
            : defaultServicePositionRemark(),
      ),
      if (distanceKm > 0)
        ExtraPosition(
          date: dateStr,
          name: language == 'en' ? 'Travel Costs' : 'Reisekosten',
          price: travelCostPerKm,
          quantity: distanceKm,
          remark: language == 'en'
              ? 'Travel from Allschwil CH to ${locationCtrl.text.trim()}'
              : 'Reisekosten von Allschwil CH nach ${locationCtrl.text.trim()}',
        ),
      ExtraPosition(
        date: dateStr,
        name: language == 'en' ? 'Extra hours' : 'Extrastunden',
        price: 50,
        quantity: 0,
        remark: language == 'en'
            ? '50 ${currency.code}/Barkeeper/h extra'
            : '50 ${currency.code}/Barkeeper/Std. extra',
      ),
      if (barCost > 0)
        ExtraPosition(
          date: dateStr,
          name: language == 'en' ? 'Bar Counter' : 'Theke',
          price: barCost,
          quantity: 1,
          remark: language == 'en'
              ? 'Mobile bar counter provided'
              : 'Mobile Theke wird gestellt',
        ),
      ...customPositions,
    ];

    final existingKeys = generated
        .map((position) => positionNameKey(position.name))
        .toSet();
    for (final requestPosition in buildRequestDerivedOfferPositions()) {
      final key = positionNameKey(requestPosition.name);
      if (existingKeys.add(key)) {
        generated.add(requestPosition);
      }
    }

    return generated;
  }

  static String normalizeServiceType(String serviceType) {
    return switch (serviceType) {
      'cocktailservice' => 'cocktail_service',
      'barservice' => 'bar_service',
      _ => serviceType,
    };
  }

  void changeServiceType(String value) {
    final previousDefault = defaultServicePositionText(
      serviceType: serviceType,
    );
    final previousRemarkDefault = defaultServicePositionRemark(
      serviceType: serviceType,
    );
    final nextDefault = defaultServicePositionText(serviceType: value);
    final nextRemarkDefault = defaultServicePositionRemark(serviceType: value);
    final currentText = firstPositionTextCtrl.text.trim();
    final currentRemark = firstPositionRemarkCtrl.text.trim();
    final shouldSyncTextDefault =
        currentText.isEmpty || currentText == previousDefault;
    final shouldSyncRemarkDefault =
        currentRemark.isEmpty || currentRemark == previousRemarkDefault;

    serviceType = value;
    if (shouldSyncTextDefault) {
      firstPositionTextCtrl.text = nextDefault;
    }
    if (shouldSyncRemarkDefault) {
      firstPositionRemarkCtrl.text = nextRemarkDefault;
    }
    _syncPrimaryPositionDefaults(
      previousText: previousDefault,
      nextText: nextDefault,
      previousRemark: previousRemarkDefault,
      nextRemark: nextRemarkDefault,
    );
    syncLegacyServicePositionControllers();
  }

  void changeLanguage(String lang) {
    final previousDefault = defaultServicePositionText(
      serviceType: serviceType,
      language: language,
    );
    final previousRemarkDefault = defaultServicePositionRemark(
      serviceType: serviceType,
      language: language,
    );
    final currentText = firstPositionTextCtrl.text.trim();
    final currentRemark = firstPositionRemarkCtrl.text.trim();
    final shouldSyncTextDefault =
        currentText.isEmpty || currentText == previousDefault;
    final shouldSyncRemarkDefault =
        currentRemark.isEmpty || currentRemark == previousRemarkDefault;

    language = lang;
    additionalInfoCtrl.text = lang == 'en'
        ? OfferData.defaultAdditionalInfoEn
        : OfferData.defaultAdditionalInfoDe;
    if (shouldSyncTextDefault) {
      firstPositionTextCtrl.text = defaultServicePositionText(
        serviceType: serviceType,
        language: lang,
      );
    }
    if (shouldSyncRemarkDefault) {
      firstPositionRemarkCtrl.text = defaultServicePositionRemark(
        serviceType: serviceType,
        language: lang,
      );
    }
    _syncPrimaryPositionDefaults(
      previousText: previousDefault,
      nextText: defaultServicePositionText(
        serviceType: serviceType,
        language: lang,
      ),
      previousRemark: previousRemarkDefault,
      nextRemark: defaultServicePositionRemark(
        serviceType: serviceType,
        language: lang,
      ),
    );
    syncLegacyServicePositionControllers();
  }

  /// Rebuilds the standard positions from the current form values, keeping
  /// custom positions (everything after the first that is not a standard
  /// name).
  void regeneratePositions() {
    final autoNames = {
      defaultServicePositionText(),
      'Reisekosten',
      'Travel Costs',
      'Extrastunden',
      'Extra hours',
      'Theke',
      'Bar Counter',
    };
    final existingCustom = offerPositions
        .asMap()
        .entries
        .where(
          (entry) => entry.key > 0 && !autoNames.contains(entry.value.name),
        )
        .map((entry) => entry.value)
        .toList();

    offerPositions
      ..clear()
      ..addAll(buildGeneratedOfferPositions(customPositions: existingCustom));
    syncLegacyServicePositionControllers();
  }

  /// Adds ([index] null) or replaces a position.
  void putPosition(ExtraPosition position, {int? index}) {
    if (index != null) {
      offerPositions[index] = position;
    } else {
      offerPositions.add(position);
    }
    syncLegacyServicePositionControllers();
  }

  void removePosition(int index) {
    offerPositions.removeAt(index);
    syncLegacyServicePositionControllers();
  }

  static String positionNameKey(String value) => value.trim().toLowerCase();

  List<ExtraPosition> buildRequestDerivedOfferPositions() {
    final isEn = language == 'en';
    final dateStr = formatDocumentDate(eventDate);
    final rows = <ExtraPosition>[];

    if (order.shots.isNotEmpty) {
      final perFlavorRemark = order.shotSelections.isNotEmpty
          ? order.shotSelections.map((s) => '${s.name} ${s.quantity}').join(', ')
          : order.shots.join(', ');

      rows.add(
        ExtraPosition(
          date: dateStr,
          name: isEn ? 'Shots' : 'Shots',
          quantity: order.offerShotsCount > 0
              ? order.offerShotsCount
              : order.requestedShotsTotal,
          price: order.offerShotsPricePerPiece > 0
              ? order.offerShotsPricePerPiece
              : 1.50,
          remark: order.offerShotsRemark.isNotEmpty
              ? order.offerShotsRemark
              : perFlavorRemark,
        ),
      );
    }

    if (order.barDrinks.isNotEmpty) {
      rows.add(
        ExtraPosition(
          date: dateStr,
          name: isEn ? 'Bar Drinks' : 'Bargetränke',
          quantity: 1,
          price: 0,
          remark: formatOrderBarDrinkLabels(
            order.barDrinks,
            isEnglish: isEn,
          ).join(', '),
        ),
      );
    }

    for (final alcohol in order.alcoholPurchase) {
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

    for (final service in order.additionalServices) {
      rows.add(
        ExtraPosition(
          date: dateStr,
          name: resolveAdditionalServiceLabel(
            service,
            catalog: catalog,
            isEnglish: isEn,
            currencyCode: currency.code,
          ),
          quantity: 1,
          // Seeded from the resolved variant's price when available; legacy
          // bare-ID entries keep defaulting to 0.
          price: resolveAdditionalServicePrice(service, catalog: catalog) ?? 0,
          remark: order.remarks,
        ),
      );
    }

    final deduped = <ExtraPosition>[];
    final seen = <String>{};
    for (final row in rows) {
      final key = positionNameKey(row.name);
      if (seen.add(key)) {
        deduped.add(row);
      }
    }
    return deduped;
  }

  void ensureRequestDerivedOfferPositions() {
    final existing = offerPositions
        .map((position) => positionNameKey(position.name))
        .toSet();
    for (final row in buildRequestDerivedOfferPositions()) {
      final key = positionNameKey(row.name);
      if (existing.add(key)) {
        offerPositions.add(row);
      }
    }
  }

  /// The catalog arrived (stream): stores it and re-resolves positions that
  /// were seeded with a still-unresolved raw "serviceId:variantId" name.
  void setCatalog(List<AdditionalService> services) {
    catalog = services;
    _repairUnresolvedAdditionalServicePositions();
  }

  void _repairUnresolvedAdditionalServicePositions() {
    for (final rawService in order.additionalServices) {
      final index = offerPositions.indexWhere((p) => p.name == rawService);
      if (index == -1) continue;

      final resolvedName = resolveAdditionalServiceLabel(
        rawService,
        catalog: catalog,
        isEnglish: language == 'en',
        currencyCode: currency.code,
      );
      if (resolvedName == rawService) continue; // still unresolved

      final resolvedPrice = resolveAdditionalServicePrice(
        rawService,
        catalog: catalog,
      );
      offerPositions[index] = offerPositions[index].copyWith(
        name: resolvedName,
        price: resolvedPrice ?? offerPositions[index].price,
      );
    }
  }

  OfferData buildOfferData() {
    return OfferData(
      orderName: order.name,
      eventDate: eventDate,
      eventTime: eventTimeCtrl.text.trim(),
      currency: currency.code,
      guestCount: int.tryParse(guestCountCtrl.text.trim()) ?? order.personCount,
      editorName: editorNameCtrl.text.trim(),
      clientName: clientNameCtrl.text.trim(),
      clientContact: clientContactCtrl.text.trim(),
      eventLocation: locationCtrl.text.trim(),
      eventTypes: Set.of(eventTypes),
      cocktails: splitCommaList(cocktailsCtrl.text),
      shots: splitCommaList(shotsCtrl.text),
      barDescription: barDescCtrl.text.trim(),
      orderTotal: double.tryParse(orderTotalCtrl.text.trim()) ?? order.total,
      distanceKm: int.tryParse(distanceKmCtrl.text.trim()) ?? 0,
      travelCostPerKm: double.tryParse(travelCostPerKmCtrl.text.trim()) ?? 0.70,
      barCost: double.tryParse(barCostCtrl.text.trim()) ?? 0,
      discount: discountAmount,
      discountRemark: discountRemarkCtrl.text.trim(),
      discountPercent: discountAmount > 0 ? discountPercent : 0,
      additionalInfo: additionalInfoCtrl.text,
      language: language,
      serviceType: serviceType,
      servicePositionText: resolvedServicePositionText(),
      servicePositionRemark: resolvedServicePositionRemark(),
      extraPositions: List.of(offerPositions),
      offerPositions: List.of(offerPositions),
      assignedEmployees: selectedEmployees.toList(),
      supervisorItems: order.items
          .where((item) => item['category'] == 'supervisor')
          .toList(),
      barDrinks: order.barDrinks,
      alcoholPurchase: order.alcoholPurchase,
      additionalServices: order.additionalServices,
      remarks: order.remarks,
    );
  }

  /// Writes the offer (two repository calls, unchanged).
  Future<bool> save(OrderRepository repo) async {
    final offerSaved = await repo.updateOfferData(
      orderId: order.id,
      clientName: clientNameCtrl.text.trim(),
      clientContact: clientContactCtrl.text.trim(),
      eventTime: eventTimeCtrl.text.trim(),
      eventTypes: eventTypes.map((e) => e.name).toList(),
      discount: discountAmount,
      discountRemark: discountRemarkCtrl.text.trim(),
      discountPercent: discountAmount > 0 ? discountPercent : 0,
      language: language,
      eventDate: eventDate,
      extraPositions: offerPositions.map((e) => e.toJson()).toList(),
      offerPositions: offerPositions.map((e) => e.toJson()).toList(),
      assignedEmployees: selectedEmployees.toList(),
      serviceType: serviceType,
      firstPositionText: resolvedServicePositionText(),
      firstPositionRemark: resolvedServicePositionRemark(),
      distanceKm: int.tryParse(distanceKmCtrl.text.trim()) ?? 0,
      travelCostPerKm: double.tryParse(travelCostPerKmCtrl.text.trim()) ?? 0.70,
      barCost: double.tryParse(barCostCtrl.text.trim()) ?? 0,
      location: locationCtrl.text.trim(),
      currency: currency.code,
    );

    if (!offerSaved) {
      return false;
    }

    return repo.updateOrderCocktailsAndBar(
      orderId: order.id,
      cocktails: splitCommaList(cocktailsCtrl.text),
      shots: splitCommaList(shotsCtrl.text),
      bar: barDescCtrl.text.trim(),
    );
  }
}
