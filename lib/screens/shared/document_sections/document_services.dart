import '../../../data/additional_service_repository.dart';
import '../../../data/cocktail_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/order_repository.dart';
import '../../../data/share_link_repository.dart';
import '../../../models/additional_service.dart';
import '../../../models/employee.dart';
import '../../../services/auth_service.dart';
import '../../../services/claude_service.dart';

String? _defaultDisplayName() => authService.displayName;

/// Generates the middle "cocktail commentary" of the offer share message.
typedef ShareMiddleGenerator =
    Future<String?> Function({
      required List<String> originalCocktails,
      required List<String> selectedCocktails,
      required List<String> allAvailableCocktails,
    });

/// `claudeService.generateOfferShareMessage` when Claude is configured.
Future<String?> defaultGenerateShareMiddle({
  required List<String> originalCocktails,
  required List<String> selectedCocktails,
  required List<String> allAvailableCocktails,
}) async {
  if (!claudeService.isConfigured) return null;
  return claudeService.generateOfferShareMessage(
    originalCocktails: originalCocktails,
    selectedCocktails: selectedCocktails,
    allAvailableCocktails: allAvailableCocktails,
  );
}

Stream<List<Employee>> _defaultWatchEmployees() =>
    employeeRepository.watchEmployees();

Stream<List<AdditionalService>> _defaultWatchAdditionalServices() =>
    additionalServiceRepository.watchServices();

Future<List<String>> _defaultLoadCocktailNames() async {
  final data = await cocktailRepository.load();
  return data.recipes.map((r) => r.name).toList();
}

/// The external collaborators of the offer and invoice screens, bundled so
/// tests can pump their sections and flows without Firebase.
///
/// Every default delegates lazily to the same global singleton the screens
/// have always used, so `const DocumentServices()` behaves exactly as before.
/// The browser-only parts (Microsoft Graph, PDF printing) are not in here:
/// they stay in the screen files, which pass them to the flows as callbacks.
class DocumentServices {
  const DocumentServices({
    this.displayName = _defaultDisplayName,
    this.watchEmployees = _defaultWatchEmployees,
    this.watchAdditionalServices = _defaultWatchAdditionalServices,
    this.loadCocktailNames = _defaultLoadCocktailNames,
    this.generateShareMiddle = defaultGenerateShareMiddle,
    OrderRepository? orderRepository,
    ShareLinkRepository? shareLinkRepository,
  }) : _orderRepository = orderRepository,
       _shareLinkRepository = shareLinkRepository;

  /// `authService.displayName` (default editor name).
  final String? Function() displayName;

  /// `employeeRepository.watchEmployees()`.
  final Stream<List<Employee>> Function() watchEmployees;

  /// `additionalServiceRepository.watchServices()`.
  final Stream<List<AdditionalService>> Function() watchAdditionalServices;

  /// Recipe names of `cocktailRepository.load()` (cocktail chips catalog).
  final Future<List<String>> Function() loadCocktailNames;

  /// Claude's part of the offer share message.
  final ShareMiddleGenerator generateShareMiddle;

  final OrderRepository? _orderRepository;
  final ShareLinkRepository? _shareLinkRepository;

  OrderRepository get orders => _orderRepository ?? orderRepository;

  ShareLinkRepository get shareLinks =>
      _shareLinkRepository ?? shareLinkRepository;
}
