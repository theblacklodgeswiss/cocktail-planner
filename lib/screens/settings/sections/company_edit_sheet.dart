import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../models/app_settings.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';

/// Opens the company edit form; resolves to the updated settings or null.
Future<AppSettings?> showCompanyEditSheet(
  BuildContext context,
  AppSettings settings,
) => showAppSheet<AppSettings>(
  context,
  builder: (sheet) => _CompanyForm(settings: settings),
);

class _CompanyForm extends StatefulWidget {
  const _CompanyForm({required this.settings});

  final AppSettings settings;

  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  late final _name = TextEditingController(text: widget.settings.companyName);
  late final _owner = TextEditingController(text: widget.settings.companyOwner);
  late final _street = TextEditingController(
    text: widget.settings.companyStreet,
  );
  late final _city = TextEditingController(text: widget.settings.companyCity);
  late final _phone = TextEditingController(text: widget.settings.companyPhone);
  late final _email = TextEditingController(text: widget.settings.companyEmail);
  late final _iban = TextEditingController(text: widget.settings.bankIban);
  late final _twint = TextEditingController(text: widget.settings.twintNumber);

  @override
  void dispose() {
    for (final c in [_name, _owner, _street, _city, _phone, _email, _iban, _twint]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String labelKey,
    IconData icon, [
    TextInputType? type,
  ]) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s12),
    child: TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(labelText: labelKey.tr(), prefixIcon: Icon(icon)),
    ),
  );

  void _save() {
    Navigator.of(context).pop(
      widget.settings.copyWith(
        companyName: _name.text.trim(),
        companyOwner: _owner.text.trim(),
        companyStreet: _street.text.trim(),
        companyCity: _city.text.trim(),
        companyPhone: _phone.text.trim(),
        companyEmail: _email.text.trim(),
        bankIban: _iban.text.trim(),
        twintNumber: _twint.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'settings.company_section'.tr(),
          style: AppText.heroTitle.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s16),
        _field(_name, 'admin.company_name', Icons.business),
        _field(_owner, 'admin.company_owner', Icons.person),
        _field(_street, 'admin.company_street', Icons.location_on),
        _field(_city, 'admin.company_city', Icons.location_city),
        _field(_phone, 'admin.company_phone', Icons.phone, TextInputType.phone),
        _field(
          _email,
          'admin.company_email',
          Icons.email,
          TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          'admin.payment_info_section'.tr(),
          style: AppText.section.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s12),
        _field(_iban, 'admin.bank_iban', Icons.account_balance),
        _field(
          _twint,
          'admin.twint_number',
          Icons.payment,
          TextInputType.phone,
        ),
        const SizedBox(height: AppSpace.s12),
        PrimaryButton(label: 'common.save'.tr(), onPressed: _save),
        const SizedBox(height: AppSpace.s8),
        TextAction(
          label: 'common.cancel'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
