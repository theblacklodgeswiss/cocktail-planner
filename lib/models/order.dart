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
    );
  }
}
