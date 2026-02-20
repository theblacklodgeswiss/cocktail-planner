import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Bottom navigation bar for shopping list wizard.
class ShoppingBottomNav extends StatelessWidget {
  const ShoppingBottomNav({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.hasSelectedItems,
    required this.onBack,
    required this.onNext,
    required this.onExport,
  });

  final int currentPage;
  final int totalPages;
  final bool hasSelectedItems;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onExport;

  bool get _isLastPage => currentPage == totalPages - 1;
  bool get _isFirstPage => currentPage == 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBackButton(context),
          Expanded(child: _buildProgressDots(colorScheme)),
          _buildNextButton(context),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    if (_isFirstPage) {
      return const SizedBox(width: 100);
    }
    return TextButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back),
      label: Text('common.back'.tr()),
    );
  }

  Widget _buildProgressDots(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildNextButton(BuildContext context) {
    if (_isLastPage) {
      return FilledButton.icon(
        onPressed: hasSelectedItems ? onExport : null,
        icon: const Icon(Icons.picture_as_pdf),
        label: Text('common.pdf'.tr()),
      );
    }
    return FilledButton.icon(
      onPressed: onNext,
      icon: const Icon(Icons.arrow_forward),
      label: Text('common.next'.tr()),
    );
  }
}
