import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/buttons.dart';

/// Bottom area of the shopping list steps: back and next; on the last step
/// the next button becomes "Angebot speichern".
class ShoppingBottomNav extends StatelessWidget {
  const ShoppingBottomNav({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onBack,
    required this.onNext,
    this.onSave,
    this.isSaving = false,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback onBack;
  final VoidCallback onNext;

  /// Save action of the last step; null disables it (nothing selected).
  final VoidCallback? onSave;

  /// Shows a spinner on the save button and blocks further taps.
  final bool isSaving;

  bool get _isLastPage => currentPage == totalPages - 1;
  bool get _isFirstPage => currentPage == 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (!_isFirstPage) ...[
          Expanded(
            child: SecondaryButton(
              label: 'common.back'.tr(),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
        ],
        Expanded(
          child: _isLastPage
              ? PrimaryButton(
                  expand: true,
                  label: 'common.save_offer'.tr(),
                  onPressed: isSaving ? null : onSave,
                  loading: isSaving,
                )
              : PrimaryButton(
                  expand: true,
                  label: 'common.next'.tr(),
                  onPressed: onNext,
                ),
        ),
      ],
    );
  }
}
