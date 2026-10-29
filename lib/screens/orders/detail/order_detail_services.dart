import 'package:flutter/widgets.dart';

import '../../../data/cocktail_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/order_repository.dart';
import '../../../data/stock_repository.dart';
import '../../../models/cocktail_data.dart';
import '../../../models/employee.dart';
import '../../../models/order.dart';
import '../../../services/auth_service.dart';
import '../../inventory/rest_entry_sheet.dart';
import '../../shopping_list/completion_deduction.dart';
import 'sheets.dart';
import 'order_detail_controller.dart';

bool _defaultIsSuperAdmin() => AuthService().isSuperAdmin;

bool _defaultIsEmployeeOrHigher() => AuthService().isEmployeeOrHigher;

Future<OrderDeductionPlan> _defaultDeductForOrder(String orderId) =>
    stockRepository.deductForOrder(orderId);

Future<bool> _defaultShowRestEntry(BuildContext context, SavedOrder order) =>
    showRestEntrySheet(context, order: order);

Stream<List<Employee>> _defaultWatchEmployees() =>
    employeeRepository.watchEmployees();

Future<CocktailData> _defaultLoadCocktailData() => cocktailRepository.load();

Future<String?> _defaultAskDeclineReason(
  BuildContext context,
  String initial,
) => showDeclineReasonSheet(context, initial: initial);

/// The external collaborators of the order detail sheet, bundled so tests
/// can pump the sheet without Firebase or the browser-only Microsoft code.
///
/// Every default delegates lazily to the same global singleton the sheet has
/// always used. The one exception is [triggerMicrosoftIntegration]: its real
/// implementation imports `dart:js_interop`, so it is required: there is no
/// silent no-op default. `showOrderDetails` (the only production entry
/// point) passes the real one, tests pass a fake.
class OrderDetailServices {
  const OrderDetailServices({
    this.isSuperAdmin = _defaultIsSuperAdmin,
    this.isEmployeeOrHigher = _defaultIsEmployeeOrHigher,
    this.deductForOrder = _defaultDeductForOrder,
    this.showRestEntry = _defaultShowRestEntry,
    this.watchEmployees = _defaultWatchEmployees,
    this.loadCocktailData = _defaultLoadCocktailData,
    required this.triggerMicrosoftIntegration,
    this.askDeclineReason = _defaultAskDeclineReason,
    OrderRepository? orderRepository,
  }) : _orderRepository = orderRepository;

  /// `AuthService().isSuperAdmin` (delete section).
  final bool Function() isSuperAdmin;

  /// `AuthService().isEmployeeOrHigher` ("Rest erfassen").
  final bool Function() isEmployeeOrHigher;

  /// `stockRepository.deductForOrder(orderId)`: plans from the FRESH order.
  final Future<OrderDeductionPlan> Function(String orderId) deductForOrder;

  /// `showRestEntrySheet(context, order: order)`.
  final Future<bool> Function(BuildContext context, SavedOrder order)
  showRestEntry;

  /// `employeeRepository.watchEmployees()`.
  final Stream<List<Employee>> Function() watchEmployees;

  /// `cocktailRepository.load()`.
  final Future<CocktailData> Function() loadCocktailData;

  /// OneDrive upload + calendar event after accepting
  /// (`runMicrosoftIntegration` in `microsoft_integration.dart`).
  final Future<void> Function(OrderDetailController controller)
  triggerMicrosoftIntegration;

  /// The decline-reason dialog (`showDeclineReasonSheet`): the trimmed
  /// reason, or null when cancelled.
  final Future<String?> Function(BuildContext context, String initial)
  askDeclineReason;

  final OrderRepository? _orderRepository;

  /// The repository the order is read/updated/deleted through (the global
  /// `orderRepository` unless overridden).
  OrderRepository get orders => _orderRepository ?? orderRepository;
}
