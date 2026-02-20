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

  int get year => date.year;
  
  bool get isAccepted => status == OrderStatus.accepted;

  factory SavedOrder.fromFirestore(String id, Map<String, dynamic> data) {
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
    );
  }
}
