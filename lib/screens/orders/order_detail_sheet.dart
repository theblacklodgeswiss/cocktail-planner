import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/employee_repository.dart';
import '../../data/order_repository.dart';
import '../../models/employee.dart';
import '../../models/order.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_pdf_generator.dart';
import '../../services/microsoft_graph_service.dart';
import '../../services/pdf_generator.dart';
import '../../utils/currency.dart';
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
    final success =
        await orderRepository.updateStatus(widget.order.id, newStatus.value);
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

  Future<void> _triggerMicrosoftIntegration() async {
    if (!microsoftGraphService.isSupported) return;

    try {
      // Generate PDF bytes
      final pdfBytes = await PdfGenerator.generateBytesFromSavedOrder(widget.order);
      
      // Build OneDrive path
      final fileName = 'Auftrag_${widget.order.name.replaceAll(' ', '_')}.pdf';
      final oneDrivePath = MicrosoftGraphService.buildOneDrivePath(
        rootFolder: 'Aufträge',
        date: widget.order.date,
        fileName: fileName,
      );
      
      // Upload to OneDrive
      final uploadSuccess = await microsoftGraphService.uploadToOneDrive(
        oneDrivePath: oneDrivePath,
        bytes: pdfBytes,
      );
      
      // Create calendar event
      final eventStart = widget.order.date;
      final eventEnd = eventStart.add(const Duration(hours: 4));
      final employeeNames = _assignedEmployees.isNotEmpty
          ? _assignedEmployees.join(', ')
          : 'TBD';
      final eventBody = 'Auftrag: ${widget.order.name}\n'
          'Personen: ${widget.order.personCount}\n'
          'Mitarbeiter: $employeeNames\n'
          'Gesamtbetrag: ${Currency.fromCode(widget.order.currency).format(widget.order.total)}';
      
      final calendarSuccess = await microsoftGraphService.createCalendarEvent(
        subject: widget.order.name,
        start: eventStart,
        end: eventEnd,
        bodyContent: eventBody,
      );
      
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('orders.microsoft_integration_failed'.tr())),
        );
      }
    }
  }

  Future<void> _generateInvoice() async {
    final language = await _showLanguageDialog();
    if (language == null || !mounted) return;

    _showLoadingDialog();

    try {
      await InvoicePdfGenerator.generateAndDownload(widget.order,
          language: language);
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('orders.invoice_created'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error'.tr())),
        );
      }
    }
  }

  Future<String?> _showLanguageDialog() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('orders.select_language'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇩🇪', style: TextStyle(fontSize: 24)),
              title: const Text('Deutsch'),
              onTap: () => Navigator.pop(ctx, 'de'),
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
              onTap: () => Navigator.pop(ctx, 'en'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text('orders.generating_invoice'.tr()),
          ],
        ),
      ),
    );
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
            Text('orders.change_status'.tr(),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_currentStatus != OrderStatus.accepted)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _updateStatus(OrderStatus.accepted),
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
        ),
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
