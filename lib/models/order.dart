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
    // Offer-related fields
    this.offerClientName = '',
    this.offerClientContact = '',
    this.offerEventTime = '',
    this.offerEventTypes = const [],
    this.offerDiscount = 0,
    this.offerLanguage = 'de',
    this.offerExtraPositions = const [],
    this.assignedEmployees = const [],
    // Form sync fields
    this.source = OrderSource.app,
    this.hasShoppingList = false,
    this.formSubmissionId = '',
    this.formCreatedAt,
    this.phone = '',
    this.location = '',
    this.guestCountRange = '',
    this.mobileBar = false,
    this.eventType = '',
    this.serviceType = '',
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
  // Offer-related fields
  final String offerClientName;
  final String offerClientContact;
  final String offerEventTime;
  final List<String> offerEventTypes;
  final double offerDiscount;
  final String offerLanguage;
  final List<Map<String, dynamic>> offerExtraPositions;
  final List<String> assignedEmployees;
  // Form sync fields
  final OrderSource source;
  final bool hasShoppingList;
  final String formSubmissionId;
  final DateTime? formCreatedAt;
  final String phone;
  final String location;
  final String guestCountRange;
  final bool mobileBar;
  final String eventType;
  final String serviceType;

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
      // Offer-related fields
      offerClientName: data['offerClientName'] as String? ?? '',
      offerClientContact: data['offerClientContact'] as String? ?? '',
      offerEventTime: data['offerEventTime'] as String? ?? '',
      offerEventTypes: (data['offerEventTypes'] as List<dynamic>?)?.cast<String>() ?? [],
      offerDiscount: (data['offerDiscount'] as num?)?.toDouble() ?? 0,
      offerLanguage: data['offerLanguage'] as String? ?? 'de',
      offerExtraPositions: (data['offerExtraPositions'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
      assignedEmployees: (data['assignedEmployees'] as List<dynamic>?)?.cast<String>() ?? [],
      // Form sync fields
      source: OrderSource.fromString(data['source'] as String?),
      // hasShoppingList is true if explicitly set, or if items/total exist
      hasShoppingList: ((data['hasShoppingList'] as bool?) ?? false) ||
          (data['items'] as List<dynamic>? ?? []).isNotEmpty ||
          ((data['total'] as num?)?.toDouble() ?? 0) > 0,
      formSubmissionId: data['formSubmissionId'] as String? ?? '',
      formCreatedAt: parseDateTime(data['formCreatedAt']),
      phone: data['phone'] as String? ?? '',
      location: data['location'] as String? ?? '',
      guestCountRange: data['guestCountRange'] as String? ?? '',
      mobileBar: data['mobileBar'] as bool? ?? false,
      eventType: data['eventType'] as String? ?? '',
      serviceType: data['serviceType'] as String? ?? '',
    );
  }
}
