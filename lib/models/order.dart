/// Order status enum
enum OrderStatus {
  quote('quote', 'Angebot'),
  accepted('accepted', 'Angenommen'),
  declined('declined', 'Abgelehnt');

  const OrderStatus(this.value, this.label);
  final String value;
  final String label;

  static OrderStatus fromString(String? value) {
    return OrderStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => OrderStatus.quote,
    );
  }
}

/// Order source enum
enum OrderSource {
  app('app'),
  form('form');

  const OrderSource(this.value);
  final String value;

  static OrderSource fromString(String? value) {
    return OrderSource.values.firstWhere(
      (s) => s.value == value,
      orElse: () => OrderSource.app,
    );
  }
}

class SavedOrder {
  const SavedOrder({
    required this.id,
    required this.name,
    required this.date,
    required this.items,
    required this.total,
    required this.personCount,
    required this.drinkerType,
    required this.currency,
    required this.status,
    this.createdBy,
    this.createdAt,
    this.cocktails = const [],
    this.shots = const [],
    this.bar = '',
    this.distanceKm = 0,
    this.thekeCost = 0,
    this.offerTravelCostPerKm = 0.70,
    this.offerBarCost = 0,
    // Offer-related fields
    this.offerClientName = '',
    this.offerClientContact = '',
    this.offerEventTime = '',
    this.offerEventTypes = const [],
    this.offerDiscount = 0,
    this.offerDiscountRemark = '',
    this.offerLanguage = 'de',
    this.offerFirstPositionText = '',
    this.offerFirstPositionRemark = '',
    this.offerExtraPositions = const [],
    this.offerShotsCount = 0,
    this.offerShotsPricePerPiece = 1.50,
    this.offerShotsRemark = '',
    this.offerExtraHours = 0,
    this.offerExtraHourRate = 50.0,
    this.assignedEmployees = const [],
    // Form sync fields
    this.source = OrderSource.app,
    this.hasShoppingList = false,
    this.formSubmissionId = '',
    this.formCreatedAt,
    this.phone = '',
    this.location = '',
    this.eventTime = '',
    this.guestCountRange = '',
    this.mobileBar = false,
    this.eventType = '',
    this.serviceType = '',
    this.requestedCocktails = const [],
    this.isPendingDismissed = false,
    this.cocktailPopularity = const {},
    this.barDrinks = const [],
    this.alcoholPurchase = const [],
    this.additionalServices = const [],
    this.remarks = '',
  });

  final String id;
  final String name;
  final DateTime date;
  final List<Map<String, dynamic>> items;
  final double total;
  final int personCount;
  final String drinkerType;
  final String currency;
  final OrderStatus status;
  final String? createdBy;
  final DateTime? createdAt;
  final List<String> cocktails;
  final List<String> shots;
  final String bar;
  final int distanceKm;
  final double thekeCost;
  final double offerTravelCostPerKm;
  final double offerBarCost;
  // Offer-related fields
  final String offerClientName;
  final String offerClientContact;
  final String offerEventTime;
  final List<String> offerEventTypes;
  final double offerDiscount;
  final String offerDiscountRemark;
  final String offerLanguage;
  final String offerFirstPositionText;
  final String offerFirstPositionRemark;
  final List<Map<String, dynamic>> offerExtraPositions;
  final int offerShotsCount;
  final double offerShotsPricePerPiece;
  final String offerShotsRemark;
  final int offerExtraHours;
  final double offerExtraHourRate;
  final List<String> assignedEmployees;
  // Form sync fields
  final OrderSource source;
  final bool hasShoppingList;
  final String formSubmissionId;
  final DateTime? formCreatedAt;
  final String phone;
  final String location;
  final String eventTime;
  final String guestCountRange;
  final bool mobileBar;
  final String eventType;
  final String serviceType;

  /// Cocktails requested in the form submission (from Excel column 15).
  final List<String> requestedCocktails;

  /// If true, this pending order (total == 0) is dismissed from pending list.
  final bool isPendingDismissed;

  /// Popularity/probability percentage for each cocktail (0-100).
  /// Key: cocktail name, Value: popularity percentage.
  final Map<String, double> cocktailPopularity;

  /// Selected bar drinks categories (e.g., "Bier", "Wein", "Softdrinks")
  final List<String> barDrinks;

  /// Selected alcohol items for purchase (e.g., "Wodka", "Chivas")
  final List<String> alcoholPurchase;

  /// Selected additional services (e.g., "360 Booth", "PhotoBox Classic")
  final List<String> additionalServices;

  /// Free-form remarks/notes for additional services
  final String remarks;

  int get year => date.year;

