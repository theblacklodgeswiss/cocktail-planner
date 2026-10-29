import 'package:flutter/widgets.dart';

import '../../data/order_repository.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../utils/currency.dart';
import '../../utils/position_translation.dart';
import '../../widgets/discount_editor.dart';
import '../shared/document_sections/document_flow.dart' show DocIssue;
import '../offer/offer_form_state.dart' show splitCommaList;

/// All data of the invoice screen: controllers, selections, positions and
/// every derived value (fields-mode sums, extra hours, discount, grand
/// total). Mutators do not notify; the screen calls them inside `setState`.
/// Moved verbatim from `_CreateInvoiceScreenState`.
///
/// Two modes: with saved offer positions ("positions mode") the total is
/// their sum; otherwise ("fields mode") it is built from bar service,
/// travel, theke, shots, extra hours and extra positions.
class InvoiceFormState {
  InvoiceFormState(this.order, {String? displayName})
    : editorNameCtrl = TextEditingController(
        text: displayName ?? 'Mario Kantharoobarajah',
      ) {
    _initializeControllers();
  }

  final SavedOrder order;

  String language = 'de';
  late DateTime eventDate;
  late String serviceType;

  final TextEditingController editorNameCtrl;
  final eventTimeCtrl = TextEditingController();
  final clientNameCtrl = TextEditingController();
  final clientContactCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  late final TextEditingController guestCountCtrl;
  final cocktailsCtrl = TextEditingController();
  final barDescCtrl = TextEditingController();
  final shotsCtrl = TextEditingController();

  // Position controllers
  late final TextEditingController barServiceCostCtrl;
  final distanceKmCtrl = TextEditingController();
  final travelCostPerKmCtrl = TextEditingController(text: '0.70');
  late final TextEditingController thekeCostCtrl;
  late final TextEditingController shotsCountCtrl;
  final shotsPricePerPieceCtrl = TextEditingController(text: '1.50');
  final shotsRemarkCtrl = TextEditingController();

  // Discount (Rabatt)
  bool discountIsPercent = true;
  final discountValueCtrl = TextEditingController();
  final discountRemarkCtrl = TextEditingController();

  // Extra hours (Extrastunden)
  late final TextEditingController extraHoursCtrl;
  final extraHourRateCtrl = TextEditingController(text: '50.00');

  late Set<String> selectedEmployees;
  final Set<EventType> eventTypes = {};

  /// Extra positions (fields mode, backward compat).
  final List<ExtraPosition> extraPositions = [];

  /// Offer positions; non-empty means positions mode.
  final List<ExtraPosition> offerPositions = [];

  bool get usePositionsMode => offerPositions.isNotEmpty;

  bool isGenerating = false;
  String? totalValidationErrorKey;
  String? employeeValidationErrorKey;

