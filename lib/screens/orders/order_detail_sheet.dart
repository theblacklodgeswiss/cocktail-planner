import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/employee_repository.dart';
import '../../models/employee.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../utils/currency.dart';
import '../shopping_list/stock_logic.dart';
import 'detail/microsoft_integration.dart';
import 'detail/order_detail_controller.dart';
import 'detail/order_detail_logic.dart';
import 'detail/order_detail_services.dart';
import 'detail/shopping_actions.dart';
import 'order_shopping_list_page.dart';
import 'order_status_helpers.dart';
import 'widgets/order_info_chip.dart';

/// Shows the order details in a modal bottom sheet.
/// For form orders without a shopping list, starts the shopping list creation
/// flow with all available data pre-filled.
void showOrderDetails(BuildContext context, SavedOrder order) {
  if (order.isFromForm && !order.hasShoppingList) {
    appState.setPendingFormOrder(order);
    context.push('/order-form');
    return;
  }

  final colorScheme = Theme.of(context).colorScheme;
  final currency = Currency.fromCode(order.currency);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _OrderDetailSheet(
      order: order,
      colorScheme: colorScheme,
      currency: currency,
    ),
  );
}


class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({
    required this.order,
    required this.colorScheme,
    required this.currency,
  });

  final SavedOrder order;
  final ColorScheme colorScheme;
  final Currency currency;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet>
    implements OrderDetailHost {
  late final OrderDetailController _c;

  @override
  void initState() {
    super.initState();
    _c = OrderDetailController(
      order: widget.order,
      host: this,
      services: const OrderDetailServices(
        triggerMicrosoftIntegration: runMicrosoftIntegration,
      ),
    );
    _c.addListener(_onControllerChanged);
  }

  /// The whole sheet rebuilds on every controller change, exactly as the
  /// old `setState` calls did.
  void _onControllerChanged() => setState(() {});

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Scaffold(
        appBar: _buildAppBar(),
        body: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _buildActionButtons(),
            const SizedBox(height: 8),
            _buildStatusCard(),
            const SizedBox(height: 16),
            if (widget.order.isFromForm) ...[
              _buildFormDetailsCard(),
              const SizedBox(height: 16),
            ],
            _buildInfoCard(),
            const SizedBox(height: 16),
            if (widget.order.items.isNotEmpty) _buildShoppingListTile(),
            if (_c.actions.contains(OrderDetailAction.delete))
              _buildDeleteSection(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.order.name),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          
          if (isNarrow) {
            // Vertical layout for narrow screens
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _c.isOpeningOffer ? null : _c.openOfferEditor,
                    icon: _c.isOpeningOffer
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined),
                    label: Text('orders.finalize_offer'.tr()),
                  ),
                  if (_c.actions.contains(OrderDetailAction.invoice)) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _c.isOpeningInvoice ? null : _c.generateInvoice,
                      icon: _c.isOpeningInvoice
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.receipt_long),
                      label: Text('orders.invoice'.tr()),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildShoppingListSection(vertical: true),
                ],
              ),
            );
          } else {
            // Horizontal layout for wider screens
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: _c.isOpeningOffer ? null : _c.openOfferEditor,
                    icon: _c.isOpeningOffer
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.description_outlined),
                    label: Text('orders.finalize_offer'.tr()),
                  ),
                  if (_c.actions.contains(OrderDetailAction.invoice)) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _c.isOpeningInvoice ? null : _c.generateInvoice,
                      icon: _c.isOpeningInvoice
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.receipt_long),
                      label: Text('orders.invoice'.tr()),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildShoppingListSection(vertical: false),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildShoppingListSection({required bool vertical}) {
    final hasList = !widget.order.needsShoppingList;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.white54),
              SizedBox(width: 6),
              Text('Einkaufsliste', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          if (vertical) ...[
            if (hasList)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _c.isDownloadingPdf ? null : _c.downloadShoppingList,
                      icon: _c.isDownloadingPdf
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 15),
                      label: const Text('PDF', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _c.isDownloadingPdf ? null : _c.downloadShoppingListWithoutPrices,
                      icon: _c.isDownloadingPdf
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined, size: 15),
                      label: const Text('Ohne Preise', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _c.isEditingList ? null : _c.editShoppingList,
                      icon: _c.isEditingList
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit, size: 15),
                      label: const Text('Bearbeiten', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            if (hasList) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _c.isGeneratingList ? null : _c.generateWithGemini,
                icon: _c.isGeneratingList
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                label: Text('orders.regenerate_with_claude'.tr(), style: const TextStyle(color: Colors.white)),
                style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
              ),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasList) ...[
                  OutlinedButton.icon(
                    onPressed: _c.isDownloadingPdf ? null : _c.downloadShoppingList,
                    icon: _c.isDownloadingPdf
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 15),
                    label: const Text('PDF', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed:
                        _c.isDownloadingPdf ? null : _c.downloadShoppingListWithoutPrices,
                    icon: _c.isDownloadingPdf
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined, size: 15),
                    label: const Text('Ohne Preise', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: _c.isEditingList ? null : _c.editShoppingList,
                    icon: _c.isEditingList
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit, size: 15),
                    label: const Text('Bearbeiten', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                ],
                FilledButton.icon(
                  onPressed: _c.isGeneratingList ? null : _c.generateWithGemini,
                  icon: _c.isGeneratingList
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  label: Text('orders.regenerate_with_claude'.tr(), style: const TextStyle(color: Colors.white)),
                  style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final actions = _c.actions;

    return Card(
      color: statusColor(_c.currentStatus).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  statusIcon(_c.currentStatus),
                  color: statusColor(_c.currentStatus),
                ),
                const SizedBox(width: 8),
                Text(
                  '${"orders.status".tr()}: ${statusLabel(_c.currentStatus)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor(_c.currentStatus),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (actions.contains(OrderDetailAction.editDeclineReason)) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: _c.editDeclineReason,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _c.declineReason.isEmpty
                              ? 'orders.decline_reason_add'.tr()
                              : '${'orders.decline_reason'.tr()}: ${_c.declineReason}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontStyle: _c.declineReason.isEmpty
                                    ? FontStyle.italic
                                    : null,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 16),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Show "Complete Offer" button if offer is incomplete and status is quote
            if (actions.contains(OrderDetailAction.completeOffer)) ...[
              Text(
                'orders.offer_incomplete'.tr(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _c.isOpeningOffer ? null : _c.openOfferEditor,
                  icon: _c.isOpeningOffer
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.edit_document),
                  label: Text('orders.complete_offer'.tr()),
                  style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),
            ] else ...[
              if (actions.contains(OrderDetailAction.recordRest)) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _c.recordRest,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text('rest.record'.tr()),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'orders.change_status'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (actions.contains(OrderDetailAction.complete))
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _c.isUpdatingStatus
                            ? null
                            : () => _c.updateStatus(OrderStatus.completed),
                        icon: _c.isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified),
                        label: Text('orders.complete'.tr()),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                      ),
                    ),
                  if (actions.contains(OrderDetailAction.complete))
                    const SizedBox(width: 8),
                  if (actions.contains(OrderDetailAction.backToAccepted))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _c.isUpdatingStatus
                            ? null
                            : () => _c.updateStatus(OrderStatus.accepted),
                        icon: _c.isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.undo),
                        label: Text('orders.back_to_accepted'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    ),
                  if (actions.contains(OrderDetailAction.accept))
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: (!acceptBlockedByTotal(widget.order.total) &&
                                    !_c.isUpdatingStatus)
                                ? () => _c.tryUpdateStatus(OrderStatus.accepted)
                                : null,
                            icon: _c.isUpdatingStatus
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text('orders.accept'.tr()),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                          if (acceptBlockedByTotal(widget.order.total))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Erst Einkaufsliste erstellen',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: Colors.orange),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (actions.contains(OrderDetailAction.accept) &&
                      actions.contains(OrderDetailAction.decline))
                    const SizedBox(width: 8),
                  if (actions.contains(OrderDetailAction.decline))
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _c.isUpdatingStatus
                            ? null
                            : () => _c.updateStatus(OrderStatus.declined),
                        icon: _c.isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.close),
                        label: Text('orders.decline'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  if (actions.contains(OrderDetailAction.backToQuote)) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _c.isUpdatingStatus
                            ? null
                            : () => _c.updateStatus(OrderStatus.quote),
                        icon: _c.isUpdatingStatus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.undo),
                        label: Text('orders.status_quote'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormDetailsCard() {
    final order = widget.order;
    return Card(
      color: order.needsShoppingList
          ? Colors.orange.withValues(alpha: 0.1)
          : Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: order.needsShoppingList ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'orders.form_details'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: order.needsShoppingList
                        ? Colors.orange
                        : Colors.blue,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (order.needsShoppingList)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'orders.no_shopping_list'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFormDetailRow(
              Icons.phone,
              'orders.phone'.tr(),
              order.phone.isNotEmpty ? order.phone : '-',
            ),
            _buildFormDetailRow(
              Icons.location_on,
              'orders.location'.tr(),
              order.location.isNotEmpty ? order.location : '-',
            ),
            _buildFormDetailRow(
              Icons.people,
              'orders.guests'.tr(),
              order.guestCountRange.isNotEmpty ? order.guestCountRange : '-',
            ),
            _buildFormDetailRow(
              Icons.local_bar,
              'orders.mobile_bar'.tr(),
              order.mobileBar ? 'orders.yes'.tr() : 'orders.no'.tr(),
            ),
            _buildFormDetailRow(
              Icons.celebration,
              'orders.event_type'.tr(),
              order.eventType.isNotEmpty ? order.eventType : '-',
            ),
            _buildFormDetailRow(
              Icons.room_service,
              'orders.service_type'.tr(),
              order.serviceType.isNotEmpty ? order.serviceType : '-',
            ),
            if (order.needsShoppingList) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _c.isOpeningShoppingList ? null : _c.openShoppingList,
                      icon: _c.isOpeningShoppingList
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.shopping_cart),
                      label: Text('orders.create_shopping_list'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _c.isGeneratingList ? null : () => _c.generateWithGemini(),
                      icon: _c.isGeneratingList
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome, color: Colors.white),
                      label: Text('orders.generate_with_claude'.tr(), style: const TextStyle(color: Colors.white)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: widget.colorScheme.outline),
          const SizedBox(width: 8),
          Text('$label:', style: TextStyle(color: widget.colorScheme.outline)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: widget.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _c.editDate,
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatDate(_c.currentDate)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 14, color: widget.colorScheme.outline),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.currency.format(widget.order.total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OrderInfoChip(
                  icon: Icons.people,
                  label: '${widget.order.personCount} ${'orders.persons'.tr()}',
                  colorScheme: widget.colorScheme,
                ),
                const SizedBox(width: 8),
                OrderInfoChip(
                  icon: Icons.local_bar,
                  label: drinkerLabel(widget.order.drinkerType),
                  colorScheme: widget.colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _EmployeeAssignmentWidget(
              assignedEmployeeIds: _c.assignedEmployees,
              onAssignmentChanged: _c.updateAssignedEmployees,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoppingListTile() {
    final order = widget.order;
    final items = _c.itemsOverride ?? order.items;
    final total = customerTotal(items);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.shopping_cart_outlined),
        title: Text('orders.shopping_list_title'.tr()),
        subtitle: Text(
          '${order.items.length} ${'orders.articles'.tr()} • ${widget.currency.format(total)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final edit = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => OrderShoppingListPage(
                order: order,
                stockApplied: _c.stockApplied,
                items: items,
                onItemsChanged: (changed) => _c.itemsOverride = changed,
              ),
            ),
          );
          if (edit == true && mounted) _c.editShoppingList();
        },
      ),
    );
  }

  Widget _buildDeleteSection() {
    return Column(
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _c.deleteOrder,
            icon: const Icon(Icons.delete_forever),
            label: Text('orders.delete_order'.tr()),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ),
      ],
    );
  }

}

