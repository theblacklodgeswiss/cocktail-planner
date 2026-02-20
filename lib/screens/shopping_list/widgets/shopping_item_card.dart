import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/material_item.dart';
import '../../../utils/currency.dart';

/// A card widget displaying a material item with quantity controls.
class ShoppingItemCard extends StatelessWidget {
  const ShoppingItemCard({
    super.key,
    required this.item,
    required this.controller,
    required this.quantity,
    required this.isSelected,
    required this.cocktails,
    required this.onQuantityChanged,
    this.totalSelected = 0,
  });

  final MaterialItem item;
  final TextEditingController controller;
  final int quantity;
  final bool isSelected;
  final List<String> cocktails;
  final void Function(int newQuantity) onQuantityChanged;
  final int totalSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (totalSelected > 0) ...[
              _buildTotalBadge(context, colorScheme),
              const SizedBox(width: 12),
            ],
            Expanded(child: _buildItemInfo(context, colorScheme)),
            const SizedBox(width: 12),
            _buildQuantityStepper(context, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBadge(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          totalSelected.toString(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
        ),
      ),
    );
  }

  Widget _buildItemInfo(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${item.unit} • ${Currency.fromCode(item.currency).format(item.price)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
            if (item.note.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.note,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                ),
              ),
            ],
          ],
        ),
        if (cocktails.length > 1) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            children: cocktails
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontSize: 10,
                            ),
                      ),
                    ))
                .toList(),
          ),
        ],
        if (isSelected) ...[
          const SizedBox(height: 6),
          Text(
            Currency.fromCode(item.currency).format(item.price * quantity),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityStepper(BuildContext context, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.surface
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: quantity > 0
                ? () => onQuantityChanged(quantity - 1)
                : null,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 40,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintText: '0',
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onQuantityChanged(quantity + 1),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
