import '../../models/stock.dart';

/// One article of the inventory table. Totals are computed, never stored.
class InventoryRow {
  const InventoryRow({
    required this.materialId,
    required this.materialName,
    required this.perLocation,
    required this.total,
    this.note,
  });

  final String materialId;
  final String materialName;

  /// Quantity per location id and origin. Every known location is present
  /// with both origins (0 if nothing is stocked).
  final Map<String, Map<StockOrigin, double>> perLocation;
  final double total;
  final String? note;
}

/// Groups stock entries by article. Entries of articles missing from
/// [catalog] (renamed or deleted) are kept, using their stored name.
/// Catalog articles without stock get a row of zeros.
List<InventoryRow> buildInventoryRows(
  List<StockEntry> entries,
  List<StorageLocation> locations, {
  List<({String id, String name})> catalog = const [],
}) {
  final names = <String, String>{for (final c in catalog) c.id: c.name};
  final byMaterial = <String, List<StockEntry>>{};
  for (final e in entries) {
    byMaterial.putIfAbsent(e.materialId, () => []).add(e);
  }
  for (final c in catalog) {
    byMaterial.putIfAbsent(c.id, () => []);
  }

  final rows = <InventoryRow>[];
  byMaterial.forEach((id, list) {
    final perLocation = <String, Map<StockOrigin, double>>{
      for (final l in locations)
        l.id: {for (final o in StockOrigin.values) o: 0.0},
    };
    var total = 0.0;
    String? note;
    for (final e in list) {
      final cell = perLocation.putIfAbsent(
        e.locationId,
        () => {for (final o in StockOrigin.values) o: 0.0},
      );
      cell[e.origin] = (cell[e.origin] ?? 0) + e.quantity;
      total += e.quantity;
      final n = e.note?.trim();
      if (note == null && n != null && n.isNotEmpty) note = n;
    }
    final name =
        names[id] ??
        list
            .map((e) => e.materialName)
            .firstWhere((n) => n.isNotEmpty, orElse: () => id);
    rows.add(
      InventoryRow(
        materialId: id,
        materialName: name,
        perLocation: perLocation,
        total: total,
        note: note,
      ),
    );
  });
  rows.sort((a, b) {
    final byKey = inventorySortKey(
      a.materialName,
    ).compareTo(inventorySortKey(b.materialName));
    return byKey != 0 ? byKey : a.materialName.compareTo(b.materialName);
  });
  return rows;
}

const _folds = {
  'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', 'å': 'a', //
  'ö': 'o', 'ò': 'o', 'ó': 'o', 'ô': 'o', //
  'ü': 'u', 'ù': 'u', 'ú': 'u', 'û': 'u', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ß': 's', 'ç': 'c', 'ñ': 'n',
};

/// Lower case, trimmed, without diacritics ("Ärger" -> "arger").
String foldInventoryName(String name) {
  final lower = name.trim().toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    out.write(_folds[ch] ?? ch);
  }
  return out.toString();
}

/// Sort key of the inventory: letters A-Z (umlauts with their base letter)
/// first, then everything else (digits, symbols) as one block at the end.
String inventorySortKey(String name) {
  final folded = foldInventoryName(name);
  final letter = folded.isNotEmpty && RegExp('[a-z]').hasMatch(folded[0]);
  return '${letter ? 0 : 1}$folded';
}

/// German formatting: comma, no trailing ",0" for whole numbers. Rounded to
/// two decimals to hide floating point noise (2.8 + 10).
String formatQuantity(double q) {
  final r = (q * 100).round() / 100;
  final text = r == r.truncateToDouble() ? r.toInt().toString() : r.toString();
  return text.replaceAll('.', ',');
}

/// Parses a user-entered quantity (comma or dot). Returns null for empty,
/// garbage, negative or non-finite input, and for 0 unless [allowZero].
double? parseQuantity(String text, {required bool allowZero}) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value.isNaN || value.isInfinite || value < 0) {
    return null;
  }
  if (value == 0 && !allowZero) return null;
  return value;
}

/// Short readable reference for an order id (first 6 characters).
String shortOrderId(String id) => id.length <= 6 ? id : id.substring(0, 6);
