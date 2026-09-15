/// A single priced option within an [AdditionalService] (e.g. "inkl. 300
/// Druck" vs. "Digital mit QR-Code" for a PhotoBox).
///
/// [price] is nullable: `null` means "Preis auf Anfrage" (price on request).
class ServiceVariant {
  const ServiceVariant({
    required this.id,
    required this.name,
    this.price,
  });

  final String id;
  final String name;
  final double? price;

  factory ServiceVariant.fromMap(Map<String, dynamic> map) => ServiceVariant(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (price != null) 'price': price,
      };
}

/// An admin-managed additional service offered on the order form (e.g.
/// "BlackLodge PhotoBox"), with one or more priced [variants] the customer
/// picks exactly one of.
class AdditionalService {
  const AdditionalService({
    required this.id,
    required this.name,
    this.imageUrl,
    this.sortOrder = 0,
    this.variants = const [],
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final int sortOrder;
  final List<ServiceVariant> variants;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory AdditionalService.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return AdditionalService(
      id: id,
      name: data['name'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      sortOrder: data['sortOrder'] as int? ?? 0,
      variants: (data['variants'] as List<dynamic>? ?? [])
          .whereType<Object?>()
          .map((v) => v is Map
              ? ServiceVariant.fromMap(Map<String, dynamic>.from(v))
              : null)
          .whereType<ServiceVariant>()
          .toList(),
      createdAt: (data['createdAt'] as dynamic)?.toDate(),
      createdBy: data['createdBy'] as String?,
      updatedAt: (data['updatedAt'] as dynamic)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        'sortOrder': sortOrder,
        'variants': variants.map((v) => v.toMap()).toList(),
      };

  /// Looks up a variant by its id, or null if this service has none with
  /// that id (e.g. it was removed since an order referenced it).
  ServiceVariant? variantById(String variantId) {
    for (final variant in variants) {
      if (variant.id == variantId) return variant;
    }
    return null;
  }
}
