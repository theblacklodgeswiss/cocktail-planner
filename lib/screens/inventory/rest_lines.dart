import '../../models/material_item.dart';
import '../../models/stock.dart';
import '../../services/voice_inventory_parser.dart';

/// One editable line of the rest confirmation view.
class RestLine {
  RestLine({
    required this.parsed,
    required this.candidates,
    required this.location,
    required this.origin,
    required this.quantity,
    this.chosenMaterialId,
    this.chosenMaterialName,
    this.locationUnresolved = false,
  });

  final ParsedLine parsed;
  final List<CatalogMatch> candidates;

  /// Null until the match is confident or the user picked an item.
  String? chosenMaterialId;
  String? chosenMaterialName;
  StorageLocation location;
  StockOrigin origin;
  double quantity;

  /// The spoken location hint matched no known location.
  bool locationUnresolved;
}

/// Turns parsed lines into confirmation lines. Only a confident catalog match
/// is pre-selected; the location hint falls back to [defaultLocation].
List<RestLine> buildRestLines(
  List<ParsedLine> parsed,
  List<(String id, MaterialItem item)> catalog,
  List<StorageLocation> locations,
  StorageLocation defaultLocation,
) {
  return parsed.map((p) {
    final candidates = matchCatalog(p.spokenName, catalog);
    final confident = isConfident(candidates);
    var location = defaultLocation;
    var unresolved = false;
    final hint = p.locationHint?.trim().toLowerCase();
    if (hint != null && hint.isNotEmpty) {
      final hit = locations.where((l) => l.name.trim().toLowerCase() == hint);
      if (hit.isNotEmpty) {
        location = hit.first;
      } else {
        unresolved = true;
      }
    }
    return RestLine(
      parsed: p,
      candidates: candidates,
      chosenMaterialId: confident ? candidates.first.materialId : null,
      chosenMaterialName: confident ? candidates.first.name : null,
      location: location,
      origin: p.originHint ?? StockOrigin.order,
      quantity: p.quantity,
      locationUnresolved: unresolved,
    );
  }).toList();
}

/// Once any line is booked, going back would rebuild the lines and book them
/// again, so the confirmation view is locked.
bool mustLockRest(int bookedCount) => bookedCount > 0;

/// Closing after a partial save must still mark the rest as recorded: part of
/// it is in stock already, so redoing it later would double-book.
bool shouldMarkRecordedOnClose(int bookedCount) => bookedCount > 0;

/// How the capture sheet books its lines.
enum CaptureMode {
  /// Adds the quantities to the stock ("Dazu", movement with + delta).
  add,

  /// Sets the stock to the counted quantities ("Zählung", correction).
  count,
}

/// Stock entry id a resolved [line] books into, or null while no article is
/// chosen.
String? restLineKey(RestLine line) {
  final id = line.chosenMaterialId;
  if (id == null) return null;
  return StockEntry.buildId(id, line.location.id, line.origin);
}

/// Counted quantity per stock entry id: lines that end up in the same entry
/// (same article, location and origin) are summed, so "2 Bacardi, 1 Bacardi"
/// counts 3. Unresolved lines are left out.
Map<String, double> countTargets(List<RestLine> lines) {
  final targets = <String, double>{};
  for (final line in lines) {
    final key = restLineKey(line);
    if (key == null) continue;
    targets[key] = (targets[key] ?? 0) + line.quantity;
  }
  return targets;
}

/// Current stock of the entry [line] books into (0 if none exists).
double currentQuantityFor(RestLine line, List<StockEntry> entries) {
  final key = restLineKey(line);
  if (key == null) return 0;
  var sum = 0.0;
  for (final e in entries) {
    if (StockEntry.buildId(e.materialId, e.locationId, e.origin) == key) {
      sum += e.quantity;
    }
  }
  return sum;
}