/// Widget for assigning employees to an order with multi-select chips
class _EmployeeAssignmentWidget extends StatefulWidget {
  const _EmployeeAssignmentWidget({
    required this.assignedEmployeeIds,
    required this.onAssignmentChanged,
  });

  final List<String> assignedEmployeeIds;
  final Function(List<String>) onAssignmentChanged;

  @override
  State<_EmployeeAssignmentWidget> createState() =>
      _EmployeeAssignmentWidgetState();
}

class _EmployeeAssignmentWidgetState extends State<_EmployeeAssignmentWidget> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.assignedEmployeeIds);
  }

  @override
  void didUpdateWidget(_EmployeeAssignmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignedEmployeeIds != widget.assignedEmployeeIds) {
      _selectedIds = Set.from(widget.assignedEmployeeIds);
    }
  }

  void _toggleEmployee(String employeeId) {
    setState(() {
      if (_selectedIds.contains(employeeId)) {
        _selectedIds.remove(employeeId);
      } else {
        _selectedIds.add(employeeId);
      }
    });
    widget.onAssignmentChanged(_selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Employee>>(
      stream: employeeRepository.watchEmployees(),
      builder: (context, snapshot) {
        final employees = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_ind,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'orders.assigned_employees'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (employees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'orders.no_employees_assigned'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 400;
                  return Wrap(
                    spacing: isSmall ? 6 : 8,
                    runSpacing: isSmall ? 6 : 8,
                    children: employees.map((employee) {
                      final isSelected = _selectedIds.contains(employee.name);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          employee.name,
                          style: TextStyle(fontSize: isSmall ? 12 : 14),
                        ),
                        avatar: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          child: Text(
                            employee.name.isNotEmpty
                                ? employee.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: isSmall ? 10 : 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        onSelected: (_) => _toggleEmployee(employee.name),
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

