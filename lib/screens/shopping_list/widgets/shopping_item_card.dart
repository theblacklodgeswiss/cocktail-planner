import 'package:flutter/material.dart';

import '../../../models/material_item.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/floating_card.dart';
import '../../../utils/currency.dart';
import 'quantity_stepper.dart';

/// A card displaying a material item with quantity controls.
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
    final p = AppPalette.of(context);
    final currency = Currency.fromCode(item.currency);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: isSelected
              ? Border.all(color: p.primary, width: AppSize.hairline)
              : null,
        ),
        child: FloatingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (totalSelected > 0) ...[
                    _Badge(count: totalSelected),
                    const SizedBox(width: AppSpace.s12),
                  ],
                  Expanded(child: _Info(item: item, currency: currency)),
                ],
              ),
              if (cocktails.length > 1) ...[
                const SizedBox(height: AppSpace.s8),
                Wrap(
                  spacing: AppSpace.s4,
                  runSpacing: AppSpace.s4,
                  children: [for (final c in cocktails) _Chip(text: c)],
                ),
              ],
              const SizedBox(height: AppSpace.s8),
              Row(
                children: [
                  Expanded(
                    child: isSelected
                        ? Text(
                            currency.format(item.price * quantity),
                            style: AppText.number.copyWith(color: p.text),
                          )
                        : const SizedBox.shrink(),
                  ),
                  QuantityStepper(
                    controller: controller,
                    quantity: quantity,
                    onChanged: onQuantityChanged,
                    label: item.name,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: SizedBox.square(
        dimension: AppSize.optionIconBox,
        child: Center(
          child: Text(
            '$count',
            style: AppText.button.copyWith(color: p.onPrimary),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.item, required this.currency});

  final MaterialItem item;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: AppText.section.copyWith(color: p.text)),
        const SizedBox(height: AppSpace.s4),
        Text(
          '${item.unit} • ${currency.format(item.price)}'
          '${item.note.isEmpty ? '' : ' • ${item.note}'}',
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s4,
        ),
        child: Text(text, style: AppText.pill.copyWith(color: p.textSecondary)),
      ),
    );
  }
}
