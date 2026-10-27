import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/additional_service.dart';
import '../../models/cocktail_data.dart';
import '../../models/offer.dart' show EventType;
import '../../models/order.dart';
import '../../models/recipe.dart';
import '../../utils/currency.dart';
import '../../widgets/order_setup_dialog.dart';

/// Resolves the per-flavor quantity to seed for a shot during prefill: uses
/// the matching entry's quantity from [shotSelections] if the customer
/// requested a specific quantity for [recipeName], otherwise defaults to 1
/// (matching the default applied when a shot is freshly selected by staff).
/// Extracted as a pure, directly-testable function - see
/// test/click_interactions_test.dart for the regression test covering the
/// bug where this quantity was silently dropped on prefill.
int resolveShotPrefillQuantity(
  List<ShotSelection> shotSelections,
  String recipeName,
) {
  final matchingSelection = shotSelections.cast<ShotSelection?>().firstWhere(
    (s) => s!.name == recipeName,
    orElse: () => null,
  );
  return matchingSelection?.quantity ?? 1;
}

/// A failed submit validation: the step to jump to and the translation key
/// of the snackbar message.
typedef OrderFormValidationError = ({int step, String messageKey});

/// All mutable data of the order wizard (controllers, selections, derived
/// values). The screen owns one instance, listens to it and rebuilds the
/// whole form on every [notifyListeners] - exactly like the former
/// `setState` calls did.
///
/// Mutations from the step widgets go through [update], which applies the
/// change and notifies. Methods without `notify` in their contract (e.g.
/// [selectServiceType], [toggleRecipeSelection]) only mutate and are meant
/// to be called inside [update] (or a `setState` of the screen).
class OrderFormState extends ChangeNotifier {
  OrderFormState({required this.distanceLookupPending});

  static const int totalSteps = 9;

  int currentStep = 0;

  /// Guards the final-step submit button against a double-tap and drives
  /// its loading spinner while the (async) submit work - a Firestore write
  /// - is in flight. Intermediate "Weiter" taps go through the same
  /// `_nextStep`/button but only do a synchronous `setState`, so they are
  /// unaffected by this flag.
  bool isSubmitting = false;

  Future<CocktailData>? dataFuture;

  /// Resolved prefill order (from widget.prefill or appState.pendingFormOrder).
  SavedOrder? prefillOrder;

  // Form data
  String serviceType = 'cocktail_barservice';
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  DateTime? eventDate;
  TimeOfDay? eventTime;
  final TextEditingController addressController = TextEditingController();
  int personCount = 100;
  int distanceKm = 10;
  // Guests start with a "pending" lookup so the distance display shows a
  // "calculating..." state instead of the fabricated default `distanceKm`
  // value above. Cleared to false as soon as a lookup attempt for the
  // current address resolves (success or definitive failure - see the
  // debounced address listener in the screen's `initState`).
  // Employees/admins never see that display, but this starts false for them
  // anyway so the flag's meaning stays simple and role-independent.
  bool distanceLookupPending;
  String currency = defaultCurrency.code;
  String drinkerType = 'normal';
  EventType? selectedEventType;
  final List<Recipe> selectedRecipes = [];
  final Map<String, double> cocktailPopularity = {};
  final Map<String, int> shotQuantities = {};
  final Map<String, TextEditingController> shotQuantityControllers = {};
  String searchQuery = '';
  String cocktailFilter = 'all'; // 'all', 'cocktails', 'shots'
  final Set<String> selectedBarDrinks = {};
  final Set<String> selectedAlcoholItems = {};
  // Catalog services the customer picked a variant for: serviceId -> variantId.
  final Map<String, String> selectedAdditionalServices = {};
  // "Sonstiges" ("Other") stays a plain flag, not a catalog service - see
  // the design spec section 5.
  bool otherServicesSelected = false;
  // Legacy bare-string service IDs (e.g. 'booth_360') carried over from an
  // order created before the catalog existed - preserved untouched on
  // prefill/save, but not editable through the new tile grid.
  final Set<String> legacyAdditionalServiceIds = {};
  List<AdditionalService> serviceCatalog = [];
  final TextEditingController remarksController = TextEditingController();

  /// Applies [fn] and rebuilds the form (the former `setState(fn)`).
  void update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Whether the "Weiter" button is enabled on [step].
  bool canProceed(int step) {
    if (step == 1) {
      return nameController.text.trim().isNotEmpty &&
          phoneController.text.trim().isNotEmpty;
    }
    if (step == 2) {
      return eventDate != null &&
          eventTime != null &&
          addressController.text.trim().isNotEmpty;
    }
    if (step == 3) {
      return selectedEventType != null;
    }
    return true;
  }

  /// The submit-time validation: the first missing required value, in the
  /// order name -> date -> cocktails, or null when the form can be sent.
  OrderFormValidationError? firstInvalidStep() {
    if (nameController.text.trim().isEmpty) {
      return (step: 1, messageKey: 'order_setup.required_name');
    } else if (eventDate == null) {
      return (step: 2, messageKey: 'order_setup.required_date');
    } else if (selectedRecipes.isEmpty) {
      return (step: 5, messageKey: 'order_setup.required_cocktails');
    }
    return null;
  }

