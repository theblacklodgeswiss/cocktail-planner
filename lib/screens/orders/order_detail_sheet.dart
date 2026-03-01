import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/cocktail_repository.dart';
import '../../data/employee_repository.dart';
import '../../data/order_repository.dart';
import '../../models/employee.dart';
import '../../models/order.dart';
import '../../models/recipe.dart';
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import '../../services/invoice_pdf_generator.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/pdf_generator.dart';
import '../../state/app_state.dart';
import '../../utils/currency.dart';
import '../../widgets/order_setup_dialog.dart';
import 'order_status_helpers.dart';
import 'widgets/order_info_chip.dart';

/// Shows the order details in a modal bottom sheet.
void showOrderDetails(BuildContext context, SavedOrder order) {
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

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  late OrderStatus _currentStatus;
  late List<String> _assignedEmployees;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
    _assignedEmployees = List.from(widget.order.assignedEmployees);
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    // If accepting, show confirmation dialog first
    if (newStatus == OrderStatus.accepted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('invoice.confirm_save_title'.tr()),
          content: Text('invoice.confirm_save_msg'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final success = await orderRepository.updateStatus(widget.order.id, newStatus.value);
    if (success && mounted) {
      setState(() => _currentStatus = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('orders.status_changed'
              .tr(namedArgs: {'status': statusLabel(newStatus)})),
        ),
      );
      // Trigger Microsoft integration when status becomes accepted
      if (newStatus == OrderStatus.accepted) {
        _triggerMicrosoftIntegration();
      }
    }
  }

  Future<void> _updateAssignedEmployees(List<String> employeeIds) async {
    final success = await orderRepository.updateAssignedEmployees(
      widget.order.id,
      employeeIds,
    );
    if (success && mounted) {
      setState(() => _assignedEmployees = employeeIds);
    }
  }

  /// Navigate to shopping list to edit the existing order
  Future<void> _editShoppingList() async {
    final order = widget.order;
    
    // Parse eventTime from string
    TimeOfDay? eventTime;
    if (order.eventTime.isNotEmpty) {
      try {
        final parts = order.eventTime.split(':');
        if (parts.length == 2) {
          eventTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (e) {
        debugPrint('Failed to parse event time: $e');
      }
    }
    
    // Convert SavedOrder to OrderSetupData
    final orderSetup = OrderSetupData(
      orderName: order.name,
      phoneNumber: order.phone.isNotEmpty ? order.phone : null,
      eventDate: order.date,
      eventTime: eventTime,
      address: order.location.isNotEmpty ? order.location : null,
      personCount: order.personCount,
      distanceKm: order.distanceKm > 0 ? order.distanceKm : null,
      currency: order.currency,
      drinkerType: order.drinkerType,
    );
    
    // Load cocktail data to get recipe ingredients
    try {
      final cocktailData = await cocktailRepository.load();
      
      // Link this order so it gets updated instead of creating a new one
      appState.setLinkedOrder(
        order.id,
        order.name,
        requestedCocktails: order.requestedCocktails,
        savedItems: order.items,
      );
      
      // Set selected recipes from the order's cocktails and shots with real ingredients
      final allRecipes = <Recipe>[];
      
      for (final cocktailName in order.cocktails) {
        // Try to find recipe in loaded data
        final recipe = cocktailData.recipes.firstWhere(
          (r) => r.name == cocktailName,
          orElse: () => Recipe(
            id: cocktailName.toLowerCase().replaceAll(' ', '_'),
            name: cocktailName,
            ingredients: [],
            type: 'cocktail',
          ),
        );
        allRecipes.add(recipe);
      }
      
      for (final shotName in order.shots) {
        // Try to find recipe in loaded data
        final recipe = cocktailData.recipes.firstWhere(
          (r) => r.name == shotName,
          orElse: () => Recipe(
            id: shotName.toLowerCase().replaceAll(' ', '_'),
            name: shotName,
            ingredients: [],
            type: 'shot',
          ),
        );
        allRecipes.add(recipe);
      }
      
      if (allRecipes.isNotEmpty) {
        appState.setSelectedRecipes(allRecipes);
      }
      
      // Navigate to shopping list
      if (mounted) {
        Navigator.pop(context);
        context.push('/shopping-list', extra: orderSetup);
      }
    } catch (e) {
      debugPrint('Failed to load cocktail data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden der Daten: $e')),
        );
      }
    }
  }

  /// Check if offer has all required fields filled
  bool _isOfferComplete() {
    return widget.order.offerClientName.isNotEmpty &&
        widget.order.offerClientContact.isNotEmpty &&
        widget.order.offerEventTime.isNotEmpty &&
        widget.order.offerEventTypes.isNotEmpty;
  }

  /// Show message that offer needs to be completed first
  void _showOfferIncompleteMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('orders.offer_incomplete'.tr()),
        action: SnackBarAction(
          label: 'orders.complete_offer'.tr(),
          onPressed: () {
            Navigator.pop(context);
            context.push('/create-offer', extra: widget.order);
          },
        ),
      ),
    );
  }

  /// Try to update status, but check if offer is complete first (for accepting)
  void _tryUpdateStatus(OrderStatus newStatus) {
    if (newStatus == OrderStatus.accepted && !_isOfferComplete()) {
      _showOfferIncompleteMessage();
      return;
    }
    _updateStatus(newStatus);
  }

  Future<void> _triggerMicrosoftIntegration() async {
    if (!microsoftGraphService.isSupported) return;

    final statusNotifier = ValueNotifier<String>('orders.ms_step_generating_shopping_list'.tr());
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<String>(
            valueListenable: statusNotifier,
            builder: (_, status, child) => Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(status)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Fetch fresh order data to get the current event date
      final freshOrder = await orderRepository.getOrderById(widget.order.id);
      final order = freshOrder ?? widget.order;
      
      final safeName = order.name.replaceAll(' ', '_');
      final dateTag = '${order.date.year}${order.date.month.toString().padLeft(2, '0')}${order.date.day.toString().padLeft(2, '0')}';
      String? einkaufslisteUrl;
      String? auftragsbestaetigungUrl;
      
      // 1. Generate Einkaufsliste (Shopping List) PDF
      final shoppingListBytes = await PdfGenerator.generateBytesFromSavedOrder(order);
      final shoppingListFileName = 'Einkaufsliste_${safeName}_$dateTag.pdf';
      
      // 2. Upload Einkaufsliste to OneDrive
      statusNotifier.value = 'orders.ms_step_uploading_shopping_list'.tr();
      final shoppingListPath = MicrosoftGraphService.buildOneDrivePath(
        rootFolder: 'Aufträge',
        date: order.date,
        fileName: shoppingListFileName,
      );
      einkaufslisteUrl = await microsoftGraphService.uploadToOneDrive(
        oneDrivePath: shoppingListPath,
        bytes: shoppingListBytes,
      );
      
      // 3. Generate Auftragsbestätigung (Order Confirmation) PDF
      statusNotifier.value = 'orders.ms_step_generating_invoice'.tr();
      final invoiceBytes = await InvoicePdfGenerator.generateBytes(order);
      final invoiceFileName = InvoicePdfGenerator.getFilename(order);
      
      // 4. Upload Auftragsbestätigung to OneDrive
      statusNotifier.value = 'orders.ms_step_uploading_invoice'.tr();
      final invoicePath = MicrosoftGraphService.buildOneDrivePath(
        rootFolder: 'Aufträge',
        date: order.date,
        fileName: invoiceFileName,
      );
      auftragsbestaetigungUrl = await microsoftGraphService.uploadToOneDrive(
        oneDrivePath: invoicePath,
        bytes: invoiceBytes,
      );
      
      // 5. Create calendar event with document links
      statusNotifier.value = 'orders.ms_step_creating_calendar'.tr();
      
      // Parse event time (e.g. "17:30") and combine with date
      DateTime eventStart = order.date;
      if (order.offerEventTime.isNotEmpty) {
        final timeParts = order.offerEventTime.split(':');
        if (timeParts.length >= 2) {
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          eventStart = DateTime(
            order.date.year,
            order.date.month,
            order.date.day,
            hour,
            minute,
          );
        }
      }
      final eventEnd = eventStart.add(const Duration(hours: 5));
      final employeeNames = _assignedEmployees.isNotEmpty
          ? _assignedEmployees.join(', ')
          : 'TBD';
      
      // Build event body with document links
      final bodyLines = <String>[
        'Auftrag: ${order.name}',
        'Personen: ${order.personCount}',
        'Mitarbeiter: $employeeNames',
        'Gesamtbetrag: ${Currency.fromCode(order.currency).format(order.total)}',
        '',
        '--- Dokumente ---',
      ];
      if (einkaufslisteUrl != null) {
        bodyLines.add('Einkaufsliste: $einkaufslisteUrl');
      }
      if (auftragsbestaetigungUrl != null) {
        bodyLines.add('Auftragsbestätigung: $auftragsbestaetigungUrl');
      }
      
      final eventId = await microsoftGraphService.createCalendarEvent(
        subject: order.name,
        start: eventStart,
        end: eventEnd,
        bodyContent: bodyLines.join('\n'),
      );
      
      // 6. Add PDF attachments to calendar event
      if (eventId != null && eventId != 'unknown') {
        statusNotifier.value = 'orders.ms_step_adding_attachments'.tr();
        await microsoftGraphService.addCalendarAttachment(
          eventId: eventId,
          fileName: shoppingListFileName,
          bytes: shoppingListBytes,
        );
        await microsoftGraphService.addCalendarAttachment(
          eventId: eventId,
          fileName: invoiceFileName,
          bytes: invoiceBytes,
        );
      }
      
      final uploadSuccess = einkaufslisteUrl != null || auftragsbestaetigungUrl != null;
      final calendarSuccess = eventId != null;
      
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted && (uploadSuccess || calendarSuccess)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('orders.microsoft_integration_success'.tr())),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('orders.microsoft_integration_failed'.tr())),
        );
      }
    } catch (e) {
      debugPrint('Microsoft integration error: $e');
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('orders.microsoft_integration_failed'.tr())),
        );
      }
    }
  }

  Future<void> _generateInvoice() async {
    // Navigate to the CreateInvoiceScreen instead of generating directly
    Navigator.pop(context);
    context.push('/create-invoice', extra: widget.order);
  }

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('orders.delete_confirm_title'.tr()),
        content: Text('orders.delete_confirm_message'
            .tr(namedArgs: {'name': widget.order.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await orderRepository.deleteOrder(widget.order.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'orders.deleted'.tr()
                : 'orders.delete_failed'.tr()),
          ),
        );
      }
    }
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
            _buildStatusCard(),
            const SizedBox(height: 16),
            if (widget.order.isFromForm) ...[
              _buildFormDetailsCard(),
              const SizedBox(height: 16),
            ],
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildItemsHeader(),
            const SizedBox(height: 8),
            ..._buildItemsList(),
            if (AuthService().isSuperAdmin) _buildDeleteSection(),
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
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.push('/create-offer', extra: widget.order);
          },
          icon: const Icon(Icons.description_outlined),
          label: Text('orders.offer'.tr()),
        ),
        if (_currentStatus == OrderStatus.accepted)
          TextButton.icon(
            onPressed: _generateInvoice,
            icon: const Icon(Icons.receipt_long),
            label: Text('orders.invoice'.tr()),
          ),
        if (!widget.order.needsShoppingList)
          TextButton.icon(
            onPressed: _editShoppingList,
            icon: const Icon(Icons.edit),
            label: Text('common.edit'.tr()),
          ),
        FilledButton.icon(
          onPressed: () async {
            await PdfGenerator.generateFromSavedOrder(widget.order);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('orders.pdf_created'.tr())),
              );
            }
          },
          icon: const Icon(Icons.shopping_cart),
          label: Text('orders.shopping_list'.tr()),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatusCard() {
    final isComplete = _isOfferComplete();
    
    return Card(
      color: statusColor(_currentStatus).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon(_currentStatus),
                    color: statusColor(_currentStatus)),
                const SizedBox(width: 8),
                Text(
                  '${"orders.status".tr()}: ${statusLabel(_currentStatus)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor(_currentStatus),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Show "Complete Offer" button if offer is incomplete and status is quote
            if (!isComplete && _currentStatus == OrderStatus.quote) ...[
              Text('orders.offer_incomplete'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                  )),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/create-offer', extra: widget.order);
                  },
                  icon: const Icon(Icons.edit_document),
                  label: Text('orders.complete_offer'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
            ] else ...[
              Text('orders.change_status'.tr(),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_currentStatus != OrderStatus.accepted)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _tryUpdateStatus(OrderStatus.accepted),
                        icon: const Icon(Icons.check),
                        label: Text('orders.accept'.tr()),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  if (_currentStatus != OrderStatus.accepted &&
                      _currentStatus != OrderStatus.declined)
                    const SizedBox(width: 8),
                  if (_currentStatus != OrderStatus.declined)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateStatus(OrderStatus.declined),
                        icon: const Icon(Icons.close),
                        label: Text('orders.decline'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  if (_currentStatus != OrderStatus.quote) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateStatus(OrderStatus.quote),
                        icon: const Icon(Icons.undo),
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
                    color: order.needsShoppingList ? Colors.orange : Colors.blue,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (order.needsShoppingList)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
                      onPressed: () {
                        // Link this order to the shopping list with requested cocktails
                        appState.setLinkedOrder(
                          order.id,
                          order.name,
                          requestedCocktails: order.requestedCocktails,
                        );
                        Navigator.pop(context);
                        context.go('/');
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: Text('orders.create_shopping_list'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showGeminiSuggestions(order),
                      icon: const Icon(Icons.auto_awesome),
                      label: Text('orders.generate_with_gemini'.tr()),
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
          Text(
            '$label:',
            style: TextStyle(color: widget.colorScheme.outline),
          ),
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
                Icon(Icons.calendar_today,
                    size: 16, color: widget.colorScheme.outline),
                const SizedBox(width: 8),
                Text(formatDate(widget.order.date)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  label:
                      '${widget.order.personCount} ${'orders.persons'.tr()}',
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
              assignedEmployeeIds: _assignedEmployees,
              onAssignmentChanged: _updateAssignedEmployees,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsHeader() {
    return Text(
      '${widget.order.items.length} ${'orders.articles'.tr()}',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  List<Widget> _buildItemsList() {
    return widget.order.items.map((item) {
      final name = item['name'] as String? ?? '';
      final unit = item['unit'] as String? ?? '';
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final note = item['note'] as String? ?? '';
      final total = price * quantity;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: widget.colorScheme.primaryContainer,
            child: Text(
              '${quantity}x',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          title: Text(name),
          subtitle: Text(
              '$unit • ${widget.currency.format(price)}${note.isNotEmpty ? ' • $note' : ''}'),
          trailing: Text(
            widget.currency.format(total),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }).toList();
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
            onPressed: _deleteOrder,
            icon: const Icon(Icons.delete_forever),
            label: Text('orders.delete_order'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showGeminiSuggestions(SavedOrder order) async {
    // Check if Gemini API is configured
    if (!geminiService.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.gemini_not_configured'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('orders.gemini_generating'.tr()),
          ],
        ),
      ),
    );

    try {
      // Fetch cocktails and materials for the order
      final cocktailData = await cocktailRepository.load();
      final materials = cocktailData.materials
          .where((m) => m.visible)
          .map((m) => {
            'name': m.name,
            'unit': m.unit,
            'price': m.price,
            'currency': m.currency,
          })
          .toList();
      
      // Get recipe ingredients for the requested cocktails
      final matchedRecipes = <Recipe>[];
      final unmatchedNames = <String>[];
      
      // First try exact match (case-insensitive)
      for (final cocktailName in order.requestedCocktails) {
        final lower = cocktailName.toLowerCase().trim();
        final recipe = cocktailData.recipes.firstWhere(
          (r) => r.name.toLowerCase().trim() == lower,
          orElse: () => Recipe(id: '', name: '', ingredients: [], type: ''),
        );
        if (recipe.id.isNotEmpty && !matchedRecipes.any((r) => r.id == recipe.id)) {
          matchedRecipes.add(recipe);
        } else if (recipe.id.isEmpty) {
          unmatchedNames.add(cocktailName);
        }
      }
      
      // Use Gemini AI for fuzzy matching of unmatched names
      if (unmatchedNames.isNotEmpty && geminiService.isConfigured) {
        try {
          final availableNames = cocktailData.recipes.map((r) => r.name).toList();
          final aiMatches = await geminiService.matchCocktailNames(
            requestedNames: unmatchedNames,
            availableRecipeNames: availableNames,
          );
          
          for (final entry in aiMatches.entries) {
            final matchedName = entry.value;
            if (matchedName != null) {
              final recipe = cocktailData.recipes.firstWhere(
                (r) => r.name == matchedName,
                orElse: () => Recipe(id: '', name: '', ingredients: [], type: ''),
              );
              if (recipe.id.isNotEmpty && !matchedRecipes.any((r) => r.id == recipe.id)) {
                matchedRecipes.add(recipe);
              }
            }
          }
        } catch (e) {
          debugPrint('Gemini cocktail matching failed: $e');
        }
      }
      
      final recipeIngredients = matchedRecipes
          .map((r) => {
            'cocktail': r.name,
            'ingredients': r.ingredients,
          })
          .toList();
      
      // Generate material suggestions
      final suggestion = await geminiService.generateMaterialSuggestions(
        guestCount: order.personCount,
        guestRange: order.guestCountRange,
        requestedCocktails: order.requestedCocktails,
        eventType: order.eventType,
        drinkerType: order.drinkerType,
        availableMaterials: materials,
        recipeIngredients: recipeIngredients,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (suggestion == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('orders.gemini_error'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show material suggestion review dialog
      if (mounted) {
        _showMaterialSuggestionDialog(order, suggestion, matchedRecipes);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('orders.gemini_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMaterialSuggestionDialog(
    SavedOrder order,
    GeminiMaterialSuggestion suggestion,
    List<Recipe> matchedRecipes,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _GeminiMaterialDialog(
        order: order,
        suggestion: suggestion,
        onConfirm: (confirmedMaterials, explanation) {
          // Convert to MaterialSuggestion and store in app state
          final suggestions = confirmedMaterials.entries.map((e) {
            final parts = e.key.split('|');
            return MaterialSuggestion(
              name: parts[0],
              unit: parts.length > 1 ? parts[1] : '',
              quantity: e.value,
              reason: '',
            );
          }).toList();
          
          // Set selected recipes FIRST (before navigating)
          if (matchedRecipes.isNotEmpty) {
            appState.setSelectedRecipes(matchedRecipes);
          }
          
          appState.setLinkedOrder(
            order.id,
            order.name,
            requestedCocktails: order.requestedCocktails,
          );
          appState.setMaterialSuggestions(suggestions, explanation);
          Navigator.pop(context);
          context.go('/');
        },
      ),
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

class _EmployeeAssignmentWidgetState
    extends State<_EmployeeAssignmentWidget> {
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
                Icon(Icons.assignment_ind,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'orders.assigned_employees'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (employees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'orders.no_employees_assigned'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
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
                          style: TextStyle(
                            fontSize: isSmall ? 12 : 14,
                          ),
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
                        selectedColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        checkmarkColor:
                            Theme.of(context).colorScheme.primary,
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

/// Dialog to review and confirm Gemini material suggestions
class _GeminiMaterialDialog extends StatefulWidget {
  const _GeminiMaterialDialog({
    required this.order,
    required this.suggestion,
    required this.onConfirm,
  });

  final SavedOrder order;
  final GeminiMaterialSuggestion suggestion;
  final void Function(Map<String, int> materials, String explanation) onConfirm;

  @override
  State<_GeminiMaterialDialog> createState() => _GeminiMaterialDialogState();
}

class _GeminiMaterialDialogState extends State<_GeminiMaterialDialog> {
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
        width: 500,
        height: 500,
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
                      '${'orders.guests'.tr()}: ${widget.order.personCount}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (widget.order.requestedCocktails.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${'orders.requested_cocktails'.tr()}: ${widget.order.requestedCocktails.join(", ")}',
                        style: TextStyle(color: colorScheme.outline),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${'orders.event_type'.tr()}: ${widget.order.eventType}',
                      style: TextStyle(color: colorScheme.outline),
                    ),
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
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.outline,
                  ),
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
                                    style: const TextStyle(fontWeight: FontWeight.w500),
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
                                    _editableMaterials[entry.key] = entry.value - 1;
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
                                  _editableMaterials[entry.key] = entry.value + 1;
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
              
              if (_editableMaterials.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'orders.no_material_suggestions'.tr(),
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ),
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
          onPressed: _editableMaterials.isNotEmpty
              ? () {
                  Navigator.pop(context);
                  widget.onConfirm(
                    _editableMaterials,
                    widget.suggestion.explanation,
                  );
                }
              : null,
          icon: const Icon(Icons.shopping_cart),
          label: Text('orders.apply_to_shopping_list'.tr()),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.deepPurple,
          ),
        ),
      ],
    );
  }
}
