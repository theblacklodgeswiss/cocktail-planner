import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../utils/currency.dart';

/// Header widget for shopping list screen.
class ShoppingHeader extends StatelessWidget {
  const ShoppingHeader({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.hasSelectedItems,
    required this.onExport,
    required this.totalCost,
    required this.currency,
  });

  final int currentPage;
  final int totalPages;
  final bool hasSelectedItems;
  final VoidCallback onExport;
  final double totalCost;
  final Currency currency;

  bool get _isLastPage => currentPage == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
            icon: const Icon(Icons.arrow_back),
            tooltip: 'dashboard.title'.tr(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile) ...[
                  // Mobile: Stack vertically
                  Text(
                    'shopping.title'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currency.format(totalCost),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'shopping.step_of'.tr(namedArgs: {
                          'current': '${currentPage + 1}',
                          'total': '$totalPages'
                        }),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Desktop: Horizontal layout
                  Row(
                    children: [
                      Text(
                        'shopping.title'.tr(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          currency.format(totalCost),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'shopping.step_of'.tr(namedArgs: {
                      'current': '${currentPage + 1}',
                      'total': '$totalPages'
                    }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (_isLastPage) ...[
            if (isMobile)
              // Mobile: Icon-only button
              IconButton.filled(
                onPressed: hasSelectedItems ? onExport : null,
                icon: const Icon(Icons.save_alt, size: 20),
                tooltip: 'common.save_offer'.tr(),
              )
            else
              // Desktop: Full button with label
              FilledButton.icon(
                onPressed: hasSelectedItems ? onExport : null,
                icon: const Icon(Icons.save_alt, size: 18),
                label: Text('common.save_offer'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