  static String normalizeServiceType(String serviceType) {
    return switch (serviceType) {
      'cocktailservice' => 'cocktail_service',
      'barservice' => 'bar_service',
      _ => serviceType,
    };
  }

  /// Copies [order]'s values into the form fields (controllers, selections,
  /// event time). Does not set [prefillOrder].
  void applyPrefill(SavedOrder order) {
    nameController.text = order.name;
    phoneController.text = order.phone;
    addressController.text = order.location;
    remarksController.text = order.remarks;
    eventDate = order.date;
    personCount = order.personCount > 0 ? order.personCount : personCount;
    currency = order.currency.isNotEmpty ? order.currency : currency;
    drinkerType = order.drinkerType.isNotEmpty
        ? order.drinkerType
        : drinkerType;
    selectedEventType = order.eventType.isNotEmpty
        ? EventType.values.where((e) => e.name == order.eventType).firstOrNull
        : selectedEventType;
    selectedBarDrinks
      ..clear()
      ..addAll(order.barDrinks);
    selectedAlcoholItems
      ..clear()
      ..addAll(order.alcoholPurchase);
    applyAdditionalServicesPrefill(order.additionalServices);
    cocktailPopularity
      ..clear()
      ..addAll(order.cocktailPopularity);
    if (order.serviceType.isNotEmpty) {
      serviceType = normalizeServiceType(order.serviceType);
    }
    if (order.distanceKm > 0) distanceKm = order.distanceKm;
    // Parse event time
    final timeStr = order.offerEventTime.isNotEmpty
        ? order.offerEventTime
        : order.eventTime;
    if (timeStr.isNotEmpty) {
      try {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          eventTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {}
    }
  }

  /// Parses a prefilled order's `additionalServices` values into this
  /// form's split selection state: composite `"serviceId:variantId"`
  /// strings go into [selectedAdditionalServices], the `'other_services'`
  /// flag into [otherServicesSelected], and anything else (a legacy bare
  /// service ID from before the catalog existed) into
  /// [legacyAdditionalServiceIds] so it round-trips unchanged on save even
  /// though the new tile grid can't display or edit it.
  void applyAdditionalServicesPrefill(List<String> values) {
    selectedAdditionalServices.clear();
    legacyAdditionalServiceIds.clear();
    otherServicesSelected = false;
    for (final value in values) {
      if (value == 'other_services') {
        otherServicesSelected = true;
        continue;
      }
      final separatorIndex = value.indexOf(':');
      if (separatorIndex > 0) {
        final serviceId = value.substring(0, separatorIndex);
        final variantId = value.substring(separatorIndex + 1);
        if (serviceId.isNotEmpty && variantId.isNotEmpty) {
          selectedAdditionalServices[serviceId] = variantId;
          continue;
        }
      }
      legacyAdditionalServiceIds.add(value);
    }
  }

  /// Pre-selects the prefilled order's cocktails (falling back to its
  /// requested cocktails, with "(...)" suffixes stripped) and shots (with
  /// their requested quantities) once the recipe catalog has loaded.
  void preselectRecipes(CocktailData data, SavedOrder order) {
    final cocktailNames = order.cocktails.isNotEmpty
        ? order.cocktails
        : order.requestedCocktails;
    for (final name in cocktailNames) {
      final clean = name.contains('(')
          ? name.substring(0, name.indexOf('(')).trim()
          : name;
      final recipe = data.recipes.cast<Recipe?>().firstWhere(
        (r) => r!.name.toLowerCase() == clean.toLowerCase(),
        orElse: () => null,
      );
      if (recipe != null &&
          !selectedRecipes.any((r) => r.name == recipe.name)) {
        selectedRecipes.add(recipe);
      }
    }
    for (final name in order.shots) {
      final recipe = data.recipes.cast<Recipe?>().firstWhere(
        (r) => r!.name == name,
        orElse: () => null,
      );
      if (recipe != null &&
          !selectedRecipes.any((r) => r.name == recipe.name)) {
        selectedRecipes.add(recipe);
        shotQuantities[recipe.name] = resolveShotPrefillQuantity(
          order.shotSelections,
          recipe.name,
        );
      }
    }
  }

  /// Flattens the split selection state back into the `List<String>` shape
  /// the `additionalServices` order field has always had - composite
  /// `"serviceId:variantId"` strings for catalog picks, preserved legacy
  /// bare IDs, and `'other_services'` when that flag is set.
  List<String> get additionalServicesList => [
    for (final entry in selectedAdditionalServices.entries)
      '${entry.key}:${entry.value}',
    ...legacyAdditionalServiceIds,
    if (otherServicesSelected) 'other_services',
  ];

  /// Selects a service type. Switching to mocktails drops every selected
  /// shot (and its quantity/controller/popularity) and resets a 'shots'
  /// filter. Call inside [update].
  void selectServiceType(String value) {
    serviceType = value;
    if (value == 'mocktail_service') {
      selectedRecipes.removeWhere((recipe) => recipe.isShot);
      shotQuantities.clear();
      for (final controller in shotQuantityControllers.values) {
        controller.dispose();
      }
      shotQuantityControllers.clear();
      cocktailPopularity.removeWhere(
        (name, _) => !selectedRecipes.any((recipe) => recipe.name == name),
      );
      if (cocktailFilter == 'shots') {
        cocktailFilter = 'all';
      }
    }
  }

  /// Toggles [recipe]; a newly selected shot starts at quantity 1, a
  /// deselected one drops its quantity and controller. Call inside
  /// [update].
  void toggleRecipeSelection(Recipe recipe) {
    final isSelected = selectedRecipes.any((r) => r.id == recipe.id);
    if (isSelected) {
      selectedRecipes.removeWhere((r) => r.id == recipe.id);
      if (recipe.isShot) {
        shotQuantities.remove(recipe.name);
        shotQuantityControllers.remove(recipe.name)?.dispose();
      }
    } else {
      selectedRecipes.add(recipe);
      if (recipe.isShot) shotQuantities[recipe.name] = 1;
    }
  }

  /// Sets [recipe]'s shot quantity, clamped to at least 1. Call inside
  /// [update].
  void setShotQuantity(Recipe recipe, int quantity) {
    final clamped = quantity < 1 ? 1 : quantity;
    shotQuantities[recipe.name] = clamped;
  }

  /// The (lazily created, owned) text controller of [recipe]'s quantity
  /// field.
  TextEditingController shotQuantityController(Recipe recipe) {
    return shotQuantityControllers.putIfAbsent(
      recipe.name,
      () => TextEditingController(text: '${shotQuantities[recipe.name] ?? 1}'),
    );
  }

  /// Initializes missing popularity entries with 50 % and drops entries of
  /// recipes no longer selected. Runs while the popularity step builds
  /// (without notifying), as it always did.
  void syncPopularityWithSelection() {
    // Initialize missing entries with 50%
    for (final recipe in selectedRecipes) {
      cocktailPopularity.putIfAbsent(recipe.name, () => 50.0);
    }
    // Remove stale entries
    cocktailPopularity.removeWhere(
      (name, _) => !selectedRecipes.any((r) => r.name == name),
    );
  }

  /// The trimmed form values in the shape the setup/shopping-list flow and
  /// `saveOrder` consume (empty optional values become null).
  OrderSetupData buildSetupData() {
    return OrderSetupData(
      orderName: nameController.text.trim(),
      phoneNumber: phoneController.text.trim().isEmpty
          ? null
          : phoneController.text.trim(),
      eventDate: eventDate,
      eventTime: eventTime,
      address: addressController.text.trim().isEmpty
          ? null
          : addressController.text.trim(),
      personCount: personCount,
      distanceKm: distanceKm,
      currency: currency,
      drinkerType: drinkerType,
      serviceType: serviceType,
      barDrinks: selectedBarDrinks.isEmpty ? null : selectedBarDrinks.toList(),
      alcoholPurchase: selectedAlcoholItems.isEmpty
          ? null
          : selectedAlcoholItems.toList(),
      additionalServices: additionalServicesList.isEmpty
          ? null
          : additionalServicesList,
      remarks: remarksController.text.trim().isEmpty
          ? null
          : remarksController.text.trim(),
    );
  }

  /// Summary line of [step] in the desktop stepper.
  String stepTitle(int step) {
    switch (step) {
      case 0:
        return serviceType == 'cocktail_barservice'
            ? 'Cocktail & Bar'
            : serviceType == 'cocktail_service'
            ? 'Nur Cocktail'
            : serviceType == 'mocktail_service'
            ? 'Nur Mocktails'
            : 'Nur Bar';
      case 1:
        return nameController.text.trim().isEmpty
            ? 'Nicht ausgefüllt'
            : nameController.text.trim();
      case 2:
        return eventDate != null
            ? DateFormat('dd.MM.yyyy').format(eventDate!)
            : 'Nicht ausgefüllt';
      case 3:
        return '$personCount Personen';
      case 4:
        if (serviceType == 'cocktail_barservice' ||
            serviceType == 'bar_service') {
          final total = selectedBarDrinks.length + selectedAlcoholItems.length;
          return total == 0 ? 'Keine ausgewählt' : '$total ausgewählt';
        }
        return 'Übersprungen';
      case 5:
        return selectedRecipes.isEmpty
            ? 'Keine ausgewählt'
            : serviceType == 'mocktail_service'
            ? '${selectedRecipes.length} Mocktails'
            : '${selectedRecipes.length} Cocktails';
      case 6:
        return selectedRecipes.isEmpty
            ? 'Keine Cocktails'
            : '${selectedRecipes.length} konfiguriert';
      case 7:
        final count7 = additionalServicesList.length;
        return count7 == 0 ? 'Keine' : '$count7 ausgewählt';
      case 8:
        return 'Alles prüfen & abschließen';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    remarksController.dispose();
    for (final controller in shotQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