  bool get isAccepted => status == OrderStatus.accepted;

  bool get isFromForm => source == OrderSource.form;

  bool get needsShoppingList => isFromForm && !hasShoppingList;

  factory SavedOrder.fromFirestore(String id, Map<String, dynamic> data) {
    // Helper to parse datetime from either Timestamp or String
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      // Firestore Timestamp has toDate() method
      if (value is Map && value['_seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (value['_seconds'] as int) * 1000,
        );
      }
      // Try calling toDate() if it's a Timestamp object
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return SavedOrder(
      id: id,
      name: data['name'] as String? ?? '',
      date: data['date'] != null
          ? DateTime.tryParse(data['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      total: (data['total'] as num?)?.toDouble() ?? 0,
      personCount: (data['personCount'] as num?)?.toInt() ?? 0,
      drinkerType: data['drinkerType'] as String? ?? 'normal',
      currency: data['currency'] as String? ?? 'CHF',
      status: OrderStatus.fromString(data['status'] as String?),
      createdBy: data['createdBy'] as String?,
      createdAt: parseDateTime(data['createdAt']),
      cocktails: (data['cocktails'] as List<dynamic>?)?.cast<String>() ?? [],
      shots: (data['shots'] as List<dynamic>?)?.cast<String>() ?? [],
      bar: data['bar'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toInt() ?? 0,
      thekeCost: (data['thekeCost'] as num?)?.toDouble() ?? 0,
      offerTravelCostPerKm:
          (data['offerTravelCostPerKm'] as num?)?.toDouble() ?? 0.70,
      offerBarCost: (data['offerBarCost'] as num?)?.toDouble() ?? 0,
      // Offer-related fields
      offerClientName: data['offerClientName'] as String? ?? '',
      offerClientContact: data['offerClientContact'] as String? ?? '',
      offerEventTime: data['offerEventTime'] as String? ?? '',
      offerEventTypes:
          (data['offerEventTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      offerDiscount: (data['offerDiscount'] as num?)?.toDouble() ?? 0,
      offerDiscountRemark: data['offerDiscountRemark'] as String? ?? '',
      offerLanguage: data['offerLanguage'] as String? ?? 'de',
      offerFirstPositionText: data['offerFirstPositionText'] as String? ?? '',
      offerFirstPositionRemark:
          data['offerFirstPositionRemark'] as String? ?? '',
      offerExtraPositions:
          (data['offerExtraPositions'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      offerShotsCount: (data['offerShotsCount'] as num?)?.toInt() ?? 0,
      offerShotsPricePerPiece:
          (data['offerShotsPricePerPiece'] as num?)?.toDouble() ?? 1.50,
      offerShotsRemark: data['offerShotsRemark'] as String? ?? '',
      offerExtraHours: (data['offerExtraHours'] as num?)?.toInt() ?? 0,
      offerExtraHourRate:
          (data['offerExtraHourRate'] as num?)?.toDouble() ?? 50.0,
      assignedEmployees:
          (data['assignedEmployees'] as List<dynamic>?)?.cast<String>() ?? [],
      // Form sync fields
      source: OrderSource.fromString(data['source'] as String?),
      // hasShoppingList is true if explicitly set, or if items/total exist
      hasShoppingList:
          ((data['hasShoppingList'] as bool?) ?? false) ||
          (data['items'] as List<dynamic>? ?? []).isNotEmpty ||
          ((data['total'] as num?)?.toDouble() ?? 0) > 0,
      formSubmissionId: data['formSubmissionId'] as String? ?? '',
      formCreatedAt: parseDateTime(data['formCreatedAt']),
      phone: data['phone'] as String? ?? '',
      location: data['location'] as String? ?? '',
      eventTime: data['eventTime'] as String? ?? '',
      guestCountRange: data['guestCountRange'] as String? ?? '',
      mobileBar: data['mobileBar'] as bool? ?? false,
      eventType: data['eventType'] as String? ?? '',
      serviceType: data['serviceType'] as String? ?? '',
      requestedCocktails:
          (data['requestedCocktails'] as List<dynamic>?)?.cast<String>() ?? [],
      isPendingDismissed: data['isPendingDismissed'] as bool? ?? false,
      cocktailPopularity:
          (data['cocktailPopularity'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      barDrinks: (data['barDrinks'] as List<dynamic>?)?.cast<String>() ?? [],
      alcoholPurchase:
          (data['alcoholPurchase'] as List<dynamic>?)?.cast<String>() ?? [],
      additionalServices:
          (data['additionalServices'] as List<dynamic>?)?.cast<String>() ?? [],
      remarks: data['remarks'] as String? ?? '',
    );
  }
}