  /// Every controller, in the order [dispose] releases them. Note: the
  /// former screen never disposed the location controller (a leak); it is
  /// released here as well.
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
    barServiceCostCtrl,
    distanceKmCtrl,
    travelCostPerKmCtrl,
    thekeCostCtrl,
    shotsCountCtrl,
    shotsPricePerPieceCtrl,
    shotsRemarkCtrl,
    discountValueCtrl,
    discountRemarkCtrl,
    extraHoursCtrl,
    extraHourRateCtrl,
  ];

  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
  }

  void _initializeControllers() {
    eventDate = order.date;
    guestCountCtrl = TextEditingController(text: order.personCount.toString());

    // Initial bar service cost
    final travelTotal = order.distanceKm * 2 * 0.70;
    final barServiceCost = order.total - travelTotal - order.thekeCost;
    barServiceCostCtrl = TextEditingController(
      text: barServiceCost.toStringAsFixed(2),
    );

    final cocktailSource = order.cocktails.isNotEmpty
        ? order.cocktails
        : order.requestedCocktails;
    cocktailsCtrl.text = cocktailSource.join(', ');
    shotsCtrl.text = order.shots.join(', ');
    barDescCtrl.text = order.bar;
    distanceKmCtrl.text = order.distanceKm > 0
        ? order.distanceKm.toString()
        : '';
    thekeCostCtrl = TextEditingController(
      text: order.thekeCost > 0 ? order.thekeCost.toStringAsFixed(2) : '',
    );

    // Shots position - saved values or calculated from personCount
    final shotsCount = order.offerShotsCount > 0
        ? order.offerShotsCount
        : (order.shots.isNotEmpty ? order.personCount ~/ 5 : 0);
    shotsCountCtrl = TextEditingController(
      text: shotsCount > 0 ? shotsCount.toString() : '',
    );
    shotsPricePerPieceCtrl.text = order.offerShotsPricePerPiece.toStringAsFixed(
      2,
    );

    if (order.offerShotsRemark.isNotEmpty) {
      shotsRemarkCtrl.text = order.offerShotsRemark;
    } else if (order.shots.isNotEmpty) {
      shotsRemarkCtrl.text =
          'Shots – ${order.shots.join(", ")}\nAusgeschenkt in 0.4 CL Shotbechern';
    }

    clientNameCtrl.text = order.offerClientName;
    clientContactCtrl.text = order.offerClientContact;
    locationCtrl.text = order.location;
    eventTimeCtrl.text = order.offerEventTime;
    language = order.offerLanguage;

    for (final typeStr in order.offerEventTypes) {
      final type = EventType.values.where((e) => e.name == typeStr).firstOrNull;
      if (type != null) eventTypes.add(type);
    }

    if (order.offerPositions.isNotEmpty) {
      for (final posData in order.offerPositions) {
        offerPositions.add(ExtraPosition.fromJson(posData));
      }
    } else {
      for (final posData in order.offerExtraPositions) {
        extraPositions.add(ExtraPosition.fromJson(posData));
      }
    }

    _initializeDiscount();

    extraHoursCtrl = TextEditingController(
      text: order.offerExtraHours > 0 ? order.offerExtraHours.toString() : '',
    );
    extraHourRateCtrl.text = order.offerExtraHourRate.toStringAsFixed(2);

    selectedEmployees = Set.from(order.assignedEmployees);

    serviceType = normalizeServiceType(
      order.serviceType.isNotEmpty ? order.serviceType : 'cocktail_barservice',
    );
  }

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

  static String normalizeServiceType(String serviceType) {
    return switch (serviceType) {
      'cocktailservice' => 'cocktail_service',
      'barservice' => 'bar_service',
      _ => serviceType,
    };
  }

  void changeLanguage(String lang) {
    language = lang;
    // Standard positions follow the language; custom texts are left alone.
    for (var i = 0; i < offerPositions.length; i++) {
      offerPositions[i] = translateStandardPosition(offerPositions[i], lang);
    }
  }

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

  void putOfferPosition(ExtraPosition position, {int? index}) {
    if (index != null) {
      offerPositions[index] = position;
    } else {
      offerPositions.add(position);
    }
  }

  void putExtraPosition(ExtraPosition position, {int? index}) {
    if (index != null) {
      extraPositions[index] = position;
    } else {
      extraPositions.add(position);
    }
  }

  double get barServiceCost =>
      double.tryParse(barServiceCostCtrl.text.trim()) ?? 0;
  int get distanceKm => int.tryParse(distanceKmCtrl.text.trim()) ?? 0;
  double get travelCostPerKm =>
      double.tryParse(travelCostPerKmCtrl.text.trim()) ?? 0.70;
  double get travelCostTotal => distanceKm * 2 * travelCostPerKm;
  double get thekeCost => double.tryParse(thekeCostCtrl.text.trim()) ?? 0;
  int get shotsCount => int.tryParse(shotsCountCtrl.text.trim()) ?? 0;
  double get shotsPricePerPiece =>
      double.tryParse(shotsPricePerPieceCtrl.text.trim()) ?? 1.50;
  double get shotsCostTotal => shotsCount * shotsPricePerPiece;
  double get extraPositionsTotal =>
      extraPositions.fold(0.0, (sum, p) => sum + p.total);

  // Extra hours: employees x hours x rate
  int get extraHours => int.tryParse(extraHoursCtrl.text.trim()) ?? 0;
  double get extraHourRate =>
      double.tryParse(extraHourRateCtrl.text.trim()) ?? 50.0;
  double get extraHoursTotal =>
      selectedEmployees.length * extraHours * extraHourRate;

  /// Sum of all fields-mode positions (without discount).
  double get positionsSum =>
      barServiceCost +
      travelCostTotal +
      thekeCost +
      shotsCostTotal +
      extraHoursTotal +
      extraPositionsTotal;

  /// Sum of all offer positions (positions mode).
  double get offerPositionsSum =>
      offerPositions.fold(0.0, (sum, p) => sum + p.total);

  /// Subtotal the discount applies to.
  double get subtotal => usePositionsMode ? offerPositionsSum : positionsSum;

  double get discountInput =>
      DiscountEditor.parseValue(discountValueCtrl.text) ?? 0;

  double get discountPercent =>
      discountIsPercent ? discountInput.clamp(0, 100).toDouble() : 0;

  double get discount => resolveDiscountAmount(
    subtotal: subtotal,
    percent: discountPercent,
    amount: discountIsPercent ? 0 : discountInput,
  );

  /// Discount percentage persisted alongside the amount (0 = fixed amount).
  double get storedDiscountPercent => discount > 0 ? discountPercent : 0;

  /// Grand total after discount.
  double get grandTotal => subtotal - discount;

  /// The order total that is saved: positions sum, or in fields mode only
  /// bar service + travel + theke (shots, extra hours and extra positions
  /// are stored separately and added by the PDF generator).
  double get savedTotal => usePositionsMode
      ? offerPositionsSum
      : (barServiceCost + travelCostTotal + thekeCost);

  /// Employees must be assigned. Sets/clears [employeeValidationErrorKey].
  bool validateEmployees() {
    if (selectedEmployees.isEmpty) {
      employeeValidationErrorKey = 'invoice.employees_required';
      return false;
    }
    employeeValidationErrorKey = null;
    return true;
  }

  /// The discount may not make the total negative.
  bool validateTotal() {
    if (grandTotal < 0) {
      totalValidationErrorKey = 'invoice.total_cannot_be_negative';
      return false;
    }
    totalValidationErrorKey = null;
    return true;
  }

  bool validateAll() {
    final employeesValid = validateEmployees();
    final totalValid = validateTotal();
    return employeesValid && totalValid;
  }

  /// The first validation error's translation key.
  String? get validationErrorKey =>
      employeeValidationErrorKey ?? totalValidationErrorKey;

  /// Everything missing or invalid, by step (same rules as the old
  /// screen's form validators plus [validateAll]).
  List<DocIssue> get issues {
    String? req(TextEditingController c) =>
        c.text.trim().isEmpty ? 'invoice.field_required' : null;
    final checks = <(int, String, String?)>[
      (0, 'editor', req(editorNameCtrl)),
      (0, 'client_name', req(clientNameCtrl)),
      (0, 'guests', req(guestCountCtrl)),
      (
        1,
        'employees',
        selectedEmployees.isEmpty ? 'invoice.employees_required' : null,
      ),
      (
        2,
        'bar_service_cost',
        usePositionsMode ? null : req(barServiceCostCtrl),
      ),
      (
        3,
        'discount',
        DiscountEditor.errorKeyOf(
          discountValueCtrl.text,
          isPercent: discountIsPercent,
        ),
      ),
      (3, 'total', grandTotal < 0 ? 'invoice.total_cannot_be_negative' : null),
    ];
    return [
      for (final (step, field, key) in checks)
        if (key != null) DocIssue(step, field, key),
    ];
  }

  /// The order as the invoice PDF and the share link see it.
  SavedOrder buildUpdatedOrder() {
    return SavedOrder(
      id: order.id,
      name: order.name,
      date: eventDate,
      items: order.items,
      total: savedTotal,
      personCount: int.tryParse(guestCountCtrl.text.trim()) ?? order.personCount,
      drinkerType: order.drinkerType,
      currency: order.currency,
      status: order.status,
      createdBy: order.createdBy,
      createdAt: order.createdAt,
      cocktails: splitCommaList(cocktailsCtrl.text),
      shots: splitCommaList(shotsCtrl.text),
      bar: barDescCtrl.text.trim(),
      distanceKm: distanceKm,
      thekeCost: thekeCost,
      offerClientName: clientNameCtrl.text.trim(),
      offerClientContact: clientContactCtrl.text.trim(),
      offerEventTime: eventTimeCtrl.text.trim(),
      offerEventTypes: eventTypes.map((e) => e.name).toList(),
      offerDiscount: discount,
      offerDiscountRemark: discountRemarkCtrl.text.trim(),
      offerDiscountPercent: storedDiscountPercent,
      offerLanguage: language,
      offerExtraPositions: usePositionsMode
          ? []
          : extraPositions.map((e) => e.toJson()).toList(),
      offerPositions: usePositionsMode
          ? offerPositions.map((e) => e.toJson()).toList()
          : order.offerPositions,
      offerShotsCount: usePositionsMode ? 0 : shotsCount,
      offerShotsPricePerPiece: usePositionsMode ? 0 : shotsPricePerPiece,
      offerShotsRemark: usePositionsMode ? '' : shotsRemarkCtrl.text.trim(),
      offerExtraHours: usePositionsMode ? 0 : extraHours,
      offerExtraHourRate: usePositionsMode ? 0 : extraHourRate,
      assignedEmployees: selectedEmployees.toList(),
      source: order.source,
      hasShoppingList: order.hasShoppingList,
      formSubmissionId: order.formSubmissionId,
      formCreatedAt: order.formCreatedAt,
      phone: order.phone,
      location: order.location,
      guestCountRange: order.guestCountRange,
      mobileBar: order.mobileBar,
      eventType: order.eventType,
      serviceType: serviceType,
      requestedCocktails: order.requestedCocktails,
    );
  }

  /// Writes the invoice (two repository calls, unchanged).
  Future<bool> save(OrderRepository repo) async {
    final offerSaved = await repo.updateOfferData(
      orderId: order.id,
      clientName: clientNameCtrl.text.trim(),
      clientContact: clientContactCtrl.text.trim(),
      eventTime: eventTimeCtrl.text.trim(),
      eventTypes: eventTypes.map((e) => e.name).toList(),
      discount: discount,
      discountRemark: discountRemarkCtrl.text.trim(),
      discountPercent: storedDiscountPercent,
      language: language,
      eventDate: eventDate,
      extraPositions: usePositionsMode
          ? []
          : extraPositions.map((e) => e.toJson()).toList(),
      offerPositions: usePositionsMode
          ? offerPositions.map((e) => e.toJson()).toList()
          : [],
      shotsCount: usePositionsMode ? 0 : shotsCount,
      shotsPricePerPiece: usePositionsMode ? 0 : shotsPricePerPiece,
      shotsRemark: usePositionsMode ? '' : shotsRemarkCtrl.text.trim(),
      extraHours: usePositionsMode ? 0 : extraHours,
      extraHourRate: usePositionsMode ? 0 : extraHourRate,
      assignedEmployees: selectedEmployees.toList(),
      serviceType: serviceType,
    );

    if (!offerSaved) {
      return false;
    }

    return repo.updateOrderTotals(
      orderId: order.id,
      total: savedTotal,
      distanceKm: usePositionsMode ? 0 : distanceKm,
      thekeCost: usePositionsMode ? 0 : thekeCost,
      cocktails: splitCommaList(cocktailsCtrl.text),
      shots: splitCommaList(shotsCtrl.text),
      bar: barDescCtrl.text.trim(),
    );
  }

  /// Calendar entry text (unchanged), with the discounted total.
  List<String> calendarBodyLines(
    SavedOrder built, {
    String? documentUrl,
    String? shoppingListUrl,
  }) {
    final customer = calendarCustomer(built);
    final employeeNames = built.assignedEmployees.isNotEmpty
        ? built.assignedEmployees.join(', ')
        : 'TBD';
    return <String>[
      'Auftrag: $customer',
      if (built.location.isNotEmpty) 'Adresse: ${built.location}',
      'Personen: ${built.personCount}',
      'Mitarbeiter: $employeeNames',
      'Gesamtbetrag: ${Currency.fromCode(built.currency).format(grandTotal)}',
      '',
      '--- Dokumente ---',
      if (documentUrl != null) 'Auftragsbestätigung: $documentUrl',
      if (shoppingListUrl != null) 'Einkaufsliste: $shoppingListUrl',
    ];
  }

  static String calendarCustomer(SavedOrder built) =>
      built.offerClientName.isNotEmpty ? built.offerClientName : built.name;

  /// Start of the calendar event: the date at the "HH:mm" event time.
  static DateTime calendarStart(SavedOrder built) {
    var eventStart = built.date;
    final timeParts = built.offerEventTime.split(':');
    if (timeParts.length >= 2) {
      eventStart = DateTime(
        built.date.year,
        built.date.month,
        built.date.day,
        int.tryParse(timeParts[0]) ?? 0,
        int.tryParse(timeParts[1]) ?? 0,
      );
    }
    return eventStart;
  }

  /// WhatsApp/clipboard text; follows the screen's DE/EN toggle.
  String shareMessage(String shareUrl) => language == 'en'
      ? 'Hello, here is your order confirmation for ${order.name}: $shareUrl'
      : 'Hallo, hier ist deine Auftragsbestätigung für ${order.name}: $shareUrl';
}
