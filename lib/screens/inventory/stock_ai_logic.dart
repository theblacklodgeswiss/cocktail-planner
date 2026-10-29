import 'dart:math';

import '../../models/material_item.dart';
import '../../models/stock.dart';
import '../../services/stock_ai_interpreter.dart';
import '../../services/voice_inventory_parser.dart';
import 'rest_lines.dart';

/// Pure decisions of the Claude-assisted capture: which result to show,
/// how AI lines become confirmation lines and the deterministic
/// plausibility warnings.

/// Below this confidence an AI match is offered, not pre-selected.
const stockAiConfidentThreshold = 0.6;

StockAiMode stockAiModeOf(CaptureMode mode) =>
    mode == CaptureMode.count ? StockAiMode.count : StockAiMode.add;

/// Deterministic warnings shown as chips. Never blockers.
enum PlausibilityFlag {
  /// Dazu: more than max(10, 5 × total stock); Zählung: the total at the
  /// location changes by more than max(10, 3 × old).
  unusuallyHigh,

  /// No article chosen and more than one candidate.
  notUnique,

  /// The article has no stock anywhere yet.
  noStockYet,

  /// Zählung without origin below the Investition stock.
  belowInvestment;

  String get key => switch (this) {
    unusuallyHigh => 'inventory_list.flag_high',
    notUnique => 'inventory_list.flag_not_unique',
    noStockYet => 'inventory_list.flag_no_stock',
    belowInvestment => 'inventory_list.flag_below_investment',
  };
}

double _totalOf(List<StockEntry> stock, String materialId) => stock
    .where((e) => e.materialId == materialId)
    .fold<double>(0, (s, e) => s + e.quantity);

/// Plausibility of [line] against the [stock] snapshot in [mode].
List<PlausibilityFlag> plausibilityFlags(
  RestLine line,
  List<StockEntry> stock,
  CaptureMode mode,
) {
  final material = line.chosenMaterialId;
  if (material == null) {
    return [if (line.candidates.length > 1) PlausibilityFlag.notUnique];
  }
  final total = _totalOf(stock, material);
  final flags = <PlausibilityFlag>[];
  var below = false;
  if (line.quantity >= 0) {
    if (mode == CaptureMode.add) {
      if (line.quantity > max(10, 5 * total)) {
        flags.add(PlausibilityFlag.unusuallyHigh);
      }
    } else {
      final plan = planCountFor(line, stock);
      below = plan.problem == CountProblem.belowInvestment;
      final old = plan.oldTotal;
      if ((plan.newTotal - old).abs() > max(10, 3 * old)) {
        flags.add(PlausibilityFlag.unusuallyHigh);
      }
    }
  }
  if (total <= 0) flags.add(PlausibilityFlag.noStockYet);
  if (below) flags.add(PlausibilityFlag.belowInvestment);
  return flags;
}

enum AiStatus { skipped, failed, ok }

/// What happened with the AI for one tap on "Weiter".
class AiAttempt {
  /// Not configured or switched off: never called.
  const AiAttempt.skipped() : status = AiStatus.skipped, result = null;

  /// Called, but error, timeout or an invalid answer.
  const AiAttempt.failed() : status = AiStatus.failed, result = null;

  const AiAttempt.ok(StockAiResult this.result) : status = AiStatus.ok;

  final AiStatus status;
  final StockAiResult? result;
}

class InterpretChoice {
  const InterpretChoice({required this.useAi, required this.fallbackHint});

  /// Show the AI lines (else the rule lines).
  final bool useAi;

  /// Show "Ohne KI ausgewertet": the AI was tried and did not help.
  final bool fallbackHint;
}

/// AI lines when the AI answered with lines; otherwise the rule result,
/// with a hint when the AI was tried but failed or found nothing the rules
/// found.
InterpretChoice chooseInterpretation(AiAttempt ai, ParseResult rules) {
  final rulesFound = rules.lines.isNotEmpty || rules.unparsed.isNotEmpty;
  switch (ai.status) {
    case AiStatus.skipped:
      return const InterpretChoice(useAi: false, fallbackHint: false);
    case AiStatus.failed:
      return const InterpretChoice(useAi: false, fallbackHint: true);
    case AiStatus.ok:
      if (ai.result!.lines.isNotEmpty) {
        return const InterpretChoice(useAi: true, fallbackHint: false);
      }
      return InterpretChoice(useAi: false, fallbackHint: rulesFound);
  }
}

/// Turns validated AI lines into confirmation lines. A line is only
/// pre-selected when the AI named a known article with enough confidence;
/// otherwise it keeps the candidates/pick flow of an unsure rule match.
List<RestLine> buildAiRestLines(
  StockAiResult result,
  List<(String id, MaterialItem item)> catalog,
  StorageLocation defaultLocation,
) {
  final names = {for (final (id, item) in catalog) id: item.name};
  CatalogMatch match(String id, double score) =>
      CatalogMatch(materialId: id, name: names[id]!, score: score);

  return [
    for (final ai in result.lines)
      () {
        final confident =
            ai.materialId != null &&
            ai.confidence >= stockAiConfidentThreshold;
        final ids = [?ai.materialId, ...ai.candidateIds];
        final candidates = ids.isNotEmpty
            ? [for (final id in ids) match(id, ai.confidence)]
            : matchCatalog(ai.spokenText, catalog);
        final unresolved = ai.location == null && ai.locationHint != null;
        return RestLine(
          parsed: ParsedLine(
            quantity: ai.quantity ?? -1,
            spokenName: ai.spokenText,
            locationHint: ai.locationHint,
            originHint: ai.origin,
          ),
          candidates: candidates,
          chosenMaterialId: confident ? ai.materialId : null,
          chosenMaterialName: confident ? names[ai.materialId] : null,
          location: ai.location ?? defaultLocation,
          origin: ai.origin ?? StockOrigin.order,
          quantity: ai.quantity ?? -1,
          locationUnresolved: unresolved,
          fromAi: true,
          aiNote: ai.note,
        );
      }(),
  ];
}
