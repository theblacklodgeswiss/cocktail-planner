import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../utils/url_utils.dart';
import '../../data/cocktail_repository.dart';
import '../../models/cocktail_data.dart';
import '../../models/recipe.dart';
import '../../widgets/order_setup_dialog.dart';

/// Result from the modern order form containing both setup data and selected recipes
class OrderFormResult {
  final OrderSetupData setupData;
  final List<Recipe> selectedRecipes;

  OrderFormResult({
    required this.setupData,
    required this.selectedRecipes,
  });
}

/// Modern multi-step order form inspired by Roamy app design.
/// Features card-based UI, smooth transitions, and touch-optimized controls.
class ModernOrderFormScreen extends StatefulWidget {
  final void Function(OrderFormResult result)? onSubmit;

  const ModernOrderFormScreen({super.key, this.onSubmit});

  @override
  State<ModernOrderFormScreen> createState() => _ModernOrderFormScreenState();
}

class _ModernOrderFormScreenState extends State<ModernOrderFormScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 7;
  
  Future<CocktailData>? _dataFuture;

  // Form data
  String _serviceType = 'cocktail_barservice';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  final TextEditingController _addressController = TextEditingController();
  int _personCount = 100;
  int _distanceKm = 10;
  String _currency = 'CHF';
  String _drinkerType = 'normal';
  final List<Recipe> _selectedRecipes = [];
  String _searchQuery = '';
  String _cocktailFilter = 'all'; // 'all', 'cocktails', 'shots'
  final Set<String> _selectedBarDrinks = {};
  final Set<String> _selectedAlcoholItems = {};
  final Set<String> _selectedAdditionalServices = {};
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCocktailData();
    // Read step from URL query parameter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      final stepParam = uri.queryParameters['step'];
      if (stepParam != null) {
        final step = int.tryParse(stepParam) ?? 0;
        if (step >= 0 && step < _totalSteps) {
          setState(() => _currentStep = step);
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
    _dataFuture = cocktailRepository.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync step from URL when navigating back/forward
    final uri = Uri.base;
    final stepParam = uri.queryParameters['step'];
    if (stepParam != null) {
      final step = int.tryParse(stepParam) ?? 0;
      if (step >= 0 && step < _totalSteps && step != _currentStep) {
        setState(() => _currentStep = step);
        if (_pageController.hasClients) {
          _pageController.jumpToPage(step);
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // Update browser URL without affecting GoRouter's navigation stack
  void _updateUrlWithoutNavigation(int step) {
    final currentUrl = Uri.base;
    final newUrl = currentUrl.replace(queryParameters: {'step': step.toString()});
    updateBrowserUrl(newUrl.toString());
  }

  // Show date picker (Cupertino style with mouse wheel support on Web)
  Future<DateTime?> _showCupertinoDatePicker() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 730));

    // Use Cupertino Picker everywhere with proper mouse/touch support
    DateTime selectedDate = _eventDate ?? now;

    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // Header with Cancel and OK buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'common.cancel'.tr(),
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    Text(
                      'order_setup.event_date_label'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(selectedDate),
                      child: Text(
                        'common.ok'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cupertino Date Picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selectedDate,
                  minimumDate: now,
                  maximumDate: maxDate,
                  onDateTimeChanged: (DateTime newDate) {
                    selectedDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show time picker (Cupertino style with mouse wheel support on Web)
  Future<TimeOfDay?> _showCupertinoTimePicker() async {
    final initialTime = _eventTime ?? const TimeOfDay(hour: 18, minute: 0);

    // Use Cupertino Picker everywhere with proper mouse/touch support
    DateTime selectedDateTime = DateTime(
      2000,
      1,
      1,
      initialTime.hour,
      initialTime.minute,
    );

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 300,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // Header with Cancel and OK buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'common.cancel'.tr(),
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    Text(
                      'order_setup.event_time_label'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final timeOfDay = TimeOfDay(
                          hour: selectedDateTime.hour,
                          minute: selectedDateTime.minute,
                        );
                        Navigator.of(context).pop(timeOfDay);
                      },
                      child: Text(
                        'common.ok'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cupertino Time Picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: selectedDateTime,
                  use24hFormat: true,
                  onDateTimeChanged: (DateTime newDateTime) {
                    selectedDateTime = newDateTime;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      final nextStep = _currentStep + 1;
      setState(() => _currentStep = nextStep);
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
      _submitForm();
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      final prevStep = _currentStep - 1;
      setState(() => _currentStep = prevStep);
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

  void _submitForm() {
    // Validate required fields
    String? errorMessage;
    
    if (_nameController.text.trim().isEmpty) {
      errorMessage = 'order_setup.required_name'.tr();
      _currentStep = 1; // Jump to Basic Info step
      _updateUrlWithoutNavigation(1);
    } else if (_eventDate == null) {
      errorMessage = 'order_setup.required_date'.tr();
      _currentStep = 2; // Jump to Event Details step
      _updateUrlWithoutNavigation(2);
    } else if (_selectedRecipes.isEmpty) {
      errorMessage = 'order_setup.required_cocktails'.tr();
      _currentStep = 5; // Jump to Cocktail Selection step (updated from 4 to 5)
      _updateUrlWithoutNavigation(5);
    }
    
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      setState(() {}); // Update UI to show correct step
      return;
    }

    final setupData = OrderSetupData(
      orderName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      eventDate: _eventDate,
      eventTime: _eventTime,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      personCount: _personCount,
      distanceKm: _distanceKm,
      currency: _currency,
      drinkerType: _drinkerType,
      serviceType: _serviceType,
      barDrinks: _selectedBarDrinks.isEmpty ? null : _selectedBarDrinks.toList(),
      alcoholPurchase: _selectedAlcoholItems.isEmpty ? null : _selectedAlcoholItems.toList(),
      additionalServices: _selectedAdditionalServices.isEmpty ? null : _selectedAdditionalServices.toList(),
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
    );

    final result = OrderFormResult(
      setupData: setupData,
      selectedRecipes: _selectedRecipes,
    );

    if (widget.onSubmit != null) {
      widget.onSubmit!(result);
    } else {
      context.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text('order_setup.title'.tr()),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: index <= _currentStep
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
            onPageChanged: (index) => setState(() => _currentStep = index),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildServiceTypeStep(),
              _buildBasicInfoStep(),
              _buildEventDetailsStep(),
              _buildPreferencesStep(),
              _buildBarAlcoholStep(),
              _buildCocktailSelectionStep(),
              _buildAdditionalServicesStep(),
            ],
          ),
        ),
        // Navigation Buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: _currentStep > 0
                      ? OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('common.back'.tr()),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _nextStep,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentStep < _totalSteps - 1
                          ? 'common.next'.tr()
                          : 'common.finish'.tr(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Side: Vertical Stepper
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border(
              right: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'order_setup.title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildStepperItem(
                      0,
                      Icons.celebration,
                      'order_setup.service_type_label'.tr(),
                      'Service auswählen',
                    ),
                    _buildStepperItem(
                      1,
                      Icons.person_outline,
                      'order_setup.basic_info_title'.tr(),
                      'Kontaktdaten',
                    ),
                    _buildStepperItem(
                      2,
                      Icons.calendar_today,
                      'order_setup.event_details_title'.tr(),
                      'Event-Details',
                    ),
                    _buildStepperItem(
                      3,
                      Icons.tune,
                      'order_setup.preferences_title'.tr(),
                      'Präferenzen',
                    ),
                    _buildStepperItem(
                      4,
                      Icons.liquor,
                      'Bargetränke & Alkohol',
                      'Optional',
                    ),
                    _buildStepperItem(
                      5,
                      Icons.local_bar,
                      'Cocktail-Auswahl',
                      'Cocktails',
                    ),
                    _buildStepperItem(
                      6,
                      Icons.miscellaneous_services,
                      'Zusatzleistungen',
                      'Optional',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Right Side: Content
        Expanded(
          child: SingleChildScrollView(
            child: _currentStep >= 5
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

  Widget _buildStepperItem(int step, IconData icon, String title, String subtitle) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _currentStep = step);
            // Update URL without affecting navigation stack
            _updateUrlWithoutNavigation(step);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : icon,
                    color: isActive || isCompleted
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getStepTitle(step),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              color: isActive
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return _serviceType == 'cocktail_barservice'
            ? 'Cocktail & Bar'
            : _serviceType == 'cocktail_service'
                ? 'Nur Cocktail'
                : 'Nur Bar';
      case 1:
        return _nameController.text.trim().isEmpty
            ? 'Nicht ausgefüllt'
            : _nameController.text.trim();
      case 2:
        return _eventDate != null
            ? DateFormat('dd.MM.yyyy').format(_eventDate!)
            : 'Nicht ausgefüllt';
      case 3:
        return '$_personCount Personen';
      case 4:
        if (_serviceType == 'cocktail_barservice' || _serviceType == 'bar_service') {
          final total = _selectedBarDrinks.length + _selectedAlcoholItems.length;
          return total == 0 ? 'Keine ausgewählt' : '$total ausgewählt';
        }
        return 'Übersprungen';
      case 5:
        return _selectedRecipes.isEmpty
            ? 'Keine ausgewählt'
            : '${_selectedRecipes.length} Cocktails';
      case 6:
        final count = _selectedAdditionalServices.length;
        return count == 0 ? 'Keine' : '$count ausgewählt';
      default:
        return '';
    }
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildServiceTypeStep();
      case 1:
        return _buildBasicInfoStep();
      case 2:
        return _buildEventDetailsStep();
      case 3:
        return _buildPreferencesStep();
      case 4:
        return _buildBarAlcoholStep();
      case 5:
        return _buildCocktailSelectionStep();
      case 6:
        return _buildAdditionalServicesStep();
      default:
        return Container();
    }
  }

  Widget _buildServiceTypeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_setup.service_type_title'.tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.service_type_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          _buildServiceCard(
            'cocktail_barservice',
            Icons.celebration,
            'order_setup.service_cocktail_barservice'.tr(),
            'order_setup.service_cocktail_barservice_desc'.tr(),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            'cocktail_service',
            Icons.local_bar,
            'order_setup.service_cocktailservice'.tr(),
            'order_setup.service_cocktailservice_desc'.tr(),
          ),
          const SizedBox(height: 16),
          _buildServiceCard(
            'bar_service',
            Icons.liquor,
            'order_setup.service_barservice'.tr(),
            'order_setup.service_barservice_desc'.tr(),
          ),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            _buildDesktopActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    String value,
    IconData icon,
    String title,
    String description,
  ) {
    final isSelected = _serviceType == value;
    return Card(
      elevation: isSelected ? 8 : 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _serviceType = value);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_setup.basic_info_title'.tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.basic_info_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'order_setup.order_name_label'.tr(),
              hintText: 'order_setup.order_name_hint'.tr(),
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'order_setup.phone_label'.tr(),
              hintText: 'order_setup.phone_hint'.tr(),
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
          ),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            _buildDesktopActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildEventDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_setup.event_details_title'.tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.event_details_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          _buildDateTimePicker(),
          const SizedBox(height: 20),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'order_setup.address_label'.tr(),
              hintText: 'order_setup.address_hint'.tr(),
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            maxLines: 3,
          ),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            _buildDesktopActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              final date = await _showCupertinoDatePicker();
              if (date != null) {
                HapticFeedback.selectionClick();
                setState(() => _eventDate = date);
              }
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'order_setup.event_date_label'.tr(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _eventDate != null
                              ? DateFormat('EEEE, dd. MMMM yyyy').format(_eventDate!)
                              : 'order_setup.event_date_hint'.tr(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
          InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();
              final time = await _showCupertinoTimePicker();
              if (time != null) {
                HapticFeedback.selectionClick();
                setState(() => _eventTime = time);
              }
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'order_setup.event_time_label'.tr(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _eventTime != null
                              ? _eventTime!.format(context)
                              : 'order_setup.event_time_hint'.tr(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_setup.preferences_title'.tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.preferences_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          _buildPersonCountSlider(),
          const SizedBox(height: 32),
          _buildDistanceSlider(),
          const SizedBox(height: 32),
          _buildCurrencySelector(),
          const SizedBox(height: 32),
          _buildDrinkerTypeSelector(),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            _buildDesktopActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonCountSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'order_setup.person_count_label'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_personCount',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Slider(
          value: _personCount.toDouble(),
          min: 50,
          max: 1000,
          divisions: 19,
          label: '$_personCount',
          onChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() => _personCount = value.round());
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('50', style: Theme.of(context).textTheme.bodySmall),
            Text('1000', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildDistanceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'order_setup.distance_label'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_distanceKm km',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Slider(
          value: _distanceKm.toDouble(),
          min: 0,
          max: 1000,
          divisions: 50,
          label: '$_distanceKm km',
          onChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() => _distanceKm = value.round());
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 km', style: Theme.of(context).textTheme.bodySmall),
            Text('1000 km', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'order_setup.currency_label'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'CHF', label: Text('CHF')),
            ButtonSegment(value: 'EUR', label: Text('EUR')),
            ButtonSegment(value: 'USD', label: Text('USD')),
          ],
          selected: {_currency},
          onSelectionChanged: (values) {
            HapticFeedback.selectionClick();
            setState(() => _currency = values.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.comfortable,
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrinkerTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'order_setup.drinker_type_label'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildDrinkerChip('light', Icons.local_drink, 'order_setup.drinker_light'.tr()),
            _buildDrinkerChip('normal', Icons.local_bar, 'order_setup.drinker_normal'.tr()),
            _buildDrinkerChip('heavy', Icons.sports_bar, 'order_setup.drinker_heavy'.tr()),
          ],
        ),
      ],
    );
  }

  Widget _buildDrinkerChip(String value, IconData icon, String label) {
    final isSelected = _drinkerType == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _drinkerType = value);
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildBarDrinksSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'order_setup.bar_drinks_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'order_setup.bar_drinks_subtitle'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBarDrinkCheckbox('whiskey_mix', 'Whiskey & Mischgetränke'),
            _buildBarDrinkCheckbox('vodka_mix', 'Vodka & Mischgetränke'),
            _buildBarDrinkCheckbox('gin_mix', 'Gin & Mischgetränke'),
            _buildBarDrinkCheckbox('shots', 'Shots'),
            _buildBarDrinkCheckbox('other', 'Sonstiges'),
          ],
        ),
      ],
    );
  }

  Widget _buildBarDrinkCheckbox(String value, String label) {
    final isSelected = _selectedBarDrinks.contains(value);
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        HapticFeedback.selectionClick();
        setState(() {
          if (selected) {
            _selectedBarDrinks.add(value);
          } else {
            _selectedBarDrinks.remove(value);
          }
        });
      },
      showCheckmark: true,
    );
  }

  Widget _buildAlcoholPurchaseSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'order_setup.alcohol_purchase_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'order_setup.alcohol_purchase_subtitle'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildAlcoholCheckbox('whiskey_chivas', 'Whiskey Chivas 0.7L - 35,-'),
            _buildAlcoholCheckbox('whiskey_black_label', 'Whiskey Black Label 0.7L - 35,-'),
            _buildAlcoholCheckbox('vodka_absolut', 'Vodka Absolut 0.7L - 25,-'),
            _buildAlcoholCheckbox('vodka_three_sixty', 'Vodka Three Sixty 0.7L - 25,-'),
            _buildAlcoholCheckbox('vodka_ciroc', 'Vodka Ciroc 0.7L - 40,-'),
            _buildAlcoholCheckbox('vodka_belvedere', 'Vodka Belvedere 0.7L - 45,-'),
            _buildAlcoholCheckbox('vodka_grey_goose', 'Vodka Grey Goose 0.7L - 45,-'),
            _buildAlcoholCheckbox('gin_bombay', 'Gin Bombay Saphire 0.7L - 25,-'),
            _buildAlcoholCheckbox('gin_bulldog', 'Gin Bulldog 0.7L - 35,-'),
          ],
        ),
      ],
    );
  }

  Widget _buildAlcoholCheckbox(String value, String label) {
    final isSelected = _selectedAlcoholItems.contains(value);
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        HapticFeedback.selectionClick();
        setState(() {
          if (selected) {
            _selectedAlcoholItems.add(value);
          } else {
            _selectedAlcoholItems.remove(value);
          }
        });
      },
      showCheckmark: true,
    );
  }

  Widget _buildBarAlcoholStep() {
    // Skip this step if service type doesn't include bar service
    if (_serviceType != 'cocktail_barservice' && _serviceType != 'bar_service') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Dieser Schritt ist für Ihren ausgewählten Service nicht erforderlich.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Barservice - Welche Getränke sollen ausgeschenkt werden?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wähle alle zutreffenden Kategorien',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          _buildBarDrinksSelector(),
          const SizedBox(height: 32),
          _buildAlcoholPurchaseSelector(),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            _buildDesktopActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildCocktailSelectionStep() {
    return FutureBuilder<CocktailData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final recipes = snapshot.data?.recipes ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'order_setup.cocktail_selection_title'.tr(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
                Text(
                  'order_setup.cocktail_selection_subtitle'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'dialog.search_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
              const SizedBox(height: 16),
              // Filter Chips
              Row(
                children: [
                  FilterChip(
                    selected: _cocktailFilter == 'all',
                    label: Text('Alle'),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _cocktailFilter = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _cocktailFilter == 'cocktails',
                    label: Text('Cocktails'),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _cocktailFilter = 'cocktails');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _cocktailFilter == 'shots',
                    label: Text('Shots'),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _cocktailFilter = 'shots');
                    },
                  ),
                ],
              ),
              if (_selectedRecipes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedRecipes.length} ${_selectedRecipes.length == 1 ? "Cocktail" : "Cocktails"} ausgewählt',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildCocktailList(recipes),
              if (MediaQuery.of(context).size.width >= 600) ...[
                const SizedBox(height: 32),
                _buildDesktopActionButtons(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCocktailList(List<Recipe> recipes) {
    final filtered = recipes.where((recipe) {
      // Suchfilter
      if (_searchQuery.isNotEmpty && !recipe.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      // Typ-Filter
      if (_cocktailFilter == 'cocktails' && recipe.isShot) {
        return false;
      }
      if (_cocktailFilter == 'shots' && !recipe.isShot) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Keine Cocktails gefunden',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Grid für Desktop (≥600px)
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 600) {
      // Berücksichtige die Sidebar (280px) bei der Berechnung
      final availableWidth = screenWidth - 280 - 64; // Sidebar + Padding
      final crossAxisCount = availableWidth > 1400 ? 8 
          : availableWidth > 1200 ? 7 
          : availableWidth > 1000 ? 6 
          : availableWidth > 800 ? 5 
          : availableWidth > 600 ? 4 
          : 3;
      
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.0,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildCocktailCard(filtered[index]);
        },
      );
    }
    
    // Liste für Mobile
    return Column(
      children: filtered.map((recipe) => _buildCocktailCard(recipe)).toList(),
    );
  }

  Widget _buildCocktailCard(Recipe recipe) {
    final isSelected = _selectedRecipes.any((r) => r.id == recipe.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    // Quadratisches Design für Desktop, Liste für Mobile
    if (isDesktop) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (isSelected) {
                _selectedRecipes.removeWhere((r) => r.id == recipe.id);
              } else {
                _selectedRecipes.add(recipe);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon oben
                Icon(
                  Icons.local_bar,
                  size: 24,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                // Name in der Mitte (flexibel)
                Flexible(
                  child: Center(
                    child: Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Badge + Check unten
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (recipe.isShot)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Shot',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                        ),
                      ),
                    if (recipe.isShot) const SizedBox(width: 4),
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile Layout (Liste)
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (isSelected) {
              _selectedRecipes.removeWhere((r) => r.id == recipe.id);
            } else {
              _selectedRecipes.add(recipe);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipe.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (recipe.isShot) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Shot',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalServicesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_setup.additional_services_title'.tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.additional_services_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildServiceCheckbox('booth_360', 'BlackLodge - 360 Booth (600 CHF)'),
              _buildServiceCheckbox('photobox_print', 'BlackLodge - PhotoBox inkl. 300 Druck (500 CHF)'),
              _buildServiceCheckbox('photobox_qr', 'BlackLodge - PhotoBox Digal mit QR Code (300 CHF)'),
              _buildServiceCheckbox('bubble_waffles', 'BlackLodge - Bubble Waffles (250 CHF)'),
              _buildServiceCheckbox('catering', 'BlackLodge - Catering (Preis auf Anfrage)'),
              _buildServiceCheckbox('choreographer', 'Nirosi Singh - Choreographer (Preis auf Anfrage)'),
              _buildServiceCheckbox('dj', 'Extern - DJs (Preis auf Anfrage)'),
              _buildServiceCheckbox('led_screen', 'Extern - LED Screen (Preis auf Anfrage)'),
              _buildServiceCheckbox('security', 'Mudanca Security (min. 2 Securitys á 40 CHF/H)'),
              _buildServiceCheckbox('entry_song', 'Entry Song mit Geige - Praveen (300 CHF)'),
              _buildServiceCheckbox('other_services', 'Sonstiges'),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'order_setup.remarks_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'order_setup.remarks_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _remarksController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'order_setup.remarks_hint'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (MediaQuery.of(context).size.width >= 600) ...[
            const SizedBox(height: 32),
            _buildDesktopActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceCheckbox(String value, String label) {
    final isSelected = _selectedAdditionalServices.contains(value);
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        HapticFeedback.selectionClick();
        setState(() {
          if (selected) {
            _selectedAdditionalServices.add(value);
          } else {
            _selectedAdditionalServices.remove(value);
          }
        });
      },
      showCheckmark: true,
    );
  }

  Widget _buildDesktopActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back),
              label: Text('common.back'.tr()),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          FilledButton.icon(
            onPressed: _nextStep,
            icon: Icon(_currentStep < _totalSteps - 1 ? Icons.arrow_forward : Icons.check),
            label: Text(
              _currentStep < _totalSteps - 1
                  ? 'common.next'.tr()
                  : 'common.finish'.tr(),
            ),
            iconAlignment: IconAlignment.end,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
