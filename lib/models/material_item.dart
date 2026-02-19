class MaterialItem {
  const MaterialItem({
    required this.unit,
    required this.name,
    required this.price,
    required this.currency,
    required this.note,
    this.sortOrder,
  });

  final String unit;
  final String name;
  final double price;
  final String currency;
  final String note;

  /// Manual sort position for fixed-value (Verbrauch) items. Null means unsorted.
  final int? sortOrder;

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      unit: (json['unit'] ?? json['menge']) as String,
      name: (json['name'] ?? json['artikel']) as String,
      price: ((json['price'] ?? json['preis']) as num).toDouble(),
      currency: (json['currency'] ?? json['waehrung']) as String,
      note: (json['note'] ?? json['bemerkung']) as String,
      sortOrder: json['sortOrder'] as int?,
    );
  }
}
