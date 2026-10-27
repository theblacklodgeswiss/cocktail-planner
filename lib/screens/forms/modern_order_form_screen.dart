import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/additional_service.dart';
import '../../models/order.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../widgets/order_setup_dialog.dart';
import 'order_form_navigation.dart';
import 'order_form_services.dart';
import 'order_form_shopping_list.dart';
import 'order_form_state.dart';
import 'steps/additional_services_step.dart';
import 'steps/bar_drinks_step.dart';
import 'steps/cocktails_step.dart';
import 'steps/contact_step.dart';
import 'steps/event_step.dart';
import 'steps/overview_step.dart';
import 'steps/popularity_step.dart';
import 'steps/preferences_step.dart';
import 'steps/service_type_step.dart';

export 'order_form_state.dart' show resolveShotPrefillQuantity;

/// Result from the modern order form containing both setup data and selected recipes
class OrderFormResult {
  final OrderSetupData setupData;
  final List<Recipe> selectedRecipes;

  OrderFormResult({required this.setupData, required this.selectedRecipes});
}

/// Modern multi-step order form inspired by Roamy app design.
/// Features card-based UI, smooth transitions, and touch-optimized controls.
/// Pass [prefill] to pre-populate all fields from an existing form order.
class ModernOrderFormScreen extends StatefulWidget {
  final void Function(OrderFormResult result)? onSubmit;
  final SavedOrder? prefill;

  /// External collaborators (auth role, repositories, distance lookup,
  /// browser URL). Defaults to the app's global singletons; tests inject
  /// fakes.
  final OrderFormServices services;

  const ModernOrderFormScreen({
    super.key,
    this.onSubmit,
    this.prefill,
    this.services = const OrderFormServices(),
  });

  @override
  State<ModernOrderFormScreen> createState() => _ModernOrderFormScreenState();
}

class _ModernOrderFormScreenState extends State<ModernOrderFormScreen> {
  final PageController _pageController = PageController();
  static const int _totalSteps = OrderFormState.totalSteps;

  /// All form data (controllers, selections, derived values).
  late final OrderFormState _form;

  StreamSubscription<List<AdditionalService>>? _serviceCatalogSubscription;

  Timer? _distanceLookupDebounce;
  // Trimmed address text as of the last time the debounce/lookup logic
  // below actually ran. `TextEditingController.addListener` fires on ANY
  // `TextEditingValue` change, including a cursor/selection move with no
  // text change (e.g. tapping back into an already-filled field) - without
  // this, that spurious notification would still cancel/reschedule the
  // lookup and flash "calculating...", wasting a Nominatim request.
  String _lastLookupAddress = '';

