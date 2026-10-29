import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../ui/widgets/pressable.dart';

/// Notice that AI suggestions were applied; tap toggles the explanation,
/// "Rückgängig" clears all quantities, the cross hides the notice.
class AiSuggestionBanner extends StatelessWidget {
  const AiSuggestionBanner({
    super.key,
    required this.count,
    required this.explanation,
    required this.expanded,
    required this.onToggle,
    required this.onUndo,
    required this.onClose,
  });

  final int count;
  final String explanation;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onUndo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: FloatingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: AppSize.rowIcon, color: p.gold),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Pressable(
                    minSize: AppSize.minTap,
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.s8,
                      ),
                      child: Text(
                        'shopping.claude_suggestions_applied'.tr(
                          namedArgs: {'count': '$count'},
                        ),
                        style: AppText.button.copyWith(color: p.text),
                      ),
                    ),
                  ),
                ),
                Pressable(
                  minSize: AppSize.minTap,
                  radius: AppRadius.pill,
                  semanticLabel: 'common.close'.tr(),
                  onTap: onClose,
                  child: SizedBox.square(
                    dimension: AppSize.minTap,
                    child: Icon(
                      Icons.close,
                      size: AppSize.rowIcon,
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (explanation.isNotEmpty)
              Text(
                explanation,
                style: AppText.body.copyWith(color: p.textSecondary),
                maxLines: expanded ? null : 2,
                overflow: expanded ? null : TextOverflow.ellipsis,
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextAction(label: 'common.undo'.tr(), onPressed: onUndo),
            ),
          ],
        ),
      ),
    );
  }
}
