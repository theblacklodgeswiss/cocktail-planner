import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/additional_service.dart';
import '../../models/order.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../../ui/motion.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/pressable.dart';
import '../../ui/widgets/step_scaffold.dart';
import '../../widgets/order_setup_dialog.dart';
import 'order_form_navigation.dart';
import 'order_form_services.dart';
import 'order_form_shopping_list.dart';
import 'order_form_state.dart';
import 'step_mapping.dart';
import 'steps/contact_step.dart';
import 'steps/drinks_step.dart';
import 'steps/extras_step.dart';
import 'steps/occasion_step.dart';
import 'steps/schedule_step.dart';
import 'steps/wizard_widgets.dart' show CheckMark;

export 'order_form_state.dart' show resolveShotPrefillQuantity;

/// Result from the modern order form containing both setup data and selected recipes
class OrderFormResult {
  final OrderSetupData setupData;
  final List<Recipe> selectedRecipes;

  OrderFormResult({required this.setupData, required this.selectedRecipes});
}

/// The five-step order wizard (see `step_mapping.dart` for the steps and
/// how old nine-step `?step=n` links are read). Each step is a
/// [StepScaffold]; Android back goes to the previous step.
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
  final ScrollController _scrollController = ScrollController();
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
    // Read step from URL query parameter (old 5..8 links are mapped).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = widget.services.currentUri();
      final stepParam = uri.queryParameters['step'];
      if (stepParam != null) {
        final step = resolveStepParam(stepParam);
        if (step != null) {
          setState(() => _form.currentStep = step);
          // A legacy index is rewritten to its new one.
          if ('$step' != stepParam) _updateUrlWithoutNavigation(step);
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
    // A failed load is shown (with retry) by the drinks step; mark the
    // error as handled so it is not reported as uncaught before that step
    // is opened.
    _form.dataFuture!.then<void>((_) {}, onError: (Object _) {});
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
      final step = resolveStepParam(stepParam);
      if (step != null && step != _form.currentStep) {
        setState(() => _form.currentStep = step);
        _scrollToTop();
      }
    }
  }

  @override
  void dispose() {
    _distanceLookupDebounce?.cancel();
    _serviceCatalogSubscription?.cancel();
    _scrollController.dispose();
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

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// Shows [step] (content, progress, bottom bar) and mirrors it in the URL.
  void _goToStep(int step) {
    setState(() => _form.currentStep = step);
    // Update URL without affecting navigation stack
    _updateUrlWithoutNavigation(step);
    _scrollToTop();
  }

  void _nextStep() {
    final step = _form.currentStep;
    if (step >= _totalSteps - 1) {
      unawaited(_submitForm());
      return;
    }
    if (!_form.canProceed(step)) {
      // Never a silent no-op: the first tap explains at the fields what is
      // missing. Guests and customers stay on the step until it is valid;
      // staff (who often fill in only what they know, as the old sidebar
      // allowed) continue with the next tap. Submit validation is the same
      // for everyone.
      final explained = _form.attemptedSteps.contains(step);
      if (!_isAdminUser || !explained) {
        _revealMissing(step, _form.firstMissingField(step));
        return;
      }
    }
    HapticFeedback.lightImpact();
    _goToStep(step + 1);
  }

  void _previousStep() {
    if (_form.currentStep > 0) {
      HapticFeedback.lightImpact();
      _goToStep(_form.currentStep - 1);
    }
  }

  /// Back arrow: previous step, or leave the wizard from step 0.
  void _onBack() {
    if (_form.currentStep > 0) {
      _previousStep();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  /// Turns on the hints of [step] and brings [field] into view (text
  /// fields also get focus, which opens the keyboard).
  void _revealMissing(int step, FormFieldId? field) {
    _form.update(() => _form.attemptedSteps.add(step));
    if (field == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _form.focusNodeOf(field);
      if (node == null) FocusManager.instance.primaryFocus?.unfocus();
      final anchor = _form.fieldKeys[field]?.currentContext;
      if (anchor != null) {
        Scrollable.ensureVisible(
          anchor,
          alignment: 0.2,
          duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.page,
          curve: AppMotion.easeOut,
        );
      }
      node?.requestFocus();
    });
  }

  Future<void> _submitForm() async {
    if (_form.isSubmitting) return;
    // Validate required fields
    final invalid = _form.firstInvalidStep();
    if (invalid != null) {
      // Jump to the faulty step (content included) and point at the field.
      _goToStep(invalid.step);
      _revealMissing(
        invalid.step,
        FormFieldId.values.firstWhere(
          (f) => f.messageKey == invalid.messageKey,
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(invalid.messageKey.tr())));
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
            backgroundColor: AppPalette.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _generateShoppingListWithGemini() =>
      generateShoppingListWithClaude(context, _form);

  void _retryCocktailData() => setState(_loadCocktailData);

  /// Staff only: a sheet listing all steps; picking one jumps there
  /// without validation (what the old desktop sidebar did).
  Future<void> _showStepPicker() async {
    final picked = await showAppSheet<int>(
      context,
      builder: (sheet) {
        final p = AppPalette.of(sheet);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ui.jump_to_step'.tr(),
              style: AppText.heroTitle.copyWith(color: p.text),
            ),
            const SizedBox(height: AppSpace.s8),
            for (var i = 0; i < _totalSteps; i++)
              Pressable(
                minSize: AppSize.minTap,
                selected: i == _form.currentStep,
                onTap: () => Navigator.of(sheet).pop(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: AppSize.stepDigit,
                        child: Text(
                          '${i + 1}',
                          style: AppText.number.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _titleOf(i),
                          style: AppText.button.copyWith(color: p.text),
                        ),
                      ),
                      CheckMark(selected: i == _form.currentStep),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (picked != null && mounted && picked != _form.currentStep) {
      HapticFeedback.selectionClick();
      _goToStep(picked);
    }
  }

  String _titleOf(int step) => switch (step) {
    0 => 'order_wizard.title_occasion'.tr(),
    1 => 'order_wizard.title_schedule'.tr(),
    2 => 'order_wizard.title_contact'.tr(),
    3 => 'order_wizard.title_drinks'.tr(),
    _ => 'order_wizard.title_extras'.tr(),
  };

  Widget _stepContent(int step) => switch (step) {
    0 => OccasionStep(form: _form),
    1 => ScheduleStep(form: _form, isEmployeeOrHigher: _isAdminUser),
    2 => ContactStep(form: _form),
    3 => DrinksStep(form: _form, onRetry: _retryCocktailData),
    _ => ExtrasStep(
      form: _form,
      isEmployeeOrHigher: _isAdminUser,
      onEditStep: _goToStep,
    ),
  };

  @override
  Widget build(BuildContext context) {
    // The step widgets read MediaQuery and the EasyLocalization locale on
    // their own contexts. This screen keeps depending on both explicitly:
    // every resize, rotation, keyboard inset or locale change re-runs
    // didChangeDependencies, which re-reads the URL's `?step=` (this is how
    // browser back/forward re-syncs).
    MediaQuery.of(context);
    context.locale;
    final step = _form.currentStep;
    return PopScope(
      // Android back walks the steps; only step 0 leaves the wizard.
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previousStep();
      },
      child: StepScaffold(
        step: step + 1,
        total: _totalSteps,
        title: _titleOf(step),
        onBack: _onBack,
        controller: _scrollController,
        onStepLabelTap: _isAdminUser ? _showStepPicker : null,
        bottom: OrderFormBottomBar(
          form: _form,
          isEmployeeOrHigher: _isAdminUser,
          onNext: _nextStep,
          onGenerateShoppingList: _generateShoppingListWithGemini,
        ),
        child: _StepEntrance(key: ValueKey(step), child: _stepContent(step)),
      ),
    );
  }
}

/// Fades (and, unless reduced motion is on, slightly slides) a step's
/// content in when it appears. Only the new step is in the tree, so field
/// anchors and focus nodes are never mounted twice.
class _StepEntrance extends StatefulWidget {
  const _StepEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<_StepEntrance> createState() => _StepEntranceState();
}

class _StepEntranceState extends State<_StepEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
  )..forward();
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.easeOut,
  );

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faded = FadeTransition(opacity: _curve, child: widget.child);
    if (AppMotion.reduced(context)) return faded;
    return SlideTransition(
      position: Tween(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(_curve),
      child: faded,
    );
  }
}
