import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a stock quantity came from: bought for an order or invested.
enum StockOrigin {
  order,
  investment;

  /// Unknown or missing values fall back to [StockOrigin.order].
  static StockOrigin fromString(String? value) {
    switch (value) {
      case 'investment':
        return StockOrigin.investment;
      case 'order':
      default:
        return StockOrigin.order;
    }
  }
}

/// Numbers may arrive as int, double or (hand-edited / imported) as text
/// with a comma or dot; anything else counts as 0.
double _toDouble(dynamic value) {
  if (value is num) return value.isFinite ? value.toDouble() : 0;
  if (value is String) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed != null && parsed.isFinite ? parsed : 0;
  }
  return 0;
}

/// Text field that tolerates other types (e.g. a number in a note).
String? _str(dynamic value) {
  if (value == null) return null;
  return value is String ? value : value.toString();
}

/// Timestamp, DateTime or epoch millis; anything else is epoch 0.
DateTime _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// A physical place where stock is kept.
class StorageLocation {
  const StorageLocation({
    required this.id,
    required this.name,
    this.ownerEmail,
  });

  final String id;
  final String name;
  final String? ownerEmail;

  factory StorageLocation.fromMap(String id, Map<String, dynamic> map) {
    return StorageLocation(
      id: id,
      name: _str(map['name']) ?? '',
      ownerEmail: _str(map['ownerEmail']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (ownerEmail != null) 'ownerEmail': ownerEmail,
      };
}

/// Quantity of one material at one location for one origin.
class StockEntry {
  const StockEntry({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.locationId,
    required this.origin,
    required this.quantity,
    this.note,
  });

  final String id;
  final String materialId;
  final String materialName;
  final String locationId;
  final StockOrigin origin;
  final double quantity;
  final String? note;

  /// Document ID: one entry per material, location and origin.
  static String buildId(
    String materialId,
    String locationId,
    StockOrigin origin,
  ) =>
      '$materialId|$locationId|${origin.name}';

  factory StockEntry.fromMap(String id, Map<String, dynamic> map) {
    return StockEntry(
      id: id,
      materialId: _str(map['materialId']) ?? '',
      materialName: _str(map['materialName']) ?? '',
      locationId: _str(map['locationId']) ?? '',
      origin: StockOrigin.fromString(_str(map['origin'])),
      quantity: _toDouble(map['quantity']),
      note: _str(map['note']),
    );
  }

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'materialName': materialName,
        'locationId': locationId,
        'origin': origin.name,
        'quantity': quantity,
        if (note != null) 'note': note,
      };
}

/// Append-only log entry for a stock change.
/// [reason]: rest, manual (standalone capture), take, correction, import or
/// order_deduction.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.materialId,
    required this.locationId,
    required this.origin,
    required this.delta,
    required this.reason,
    this.orderId,
    required this.byEmail,
    required this.at,
  });

  final String id;
  final String materialId;
  final String locationId;
  final StockOrigin origin;
  final double delta;
  final String reason;
  final String? orderId;
  final String byEmail;
  final DateTime at;

  factory StockMovement.fromMap(String id, Map<String, dynamic> map) {
    return StockMovement(
      id: id,
      materialId: _str(map['materialId']) ?? '',
      locationId: _str(map['locationId']) ?? '',
      origin: StockOrigin.fromString(_str(map['origin'])),
      delta: _toDouble(map['delta']),
      reason: _str(map['reason']) ?? '',
      orderId: _str(map['orderId']),
      byEmail: _str(map['byEmail']) ?? '',
      at: _toDate(map['at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'locationId': locationId,
        'origin': origin.name,
        'delta': delta,
        'reason': reason,
        if (orderId != null) 'orderId': orderId,
        'byEmail': byEmail,
        'at': Timestamp.fromDate(at),
      };
}
