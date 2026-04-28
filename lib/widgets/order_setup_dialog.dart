import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../utils/currency.dart';

class OrderSetupData {
  final String orderName;
  final String? phoneNumber;
  final DateTime? eventDate;
  final TimeOfDay? eventTime;
  final String? address;
  final int personCount;
  final int? distanceKm;
  final String currency;
  final String drinkerType;
  final String serviceType;
  final List<String>? barDrinks;
  final List<String>? alcoholPurchase;
  final List<String>? additionalServices;
  final String? remarks;

  OrderSetupData({
    required this.orderName,
    this.phoneNumber,
    this.eventDate,
    this.eventTime,
    this.address,
    required this.personCount,
    this.distanceKm,
    required this.currency,
    required this.drinkerType,
    required this.serviceType,
    this.barDrinks,
    this.alcoholPurchase,
    this.additionalServices,
    this.remarks,
  });
}

class OrderSetupForm extends StatefulWidget {
  final void Function(OrderSetupData data) onSubmit;
  const OrderSetupForm({super.key, required this.onSubmit});

  @override
  State<OrderSetupForm> createState() => _OrderSetupFormState();
}

class _OrderSetupFormState extends State<OrderSetupForm> {
  final _formKey = GlobalKey<FormState>();
  final orderNameCtrl = TextEditingController();
  final phoneNumberCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final personCountCtrl = TextEditingController();
  final distanceCtrl = TextEditingController();
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  String currency = defaultCurrency.code;
  String drinkerType = 'normal';
  String serviceType = 'cocktail_barservice';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'order_setup.title'.tr(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('order_setup.hint'.tr()),
              const SizedBox(height: 16),
              Text(
                'order_setup.service_type_label'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('order_setup.service_cocktail_barservice'.tr()),
                    selected: serviceType == 'cocktail_barservice',
                    onSelected: (_) =>
                        setState(() => serviceType = 'cocktail_barservice'),
                  ),
                  ChoiceChip(
                    label: Text('order_setup.service_cocktailservice'.tr()),
                    selected: serviceType == 'cocktail_service',
                    onSelected: (_) =>
                        setState(() => serviceType = 'cocktail_service'),
                  ),
                  ChoiceChip(
                    label: Text('order_setup.service_mocktailservice'.tr()),
                    selected: serviceType == 'mocktail_service',
                    onSelected: (_) =>
                        setState(() => serviceType = 'mocktail_service'),
                  ),
                  ChoiceChip(
                    label: Text('order_setup.service_barservice'.tr()),
                    selected: serviceType == 'bar_service',
                    onSelected: (_) =>
                        setState(() => serviceType = 'bar_service'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: orderNameCtrl,
                decoration: InputDecoration(
                  labelText: 'order_setup.order_name_label'.tr(),
                  hintText: 'order_setup.order_name_hint'.tr(),
                  prefixIcon: const Icon(Icons.badge),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'order_setup.required'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneNumberCtrl,
                decoration: InputDecoration(
                  labelText: 'order_setup.phone_label'.tr(),
                  hintText: 'order_setup.phone_hint'.tr(),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _eventDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (date != null) {
                    setState(() => _eventDate = date);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'order_setup.event_date_label'.tr(),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _eventDate != null
                        ? DateFormat('dd.MM.yyyy').format(_eventDate!)
                        : 'order_setup.event_date_hint'.tr(),
                    style: TextStyle(
                      color: _eventDate != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime:
                        _eventTime ?? const TimeOfDay(hour: 18, minute: 0),
                  );
                  if (time != null) {
                    setState(() => _eventTime = time);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'order_setup.event_time_label'.tr(),
                    prefixIcon: const Icon(Icons.access_time),
                  ),
                  child: Text(
                    _eventTime != null
                        ? _eventTime!.format(context)
                        : 'order_setup.event_time_hint'.tr(),
                    style: TextStyle(
                      color: _eventTime != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'order_setup.address_label'.tr(),
                  hintText: 'order_setup.address_hint'.tr(),
                  prefixIcon: const Icon(Icons.location_on),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: personCountCtrl,
                decoration: InputDecoration(
                  labelText: 'order_setup.person_count_label'.tr(),
                  prefixIcon: const Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || int.tryParse(v) == null
                    ? 'order_setup.required'.tr()
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: distanceCtrl,
                decoration: InputDecoration(
                  labelText: 'order_setup.distance_label'.tr(),
                  prefixIcon: const Icon(Icons.directions_car),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('order_setup.currency_label'.tr()),
                  ),
                  ...Currency.values.map(
                    (entry) => ChoiceChip(
                      label: Text(entry.code),
                      selected: currency == entry.code,
                      onSelected: (_) => setState(() => currency = entry.code),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('order_setup.drinker_type_label'.tr()),
                  ),
                  ChoiceChip(
                    label: Text('order_setup.drinker_light'.tr()),
                    selected: drinkerType == 'light',
                    onSelected: (_) => setState(() => drinkerType = 'light'),
                  ),
                  ChoiceChip(
                    label: Text('order_setup.drinker_normal'.tr()),
                    selected: drinkerType == 'normal',
                    onSelected: (_) => setState(() => drinkerType = 'normal'),
                  ),
                  ChoiceChip(
                    label: Text('order_setup.drinker_heavy'.tr()),
                    selected: drinkerType == 'heavy',
                    onSelected: (_) => setState(() => drinkerType = 'heavy'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // Optionally clear form or notify parent
                    },
                    child: Text('common.cancel'.tr()),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSubmit(
                          OrderSetupData(
                            orderName: orderNameCtrl.text.trim(),
                            phoneNumber: phoneNumberCtrl.text.trim().isEmpty
                                ? null
                                : phoneNumberCtrl.text.trim(),
                            eventDate: _eventDate,
                            eventTime: _eventTime,
                            address: addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                            personCount: int.parse(personCountCtrl.text.trim()),
                            distanceKm: int.tryParse(distanceCtrl.text.trim()),
                            currency: currency,
                            drinkerType: drinkerType,
                            serviceType: serviceType,
                          ),
                        );
                      }
                    },
                    child: Text('common.next'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
