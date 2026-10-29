import 'dart:math';

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
    bool? originExplicit,
    String? id,
  }) : originExplicit = originExplicit ?? parsed.originHint != null,
       id = id ?? newRestLineId();

  /// Stable id of the line, created with it (idempotent movement ids).
  final String id;

  /// The origin was said ("Investition", "Auftrag") or picked by hand. A
  /// count without it sets "Auftrag" to the counted rest (see
  /// [planCountLine]).
  bool originExplicit;

  final ParsedLine parsed;
  final List<CatalogMatch> candidates;

  /// Null until the match is confident or the user picked an item.
  String? chosenMaterialId;
  String? chosenMaterialName;
  StorageLocation location;
  StockOrigin origin;

  /// Negative while the typed quantity is invalid.
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

final _random = Random.secure();

/// Random 16-hex-digit id for a new line.
String newRestLineId() => [
  for (var i = 0; i < 8; i++)
    _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();

/// Deterministic movement id of a standalone "Dazu" line, so a retry after
/// a commit whose response got lost cannot book it twice.
String manualMovementId(RestLine line) =>
    'manual|${line.id}|${line.chosenMaterialId}|${line.location.id}|'
    '${line.origin.name}';

/// Quantity rule per mode: a count may be 0 ("0 Bacardi" = empty), an
/// addition must be more than 0.
bool isValidLineQuantity(double quantity, CaptureMode mode) =>
    mode == CaptureMode.count ? quantity >= 0 : quantity > 0;

/// Current quantity of [material] at [locationId] for [origin].
double stockOf(
  List<StockEntry> entries,
  String material,
  String locationId,
  StockOrigin origin,
) {
  final id = StockEntry.buildId(material, locationId, origin);
  var sum = 0.0;
  for (final e in entries) {
    if (StockEntry.buildId(e.materialId, e.locationId, e.origin) == id) {
      sum += e.quantity;
    }
  }
  return sum;
}

enum CountProblem {
  /// Without an origin, the count is below the investment stock.
  belowInvestment,

  /// Another line counts the same article at the same location.
  duplicate,
}

/// What a count line does at its location: before and after per origin,
/// and the writes needed (only origins that change).
class CountPlan {
  const CountPlan({
    required this.oldOrder,
    required this.oldInvestment,
    required this.newOrder,
    required this.newInvestment,
    this.problem,
  });

  final double oldOrder;
  final double oldInvestment;
  final double newOrder;
  final double newInvestment;
  final CountProblem? problem;

  double get oldTotal => oldOrder + oldInvestment;
  double get newTotal => newOrder + newInvestment;
  bool get valid => problem == null;

  /// setQuantity calls: changed origins only (no no-op corrections).
  List<(StockOrigin, double)> get writes => [
    if ((newOrder - oldOrder).abs() > 1e-9) (StockOrigin.order, newOrder),
    if ((newInvestment - oldInvestment).abs() > 1e-9)
      (StockOrigin.investment, newInvestment),
  ];
}

/// A count states what is physically at the location:
/// - with an [origin] said or picked, exactly that origin is set;
/// - without one, "Auftrag" becomes counted − current "Investition" (the
///   investment stock stays); a count below the investment stock is
///   invalid ([CountProblem.belowInvestment]).
/// [duplicate] marks the line invalid as well.
CountPlan planCountLine({
  required double counted,
  StockOrigin? origin,
  required double currentOrder,
  required double currentInvestment,
  bool duplicate = false,
}) {
  var newOrder = currentOrder;
  var newInvestment = currentInvestment;
  CountProblem? problem;
  switch (origin) {
    case StockOrigin.order:
      newOrder = counted;
    case StockOrigin.investment:
      newInvestment = counted;
    case null:
      if (counted < currentInvestment - 1e-9) {
        problem = CountProblem.belowInvestment;
      } else {
        newOrder = counted - currentInvestment;
      }
  }
  return CountPlan(
    oldOrder: currentOrder,
    oldInvestment: currentInvestment,
    newOrder: newOrder,
    newInvestment: newInvestment,
    problem: duplicate ? CountProblem.duplicate : problem,
  );
}

/// Count lines that clash: the same article at the same location, unless
/// both name different origins explicitly ("2 Bacardi Auftrag, 1 Bacardi
/// Investition" is fine). Unresolved lines never clash.
Set<RestLine> countDuplicates(List<RestLine> lines) {
  final clash = <RestLine>{};
  for (var i = 0; i < lines.length; i++) {
    for (var j = i + 1; j < lines.length; j++) {
      final a = lines[i];
      final b = lines[j];
      if (a.chosenMaterialId == null ||
          a.chosenMaterialId != b.chosenMaterialId ||
          a.location.id != b.location.id) {
        continue;
      }
      final distinct =
          a.originExplicit && b.originExplicit && a.origin != b.origin;
      if (!distinct) clash.addAll([a, b]);
    }
  }
  return clash;
}

/// [planCountLine] for a resolved [line] against the [stock] snapshot.
CountPlan planCountFor(
  RestLine line,
  List<StockEntry> stock, {
  bool duplicate = false,
}) {
  final material = line.chosenMaterialId ?? '';
  return planCountLine(
    counted: line.quantity,
    origin: line.originExplicit ? line.origin : null,
    currentOrder: stockOf(stock, material, line.location.id, StockOrigin.order),
    currentInvestment: stockOf(
      stock,
      material,
      line.location.id,
      StockOrigin.investment,
    ),
    duplicate: duplicate,
  );
}
