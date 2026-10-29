import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/material_item.dart';
import '../../models/stock.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/hero_card.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/states.dart';
import '../../utils/currency.dart';
import '../inventory/inventory_rows.dart';
import '../shopping_list/stock_logic.dart';

/// Read-only view of an order's shopping list. All state and side effects
/// (saving the source, loading stock) live in the page that owns this view.
///
/// Staff (`staff`) additionally see, per item, the Laden/Lager switch and the
/// internal cost; customers never do. After [applied] (stock booked) the
/// switch is locked and the internal cost is replaced by a note.
class OrderShoppingListView extends StatelessWidget {
  const OrderShoppingListView({
    super.key,
    required this.items,
    required this.currency,
    required this.staff,
    required this.applied,
    required this.saving,
    required this.entries,
    required this.locations,
    required this.catalog,
    required this.ownLocationId,
    required this.onSetSource,
    required this.onBack,
    required this.onEdit,
  });

  final List<Map<String, dynamic>> items;
  final Currency currency;
  final bool staff;
  final bool applied;
  final bool saving;
  final List<StockEntry> entries;
  final List<StorageLocation> locations;
  final List<({String id, MaterialItem item})> catalog;
  final String? ownLocationId;
  final void Function(int index, ItemSource source) onSetSource;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final total = customerTotal(items);
    final internalTotal = items.fold<double>(
      0,
      (sum, item) => sum + itemInternalCost(item, entries, catalog),
    );
    final showInternal = staff && !applied;

    return LargeTitleScaffold(
      title: 'orders.shopping_list_title'.tr(),
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpace.s4),
        child: GlassIconButton(
          icon: Icons.arrow_back,
          semanticLabel: 'ui.back'.tr(),
          onPressed: onBack,
        ),
      ),
      bottomBar: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s8,
          AppSpace.s16,
          AppSpace.s12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: PrimaryButton(
          label: 'orders.edit_shopping_list'.tr(),
          onPressed: onEdit,
        ),
      ),
      slivers: [
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'shopping_ui.no_items'.tr(),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                0,
                AppSpace.s16,
                AppSpace.s12,
              ),
              child: HeroCard(
                kicker: 'orders.shopping_list_total'.tr(),
                title: currency.format(total),
                titleStyle: AppText.display,
                meta: [
                  '${items.length} ${'orders.articles'.tr()}',
                  if (showInternal)
                    '${'orders.internal_cost_total'.tr()}: '
                        '${currency.format(internalTotal)}',
                ].join(' · '),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s8),
              itemBuilder: (context, i) => FloatingCard(
                key: Key('shopping-item-$i'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ItemRow(item: items[i], currency: currency),
                    if (staff) ...[
                      const SizedBox(height: AppSpace.s8),
                      _SourceRow(
                        index: i,
                        item: items[i],
                        currency: currency,
                        applied: applied,
                        saving: saving,
                        entries: entries,
                        locations: locations,
                        catalog: catalog,
                        ownLocationId: ownLocationId,
                        onSetSource: onSetSource,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.currency});

  final Map<String, dynamic> item;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final note = item['note'] as String? ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSize.optionIconBox,
              minHeight: AppSize.optionIconBox,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Text(
                  '${quantity}x',
                  style: AppText.button.copyWith(color: p.text),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] as String? ?? '',
                style: AppText.section.copyWith(color: p.text),
              ),
              Text(
                '${item['unit'] as String? ?? ''} • ${currency.format(price)}'
                '${note.isEmpty ? '' : ' • $note'}',
                style: AppText.body.copyWith(color: p.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        Text(
          currency.format(price * quantity),
          style: AppText.number.copyWith(color: p.text),
        ),
      ],
    );
  }
}

/// Laden/Lager switch on its own row, then location, availability and cost.
class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.index,
    required this.item,
    required this.currency,
    required this.applied,
    required this.saving,
    required this.entries,
    required this.locations,
    required this.catalog,
    required this.ownLocationId,
    required this.onSetSource,
  });

  final int index;
  final Map<String, dynamic> item;
  final Currency currency;
  final bool applied;
  final bool saving;
  final List<StockEntry> entries;
  final List<StorageLocation> locations;
  final List<({String id, MaterialItem item})> catalog;
  final String? ownLocationId;
  final void Function(int index, ItemSource source) onSetSource;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final source = ItemSource.fromItem(item);
    final materialId = resolveMaterialId(item, catalog);
    final canStock = materialId != null && locations.isNotEmpty;
    final locationId = source.locationId;
    final selected = locations.any((l) => l.id == locationId)
        ? locationId
        : null;
    final available = selected != null && materialId != null
        ? availableAt(entries, materialId, selected)
        : null;
    final cost = itemInternalCost(item, entries, catalog);
    final caption = AppText.body.copyWith(color: p.textSecondary);
    final canToggle = canToggleSource(
      canStock: canStock,
      isStock: source.isStock,
      saving: saving,
      stockApplied: applied,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              label: 'shopping_ui.source_row'.tr(),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'orders.source_shop'.tr(),
                      style: AppText.body.copyWith(color: p.text),
                    ),
                  ),
                  Switch(
                    key: Key('source-switch-$index'),
                    value: source.isStock,
                    onChanged: canToggle
                        ? (on) {
                            if (!on) {
                              onSetSource(index, const ItemSource.shop());
                              return;
                            }
                            if (!canStock) return;
                            final first =
                                locations.any((l) => l.id == ownLocationId)
                                ? ownLocationId!
                                : locations.first.id;
                            onSetSource(index, ItemSource.stock(first));
                          }
                        : null,
                  ),
                  Flexible(
                    child: Text(
                      'orders.source_stock'.tr(),
                      style: AppText.body.copyWith(color: p.text),
                    ),
                  ),
                ],
              ),
            ),
            if (source.isStock)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.minTap),
                child: DropdownButton<String>(
                  key: Key('source-location-$index'),
                  isExpanded: true,
                  value: selected,
                  hint: Text('orders.source_location'.tr()),
                  items: [
                    for (final l in locations)
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: saving || applied
                      ? null
                      : (id) {
                          if (id != null) {
                            onSetSource(index, ItemSource.stock(id));
                          }
                        },
                ),
              ),
            if (!canStock)
              Text(
                materialId == null
                    ? 'orders.source_unresolved'.tr()
                    : 'orders.source_no_location'.tr(),
                style: caption,
              ),
            if (available != null)
              Text(
                'orders.source_available'.tr(
                  namedArgs: {
                    'order': formatQuantity(available.order),
                    'investment': formatQuantity(available.investment),
                  },
                ),
                style: caption,
              ),
            // After booking, the cost would be recomputed from the current
            // stock and be misleading, so it is hidden with a note instead.
            if (applied)
              Text(
                'orders.stock_already_booked'.tr(),
                key: Key('locked-note-$index'),
                style: caption,
              )
            else
              Text(
                '${'orders.internal_cost'.tr()}: ${currency.format(cost)}',
                key: Key('internal-cost-$index'),
                style: caption,
              ),
          ],
        ),
      ),
    );
  }
}
