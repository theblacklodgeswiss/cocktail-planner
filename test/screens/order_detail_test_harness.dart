// Shared fakes for the order detail sheet tests
// (order_detail_refactor_test.dart). Everything the sheet talks to goes
// through `OrderDetailServices`, so no Firebase, no browser-only Microsoft
// code and no real rest-entry sheet is involved.
import 'dart:async';

import 'package:cocktail_planer/data/order_repository.dart';
import 'package:cocktail_planer/models/cocktail_data.dart';
import 'package:cocktail_planer/models/employee.dart';
import 'package:cocktail_planer/models/order.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_controller.dart';
import 'package:cocktail_planer/screens/orders/detail/dialogs.dart';
import 'package:cocktail_planer/screens/orders/detail/order_detail_services.dart';
import 'package:cocktail_planer/screens/shopping_list/completion_deduction.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

SavedOrder detailOrder({
  OrderStatus status = OrderStatus.quote,
  double total = 100,
  bool offerComplete = true,
  bool restRecorded = false,
  bool stockApplied = false,
  String declineReason = '',
  List<String> assignedEmployees = const [],
  List<Map<String, dynamic>> items = const [],
  OrderSource source = OrderSource.app,
  bool hasShoppingList = true,
}) => SavedOrder(
  id: 'o1',
  name: 'Party',
  date: DateTime(2027, 5, 1),
  items: items,
  total: total,
  personCount: 20,
  drinkerType: 'normal',
  currency: 'CHF',
  status: status,
  restRecorded: restRecorded,
  stockApplied: stockApplied,
  declineReason: declineReason,
  assignedEmployees: assignedEmployees,
  source: source,
  hasShoppingList: hasShoppingList,
  offerClientName: offerComplete ? 'Anna' : '',
  offerClientContact: 'anna@x.ch',
  offerEventTime: '18:00',
  offerEventTypes: const ['wedding'],
);

/// Records every repository write into the shared [log].
class FakeDetailRepository extends OrderRepository {
  FakeDetailRepository(this.log);

  final List<String> log;
  bool statusResult = true;
  bool updateResult = true;
  bool assignResult = true;
  bool deleteResult = true;
  SavedOrder? fresh;
  final statusCalls = <(String, String, String?)>[];
  final updateCalls = <(String, Map<String, dynamic>)>[];
  final assignCalls = <List<String>>[];

  @override
  Future<bool> updateStatus(
    String orderId,
    String status, {
    String? declineReason,
  }) async {
    log.add('updateStatus:$status');
    statusCalls.add((orderId, status, declineReason));
    return statusResult;
  }

  @override
  Future<bool> updateOrder(String orderId, Map<String, dynamic> data) async {
    log.add('updateOrder');
    updateCalls.add((orderId, data));
    return updateResult;
  }

  @override
  Future<bool> updateAssignedEmployees(
    String orderId,
    List<String> employees,
  ) async {
    log.add('assign');
    assignCalls.add(employees);
    return assignResult;
  }

  @override
  Future<bool> deleteOrder(String orderId) async {
    log.add('delete:$orderId');
    return deleteResult;
  }

  @override
  Future<SavedOrder?> getOrderById(String orderId) async {
    log.add('getOrderById:$orderId');
    return fresh;
  }
}

/// Fakes + recorded side effects for one sheet.
class DetailFakes {
  final log = <String>[];
  late final repo = FakeDetailRepository(log);
  bool superAdmin = false;
  bool staff = true;
  List<Employee> employees = const [];

  /// What `deductForOrder` returns (unless [deductError] or
  /// [deductCompleter] is set).
  OrderDeductionPlan plan = const OrderDeductionPlan(restRecorded: false);
  Object? deductError;
  Completer<OrderDeductionPlan>? deductCompleter;

  /// What the rest-entry sheet returns (saved or skipped).
  bool restSaved = true;

  /// When set, replaces the real decline-reason dialog: called with the
  /// prefilled reason, returns the answer (null = cancelled). The real
  /// dialog cannot be saved in a widget test: it disposes its
  /// TextEditingController while its exit animation still uses it
  /// (pre-existing, debug-only "used after being disposed" assertion).
  String? Function(String initial)? declineReasonAnswer;
  final reasonPrompts = <String>[];

  OrderDetailServices get services => OrderDetailServices(
    isSuperAdmin: () => superAdmin,
    isEmployeeOrHigher: () => staff,
    deductForOrder: (id) async {
      log.add('deduct:$id');
      if (deductError != null) throw deductError!;
      final completer = deductCompleter;
      if (completer != null) return completer.future;
      return plan;
    },
    showRestEntry: (context, order) async {
      log.add('rest');
      return restSaved;
    },
    watchEmployees: () => Stream.value(employees),
    loadCocktailData: () async =>
        const CocktailData(materials: [], recipes: []),
    triggerMicrosoftIntegration: (c) async => log.add('microsoft'),
    askDeclineReason: declineReasonAnswer == null
        ? (context, initial) => showDeclineReasonDialog(context, initial: initial)
        : (context, initial) async {
            reasonPrompts.add(initial);
            return declineReasonAnswer!(initial);
          },
    orderRepository: repo,
  );
}

/// Wraps [home] in EasyLocalization + a GoRouter that records the editor
/// routes the sheet pushes.
Widget detailApp(Widget home, {List<(String, Object?)>? pushed}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      for (final path in [
        '/create-offer',
        '/create-invoice',
        '/shopping-list',
        '/order-form',
      ])
        GoRoute(
          path: path,
          builder: (_, state) {
            pushed?.add((path, state.extra));
            return Scaffold(body: Text('page $path'));
          },
        ),
    ],
  );
  return EasyLocalization(
    supportedLocales: const [Locale('de'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('de'),
    startLocale: const Locale('de'),
    child: Builder(
      builder: (context) => MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
      ),
    ),
  );
}

/// A bare host page for driving [OrderDetailController] directly (no
/// sheet UI): the controller shows its dialogs and snackbars on it.
class ControllerHost extends StatefulWidget {
  const ControllerHost({
    super.key,
    required this.order,
    required this.services,
    required this.onCreated,
  });

  final SavedOrder order;
  final OrderDetailServices services;
  final void Function(OrderDetailController) onCreated;

  @override
  State<ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<ControllerHost>
    implements OrderDetailHost {
  late final OrderDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = OrderDetailController(
      order: widget.order,
      host: this,
      services: widget.services,
    );
    widget.onCreated(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('host page'));
}

/// EasyLocalization loads its assets for real, so the first pump runs in
/// `runAsync` (same as the order form tests).
Future<void> pumpDetailApp(WidgetTester tester, Widget app) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  await tester.pumpAndSettle();
}
