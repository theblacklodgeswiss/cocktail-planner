class Order {
  const Order({
    required this.id,
    required this.name,
    required this.date,
    required this.items,
    required this.total,
    required this.personCount,
    required this.drinkerType,
    this.createdBy,
  });

  final String id;
  final String name;
  final DateTime date;
  final List<Map<String, dynamic>> items;
  final double total;
  final int personCount;
  final String drinkerType;
  final String? createdBy;

  int get year => date.year;

  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    return Order(
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
      createdBy: data['createdBy'] as String?,
    );
  }
}
