import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';
import '../../state/app_state.dart';

/// Dialog to review and confirm Gemini material suggestions before applying them
class GeminiMaterialReviewDialog extends StatefulWidget {
  const GeminiMaterialReviewDialog({
    super.key,
    required this.suggestion,
    required this.personCount,
    required this.cocktailNames,
    required this.onConfirm,
  });

  final GeminiMaterialSuggestion suggestion;
  final int personCount;
  final List<String> cocktailNames;
  final void Function(List<MaterialSuggestion>, String explanation) onConfirm;

  @override
  State<GeminiMaterialReviewDialog> createState() =>
      _GeminiMaterialReviewDialogState();
}

class _GeminiMaterialReviewDialogState
    extends State<GeminiMaterialReviewDialog> {
  late Map<String, int> _editableMaterials;
  late Map<String, String> _materialReasons;

  @override
  void initState() {
    super.initState();
    _editableMaterials = {};
    _materialReasons = {};
    for (final material in widget.suggestion.materials) {
      _editableMaterials[material.key] = material.quantity;
      _materialReasons[material.key] = material.reason;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(child: Text('orders.gemini_material_suggestions'.tr())),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'orders.guests'.tr()}: ${widget.personCount}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (widget.cocktailNames.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${'orders.requested_cocktails'.tr()}: ${widget.cocktailNames.join(", ")}',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reasoning
              if (widget.suggestion.explanation.isNotEmpty) ...[
                Text(
                  'orders.gemini_reasoning'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.suggestion.explanation,
                  style: TextStyle(fontSize: 13, color: colorScheme.outline),
                ),
                const SizedBox(height: 16),
              ],

              // Suggested materials header
              Row(
                children: [
                  Text(
                    'orders.suggested_materials'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_editableMaterials.length} ${'orders.items'.tr()}',
                    style: TextStyle(color: colorScheme.outline, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Material list
              ..._editableMaterials.entries.map((entry) {
                final parts = entry.key.split('|');
                final name = parts[0];
                final unit = parts.length > 1 ? parts[1] : '';
                final reason = _materialReasons[entry.key] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (unit.isNotEmpty)
                                    Text(
                                      unit,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 20,
                              onPressed: () {
                                setState(() {
                                  if (entry.value > 1) {
                                    _editableMaterials[entry.key] =
                                        entry.value - 1;
                                  } else {
                                    _editableMaterials.remove(entry.key);
                                    _materialReasons.remove(entry.key);
                                  }
                                });
                              },
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                '${entry.value}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 20,
                              onPressed: () {
                                setState(() {
                                  _editableMaterials[entry.key] =
                                      entry.value + 1;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              iconSize: 20,
                              color: colorScheme.error,
                              onPressed: () {
                                setState(() {
                                  _editableMaterials.remove(entry.key);
                                  _materialReasons.remove(entry.key);
                                });
                              },
                            ),
                          ],
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.outline,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton.icon(
          onPressed: _editableMaterials.isEmpty
              ? null
              : () {
                  // Convert to MaterialSuggestion list
                  final suggestions = _editableMaterials.entries.map((entry) {
                    final parts = entry.key.split('|');
                    return MaterialSuggestion(
                      name: parts[0],
                      unit: parts.length > 1 ? parts[1] : '',
                      quantity: entry.value,
                      reason: _materialReasons[entry.key] ?? '',
                    );
                  }).toList();

                  widget.onConfirm(suggestions, widget.suggestion.explanation);
                  Navigator.pop(context);
                },
          icon: const Icon(Icons.check),
          label: Text('orders.apply_suggestions'.tr()),
        ),
      ],
    );
  }
}
