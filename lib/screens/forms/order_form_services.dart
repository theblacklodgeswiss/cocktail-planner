import '../../data/additional_service_repository.dart';
import '../../data/cocktail_repository.dart';
import '../../data/order_repository.dart';
import '../../models/additional_service.dart';
import '../../models/cocktail_data.dart';
import '../../services/auth_service.dart';
import '../../services/distance_calculator.dart';
import '../../utils/url_utils.dart';

bool _defaultIsEmployeeOrHigher() => authService.isEmployeeOrHigher;

Future<void> _defaultResolveRole() => authService.checkIsAdmin();

Future<CocktailData> _defaultLoadCocktailData() => cocktailRepository.load();

Stream<List<AdditionalService>> _defaultWatchAdditionalServices() =>
    additionalServiceRepository.watchServices();

Future<int?> _defaultDistanceKmFromAddress(String address) =>
    distanceCalculator.distanceKmFromAddress(address);

Uri _defaultCurrentUri() => Uri.base;

/// The external collaborators of the order form, bundled so tests can pump
/// the form without Firebase / network / a browser URL.
///
/// Every default delegates lazily to the same global singleton the form has
/// always used (nothing is touched until the form actually calls it), so the
/// production behavior of `const OrderFormServices()` is unchanged.
class OrderFormServices {
  const OrderFormServices({
    this.isEmployeeOrHigher = _defaultIsEmployeeOrHigher,
    this.resolveRole = _defaultResolveRole,
    this.loadCocktailData = _defaultLoadCocktailData,
    this.watchAdditionalServices = _defaultWatchAdditionalServices,
    this.distanceKmFromAddress = _defaultDistanceKmFromAddress,
    this.currentUri = _defaultCurrentUri,
    this.updateUrl = updateBrowserUrl,
    OrderRepository? orderRepository,
  }) : _orderRepository = orderRepository;

  /// `authService.isEmployeeOrHigher`.
  final bool Function() isEmployeeOrHigher;

  /// `authService.checkIsAdmin()` - resolves the role; the form only waits
  /// for completion and rebuilds.
  final Future<void> Function() resolveRole;

  /// `cocktailRepository.load()`.
  final Future<CocktailData> Function() loadCocktailData;

  /// `additionalServiceRepository.watchServices()`.
  final Stream<List<AdditionalService>> Function() watchAdditionalServices;

  /// `distanceCalculator.distanceKmFromAddress(address)`.
  final Future<int?> Function(String address) distanceKmFromAddress;

  /// `Uri.base` - the browser URL the `?step=n` parameter is read from.
  final Uri Function() currentUri;

  /// `updateBrowserUrl` - rewrites the browser URL without navigating.
  final void Function(String url) updateUrl;

  final OrderRepository? _orderRepository;

  /// The repository orders are saved/updated through (the global
  /// `orderRepository` unless overridden).
  OrderRepository get orders => _orderRepository ?? orderRepository;
}
