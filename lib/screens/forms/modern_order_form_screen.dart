import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
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
  final int _totalSteps = 5;
  
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
  List<Recipe> _selectedRecipes = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCocktailData();
  }

  void _loadCocktailData() {
    _dataFuture = cocktailRepository.load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      // Animate PageView on mobile layout
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentStep,
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
      setState(() => _currentStep--);
      // Animate PageView on mobile layout
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentStep,
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
    } else if (_eventDate == null) {
      errorMessage = 'order_setup.required_date'.tr();
      _currentStep = 2; // Jump to Event Details step
    } else if (_selectedRecipes.isEmpty) {
      errorMessage = 'order_setup.required_cocktails'.tr();
      _currentStep = 4; // Jump to Cocktail Selection step
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
              _buildCocktailSelectionStep(),
            ],
          ),
        ),
        // Navigation Buttons
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('common.back'.tr()),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: _currentStep > 0 ? 1 : 2,
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
                      Icons.local_bar,
                      'Cocktail-Auswahl',
                      'Cocktails',
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
            child: Center(
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
        return _selectedRecipes.isEmpty
            ? 'Keine ausgewählt'
            : '${_selectedRecipes.length} Cocktails';
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
        return _buildCocktailSelectionStep();
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
              final date = await showDatePicker(
                context: context,
                initialDate: _eventDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
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
              final time = await showTimePicker(
                context: context,
                initialTime: _eventTime ?? TimeOfDay.now(),
              );
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
          max: 2500,
          divisions: 49,
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
            Text('2500', style: Theme.of(context).textTheme.bodySmall),
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
          max: 2000,
          divisions: 100,
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
            Text('2000 km', style: Theme.of(context).textTheme.bodySmall),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildCocktailList(List<Recipe> recipes) {
    final filtered = recipes.where((recipe) {
      if (_searchQuery.isEmpty) return true;
      return recipe.name.toLowerCase().contains(_searchQuery);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Grid für Desktop (≥600px)
        if (constraints.maxWidth >= 600) {
          final crossAxisCount = constraints.maxWidth > 900 ? 3 : 2;
          
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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
      },
    );
  }

  Widget _buildCocktailCard(Recipe recipe) {
    final isSelected = _selectedRecipes.any((r) => r.id == recipe.id);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipe.isShot) ...[
                      const SizedBox(height: 4),
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
                          'dialog.tag_shot'.tr(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
}
