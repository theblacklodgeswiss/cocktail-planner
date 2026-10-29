import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/pill_filter.dart';
import '../../utils/currency.dart';

/// Result from the initial setup sheet (master data).
typedef InitialSetupResult = ({
  String name,
  int personCount,
  String drinkerType,
  Currency currency,
  int distanceKm,
});

/// Shows the initial setup sheet for all master data.
/// This is shown at the beginning of the shopping list wizard. Like the old
/// dialog it can only be left with the buttons (barrier and swipe are
/// ignored); "Abbrechen" returns null.
Future<InitialSetupResult?> showInitialSetupDialog(
  BuildContext context, {
  String? prefilledName,
  int? prefilledPersonCount,
}) {
  return showAppSheet<InitialSetupResult>(
    context,
    builder: (_) => PopScope(
      canPop: false,
      child: _InitialSetupForm(
        prefilledName: prefilledName,
        prefilledPersonCount: prefilledPersonCount,
      ),
    ),
  );
}

class _InitialSetupForm extends StatefulWidget {
  const _InitialSetupForm({this.prefilledName, this.prefilledPersonCount});

  final String? prefilledName;
  final int? prefilledPersonCount;

  @override
  State<_InitialSetupForm> createState() => _InitialSetupFormState();
}

class _InitialSetupFormState extends State<_InitialSetupForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.prefilledName ?? '',
  );
  late final TextEditingController _persons = TextEditingController(
    text:
        widget.prefilledPersonCount != null && widget.prefilledPersonCount! > 0
        ? widget.prefilledPersonCount.toString()
        : '',
  );
  final TextEditingController _distance = TextEditingController();
  String _drinkerType = 'normal';
  Currency _currency = defaultCurrency;
  String? _nameError;
  String? _personError;
  String? _distanceError;

  @override
  void dispose() {
    _name.dispose();
    _persons.dispose();
    _distance.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final personCount = int.tryParse(_persons.text.trim()) ?? 0;
    final distanceKm = int.tryParse(_distance.text.trim()) ?? -1;

    final nameErr = name.isEmpty ? 'shopping.name_required'.tr() : null;
    final personErr = personCount <= 0
        ? 'shopping.person_count_error'.tr()
        : null;
    final distErr = distanceKm < 0 ? 'shopping.distance_error'.tr() : null;
    if (nameErr != null || personErr != null || distErr != null) {
      setState(() {
        _nameError = nameErr;
        _personError = personErr;
        _distanceError = distErr;
      });
      return;
    }
    Navigator.pop(context, (
      name: name,
      personCount: personCount,
      drinkerType: _drinkerType,
      currency: _currency,
      distanceKm: distanceKm,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'shopping.setup_title'.tr(),
          style: AppText.heroTitle.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          'shopping.setup_description'.tr(),
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpace.s16),
        TextField(
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'shopping.order_name_label'.tr(),
            hintText: 'shopping.order_name_hint'.tr(),
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        const SizedBox(height: AppSpace.s12),
        TextField(
          controller: _persons,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'shopping.person_count_label'.tr(),
            hintText: 'shopping.person_count_hint'.tr(),
            errorText: _personError,
          ),
          onChanged: (_) {
            if (_personError != null) setState(() => _personError = null);
          },
        ),
        const SizedBox(height: AppSpace.s12),
        TextField(
          controller: _distance,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'shopping.distance_label'.tr(),
            hintText: 'shopping.distance_hint'.tr(),
            errorText: _distanceError,
            suffixText: 'km',
          ),
          onChanged: (_) {
            if (_distanceError != null) setState(() => _distanceError = null);
          },
        ),
        const SizedBox(height: AppSpace.s16),
        Text(
          'shopping.currency'.tr(),
          style: AppText.section.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s4),
        PillFilter<Currency>(
          options: [for (final c in Currency.values) PillOption(c, c.code)],
          value: _currency,
          onChanged: (c) => setState(() => _currency = c),
        ),
        const SizedBox(height: AppSpace.s12),
        Text(
          'shopping.drinker_type'.tr(),
          style: AppText.section.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s4),
        PillFilter<String>(
          options: [
            PillOption('light', 'orders.drinker_light'.tr()),
            PillOption('normal', 'orders.drinker_normal'.tr()),
            PillOption('heavy', 'orders.drinker_heavy'.tr()),
          ],
          value: _drinkerType,
          onChanged: (v) => setState(() => _drinkerType = v),
        ),
        const SizedBox(height: AppSpace.s24),
        PrimaryButton(label: 'common.next'.tr(), onPressed: _submit),
        const SizedBox(height: AppSpace.s8),
        TextAction(
          label: 'common.cancel'.tr(),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