  @override
  void initState() {
    super.initState();
    _form = OrderFormState(
      distanceLookupPending: !widget.services.isEmployeeOrHigher(),
    );
    // Step widgets mutate the form through `_form.update`, which rebuilds
    // the whole screen - exactly like the former in-place `setState` calls.
    _form.addListener(_onFormChanged);
    _form.nameController.addListener(() => setState(() {}));
    _form.phoneController.addListener(() => setState(() {}));
    _form.addressController.addListener(() {
      setState(() {});
      // Guests get their distance computed automatically from the address
      // they type; an employee's manually-set value must never be silently
      // overwritten by a background lookup.
      if (!widget.services.isEmployeeOrHigher()) {
        final trimmedAddress = _form.addressController.text.trim();
        // Skip the debounce/pending-reset/reschedule entirely when the
        // text hasn't actually changed (a cursor move, tapping back into
        // the field, etc. still notifies listeners but isn't an edit).
        if (trimmedAddress == _lastLookupAddress) return;
        _lastLookupAddress = trimmedAddress;
        _distanceLookupDebounce?.cancel();
        setState(() => _form.distanceLookupPending = true);
        _distanceLookupDebounce = Timer(const Duration(milliseconds: 800), () {
          // Capture the address this lookup is for at the moment it starts.
          // Cancelling `_distanceLookupDebounce` above only prevents a *new*
          // Timer body from starting - it does nothing to stop an
          // already-in-flight Future from a previous Timer that already
          // fired. If the guest edits the address again before that older
          // network call returns, its (now stale) result must not overwrite
          // whatever the newer lookup found, even if the older call happens
          // to resolve later (e.g. a slower round trip).
          final requestedAddress = _form.addressController.text.trim();
          widget.services
              .distanceKmFromAddress(requestedAddress)
              .then((result) {
            // Re-check mounted/role state HERE, right before applying the
            // result - not just when the Timer was scheduled above. The
            // role check at scheduling time can be stale: e.g. a staff
            // member editing an existing order has their address prefilled
            // (firing this listener) before the async role check resolves,
            // so this Timer can be scheduled as a "guest" lookup and only
            // fire well after the session is known to be employee-or-higher
            // and the correct prefilled `_form.distanceKm` is already showing.
            // Also discard the result if the address has since changed
            // (see `requestedAddress` above) - it no longer corresponds to
            // what's in the field. Only one Timer is ever pending at a time
            // (a new address change cancels the previous one above), so
            // these guards are sufficient without extra request-id tracking.
            if (!mounted ||
                widget.services.isEmployeeOrHigher() ||
                _form.addressController.text.trim() != requestedAddress) {
              return;
            }
            setState(() {
              if (result != null) _form.distanceKm = result;
              _form.distanceLookupPending = false;
            });
          });
        });
      }
    });
    _applyPrefill(); // must run before _loadCocktailData so _form.prefillOrder is set
    _loadCocktailData();
    _serviceCatalogSubscription =
        widget.services.watchAdditionalServices().listen((services) {
      if (mounted) setState(() => _form.serviceCatalog = services);
    });
    widget.services.resolveRole().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    // Read step from URL query parameter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = widget.services.currentUri();
      final stepParam = uri.queryParameters['step'];
      if (stepParam != null) {
        final step = int.tryParse(stepParam) ?? 0;
        if (step >= 0 && step < _totalSteps) {
          setState(() => _form.currentStep = step);
          if (_pageController.hasClients) {
            _pageController.jumpToPage(step);
          }
        }
      } else {
        // No step parameter, set to 0 and update URL
        _updateUrlWithoutNavigation(0);
      }
    });
  }

  void _loadCocktailData() {
    _form.dataFuture = widget.services.loadCocktailData();
    // After data loads, pre-select cocktails from prefill
    final prefillOrder = _form.prefillOrder;
    if (prefillOrder != null) {
      _form.dataFuture = _form.dataFuture!.then((data) {
        if (mounted) {
          setState(() => _form.preselectRecipes(data, prefillOrder));
        }
        return data;
      });
    }
  }

  void _applyPrefill() {
    // widget.prefill for programmatic use; appState.pendingFormOrder for push-navigation (avoids GoRouter extra being lost on web)
    final order = widget.prefill ?? appState.pendingFormOrder;
    if (order == null) return;
    _form.prefillOrder = order;
    appState.clearPendingFormOrder();
    _form.applyPrefill(order);
  }

  void _onFormChanged() => setState(() {});

  bool get _isAdminUser => widget.services.isEmployeeOrHigher();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync step from URL when navigating back/forward
    final uri = widget.services.currentUri();
    final stepParam = uri.queryParameters['step'];
    if (stepParam != null) {
      final step = int.tryParse(stepParam) ?? 0;
      if (step >= 0 && step < _totalSteps && step != _form.currentStep) {
        setState(() => _form.currentStep = step);
        if (_pageController.hasClients) {
          _pageController.jumpToPage(step);
        }
      }
    }
  }

  @override
  void dispose() {
    _distanceLookupDebounce?.cancel();
    _serviceCatalogSubscription?.cancel();
    _pageController.dispose();
    _form.dispose();
    super.dispose();
  }

  // Update browser URL without affecting GoRouter's navigation stack
  void _updateUrlWithoutNavigation(int step) {
    final currentUrl = widget.services.currentUri();
    final newUrl = currentUrl.replace(
      queryParameters: {'step': step.toString()},
    );
    widget.services.updateUrl(newUrl.toString());
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_form.currentStep < _totalSteps - 1) {
      final nextStep = _form.currentStep + 1;
      setState(() => _form.currentStep = nextStep);
      // Update URL without affecting navigation stack
      _updateUrlWithoutNavigation(nextStep);
      // Animate PageView on mobile layout
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      unawaited(_submitForm());
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    if (_form.currentStep > 0) {
      final prevStep = _form.currentStep - 1;
      setState(() => _form.currentStep = prevStep);
      // Update URL without affecting navigation stack
      _updateUrlWithoutNavigation(prevStep);
      // Animate PageView on mobile layout
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          prevStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_form.isSubmitting) return;
    // Validate required fields
    final invalid = _form.firstInvalidStep();
    if (invalid != null) {
      _form.currentStep = invalid.step; // Jump to the faulty step
      _updateUrlWithoutNavigation(invalid.step);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(invalid.messageKey.tr())));
      setState(() {}); // Update UI to show correct step
      return;
    }

    setState(() => _form.isSubmitting = true);

    final setupData = _form.buildSetupData();

    final result = OrderFormResult(
      setupData: setupData,
      selectedRecipes: _form.selectedRecipes,
    );

    // Employees and admins get the staff flow (pricing, shopping list);
    // everyone else gets the customer request flow.
    final isEmployeeOrHigher = widget.services.isEmployeeOrHigher();

    try {
      if (!isEmployeeOrHigher) {
        // Customer flow: Save as pending order and show thank you dialog
        await _savePendingOrderAndShowThanks(setupData);
      } else if (_form.prefillOrder != null) {
        // Admin prefill flow: update existing form order with new data, then go to shopping list
        await _updateFormOrderAndNavigate(setupData);
      } else {
        // Admin flow: Sync selected recipes + popularity to global state and navigate
        appState.setSelectedRecipes(_form.selectedRecipes);
        for (final entry in _form.cocktailPopularity.entries) {
          appState.setCocktailPopularity(entry.key, entry.value);
        }
        if (widget.onSubmit != null) {
          widget.onSubmit!(result);
        } else {
          context.go('/shopping-list', extra: setupData);
        }
      }
    } finally {
      if (mounted) setState(() => _form.isSubmitting = false);
    }
  }

  Future<void> _updateFormOrderAndNavigate(OrderSetupData setupData) async {
    final order = _form.prefillOrder!;
    final cocktailNames = _form.selectedRecipes
        .where((r) => !r.isShot)
        .map((r) => r.name)
        .toList();
    final shotNames = _form.selectedRecipes
        .where((r) => r.isShot)
        .map((r) => r.name)
        .toList();
    final eventTimeStr = setupData.eventTime != null
        ? '${setupData.eventTime!.hour.toString().padLeft(2, '0')}:${setupData.eventTime!.minute.toString().padLeft(2, '0')}'
        : '';
    await widget.services.orders.updateOrder(order.id, {
      'name': setupData.orderName,
      'date': (setupData.eventDate ?? order.date).toIso8601String(),
      'phone': setupData.phoneNumber ?? '',
      'location': setupData.address ?? '',
      'personCount': setupData.personCount,
      'distanceKm': setupData.distanceKm ?? 0,
      'currency': setupData.currency,
      'drinkerType': setupData.drinkerType,
      'serviceType': setupData.serviceType,
      'cocktails': cocktailNames,
      'shots': shotNames,
      'shotQuantities': _form.shotQuantities.entries
          .map((e) => {'name': e.key, 'quantity': e.value})
          .toList(),
      'eventTime': eventTimeStr,
      'offerEventTime': eventTimeStr,
      'eventType': _form.selectedEventType?.name ?? '',
      'offerClientName': setupData.orderName,
      'offerClientContact': setupData.phoneNumber ?? '',
    });
    appState.setLinkedOrder(
      order.id,
      setupData.orderName,
      requestedCocktails: order.requestedCocktails,
      savedItems: order.items,
    );
    appState.setSelectedRecipes(_form.selectedRecipes);
    for (final entry in _form.cocktailPopularity.entries) {
      appState.setCocktailPopularity(entry.key, entry.value);
    }
    if (mounted) {
      context.go('/shopping-list', extra: setupData);
    }
  }

  Future<void> _savePendingOrderAndShowThanks(OrderSetupData setupData) async {
    try {
      // Save pending order (total = 0) using repository method
      final orderId = await widget.services.orders.saveOrder(
        name: setupData.orderName,
        date: setupData.eventDate ?? DateTime.now(),
        items: [], // Empty items for pending order
        total: 0, // Pending order
        currency: setupData.currency,
        personCount: setupData.personCount,
        drinkerType: setupData.drinkerType,
        status: 'quote',
        cocktails: _form.selectedRecipes
            .where((r) => !r.isShot)
            .map((r) => r.name)
            .toList(),
        shots: _form.selectedRecipes
            .where((r) => r.isShot)
            .map((r) => r.name)
            .toList(),
        shotQuantities: _form.shotQuantities.entries
            .map((e) => {'name': e.key, 'quantity': e.value})
            .toList(),
        serviceType: setupData.serviceType,
        distanceKm: setupData.distanceKm ?? 0,
        phone: setupData.phoneNumber ?? '',
        location: setupData.address ?? '',
        eventTime: setupData.eventTime != null
            ? '${setupData.eventTime!.hour.toString().padLeft(2, '0')}:${setupData.eventTime!.minute.toString().padLeft(2, '0')}'
            : '',
        barDrinks: setupData.barDrinks ?? [],
        alcoholPurchase: setupData.alcoholPurchase ?? [],
        additionalServices: setupData.additionalServices ?? [],
        remarks: setupData.remarks ?? '',
        cocktailPopularity: _form.cocktailPopularity,
        eventType: _form.selectedEventType?.name ?? '',
      );

      if (orderId == null) {
        throw Exception('Failed to save order');
      }

      // Navigate to success screen
      if (mounted) {
        context.go('/order-success');
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('order_form.save_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Desktop stepper tap: jump to [step] without validation.
  void _selectStep(int step) {
    setState(() => _form.currentStep = step);
    // Update URL without affecting navigation stack
    _updateUrlWithoutNavigation(step);
  }

  Future<void> _generateShoppingListWithGemini() =>
      generateShoppingListWithClaude(context, _form);

  Widget _buildDesktopActionButtons() => OrderFormDesktopActions(
    form: _form,
    isEmployeeOrHigher: _isAdminUser,
    onNext: _nextStep,
    onBack: _previousStep,
  );

  ServiceTypeStep _serviceTypeStep() => ServiceTypeStep(
    form: _form,
    desktopActions: _buildDesktopActionButtons,
  );

  ContactStep _contactStep() =>
      ContactStep(form: _form, desktopActions: _buildDesktopActionButtons);

  EventStep _eventStep() =>
      EventStep(form: _form, desktopActions: _buildDesktopActionButtons);

  PreferencesStep _preferencesStep() => PreferencesStep(
    form: _form,
    isEmployeeOrHigher: widget.services.isEmployeeOrHigher(),
    desktopActions: _buildDesktopActionButtons,
  );

  BarDrinksStep _barDrinksStep() =>
      BarDrinksStep(form: _form, desktopActions: _buildDesktopActionButtons);

  CocktailsStep _cocktailsStep() =>
      CocktailsStep(form: _form, desktopActions: _buildDesktopActionButtons);

  PopularityStep _popularityStep() =>
      PopularityStep(form: _form, desktopActions: _buildDesktopActionButtons);

  AdditionalServicesStep _additionalServicesStep() => AdditionalServicesStep(
    form: _form,
    desktopActions: _buildDesktopActionButtons,
  );

  OverviewStep _overviewStep() => OverviewStep(
    form: _form,
    isEmployeeOrHigher: _isAdminUser,
    onGenerateShoppingList: _generateShoppingListWithGemini,
    desktopActions: _buildDesktopActionButtons,
  );

  @override
  Widget build(BuildContext context) {
    // The step builders used to run on this State's context and read
    // MediaQuery (width checks) and the EasyLocalization locale here, which
    // made this screen depend on both: every resize, rotation, keyboard
    // inset or locale change re-ran didChangeDependencies, re-reading the
    // URL's `?step=` (this is how browser back/forward re-syncs). The step
    // widgets now read them on their own context, so keep the dependencies
    // explicitly.
    MediaQuery.of(context);
    context.locale;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text('order_setup.title'.tr()),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_form.currentStep > 0) {
              _previousStep();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop/Tablet Layout (≥ 600px width)
          if (constraints.maxWidth >= 600) {
            return _buildDesktopLayout();
          }
          // Mobile Layout (< 600px width)
          return _buildMobileLayout();
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    // The former inline step builders ran for all nine pages on every
    // build; the popularity page's build-time sync (fill 50 %, drop stale
    // entries - only while recipes are selected) therefore ran on every
    // mobile rebuild. PageView now builds pages lazily, so replay it here.
    if (_form.selectedRecipes.isNotEmpty) {
      _form.syncPopularityWithSelection();
    }
    return Column(
      children: [
        // Progress Indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: List.generate(
              _totalSteps,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < _totalSteps - 1 ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: index <= _form.currentStep
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Page View
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _form.currentStep = index),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _serviceTypeStep(),
              _contactStep(),
              _eventStep(),
              _preferencesStep(),
              _barDrinksStep(),
              _cocktailsStep(),
              _popularityStep(),
              _additionalServicesStep(),
              _overviewStep(),
            ],
          ),
        ),
        // Navigation Buttons
        OrderFormMobileFooter(
          form: _form,
          isEmployeeOrHigher: _isAdminUser,
          onNext: _nextStep,
          onBack: _previousStep,
          onGenerateShoppingList: _generateShoppingListWithGemini,
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Side: Vertical Stepper
        OrderFormStepperSidebar(form: _form, onStepSelected: _selectStep),
        // Right Side: Content
        Expanded(
          child: SingleChildScrollView(
            child: _form.currentStep >= 5
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: _buildCurrentStepContent(),
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: _buildCurrentStepContent(),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_form.currentStep) {
      case 0:
        return _serviceTypeStep();
      case 1:
        return _contactStep();
      case 2:
        return _eventStep();
      case 3:
        return _preferencesStep();
      case 4:
        return _barDrinksStep();
      case 5:
        return _cocktailsStep();
      case 6:
        return _popularityStep();
      case 7:
        return _additionalServicesStep();
      case 8:
        return _overviewStep();
      default:
        return Container();
    }
  }
}
