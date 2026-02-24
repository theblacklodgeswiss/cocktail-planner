import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class OrderSetupData {
  final String orderName;
  final int personCount;
  final int? distanceKm;
  final String currency;
  final String drinkerType;

  OrderSetupData({
    required this.orderName,
    required this.personCount,
    this.distanceKm,
    required this.currency,
    required this.drinkerType,
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
  final personCountCtrl = TextEditingController();
  final distanceCtrl = TextEditingController();
  String currency = 'CHF';
  String drinkerType = 'normal';

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
              Text('order_setup.title'.tr(), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('order_setup.hint'.tr()),
              const SizedBox(height: 16),
              TextFormField(
                controller: orderNameCtrl,
                decoration: InputDecoration(
                  labelText: 'order_setup.order_name_label'.tr(),
                  hintText: 'order_setup.order_name_hint'.tr(),
                  prefixIcon: const Icon(Icons.event),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'order_setup.required'.tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: personCountCtrl,
                decoration: InputDecoration(
                  labelText: 'order_setup.person_count_label'.tr(),
                  prefixIcon: const Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || int.tryParse(v) == null ? 'order_setup.required'.tr() : null,
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
                  ChoiceChip(
                    label: const Text('CHF'),
                    selected: currency == 'CHF',
                    onSelected: (_) => setState(() => currency = 'CHF'),
                  ),
                  ChoiceChip(
                    label: const Text('EUR'),
                    selected: currency == 'EUR',
                    onSelected: (_) => setState(() => currency = 'EUR'),
                  ),
                  ChoiceChip(
                    label: const Text('USD'),
                    selected: currency == 'USD',
                    onSelected: (_) => setState(() => currency = 'USD'),
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
                            personCount: int.parse(personCountCtrl.text.trim()),
                            distanceKm: int.tryParse(distanceCtrl.text.trim()),
                            currency: currency,
                            drinkerType: drinkerType,
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
