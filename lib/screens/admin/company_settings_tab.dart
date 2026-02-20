import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../data/settings_repository.dart';

/// Tab for editing company information stored in AppSettings.
class CompanySettingsTab extends StatefulWidget {
  const CompanySettingsTab({super.key});

  @override
  State<CompanySettingsTab> createState() => _CompanySettingsTabState();
}

class _CompanySettingsTabState extends State<CompanySettingsTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _companyNameCtrl;
  late TextEditingController _companyOwnerCtrl;
  late TextEditingController _companyStreetCtrl;
  late TextEditingController _companyCityCtrl;
  late TextEditingController _companyPhoneCtrl;
  late TextEditingController _companyEmailCtrl;
  late TextEditingController _bankIbanCtrl;
  late TextEditingController _twintNumberCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadSettings();
  }

  void _initControllers() {
    _companyNameCtrl = TextEditingController();
    _companyOwnerCtrl = TextEditingController();
    _companyStreetCtrl = TextEditingController();
    _companyCityCtrl = TextEditingController();
    _companyPhoneCtrl = TextEditingController();
    _companyEmailCtrl = TextEditingController();
    _bankIbanCtrl = TextEditingController();
    _twintNumberCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyOwnerCtrl.dispose();
    _companyStreetCtrl.dispose();
    _companyCityCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyEmailCtrl.dispose();
    _bankIbanCtrl.dispose();
    _twintNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _companyNameCtrl.text = settings.companyName;
      _companyOwnerCtrl.text = settings.companyOwner;
      _companyStreetCtrl.text = settings.companyStreet;
      _companyCityCtrl.text = settings.companyCity;
      _companyPhoneCtrl.text = settings.companyPhone;
      _companyEmailCtrl.text = settings.companyEmail;
      _bankIbanCtrl.text = settings.bankIban;
      _twintNumberCtrl.text = settings.twintNumber;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final current = settingsRepository.current;
      final updated = current.copyWith(
        companyName: _companyNameCtrl.text.trim(),
        companyOwner: _companyOwnerCtrl.text.trim(),
        companyStreet: _companyStreetCtrl.text.trim(),
        companyCity: _companyCityCtrl.text.trim(),
        companyPhone: _companyPhoneCtrl.text.trim(),
        companyEmail: _companyEmailCtrl.text.trim(),
        bankIban: _bankIbanCtrl.text.trim(),
        twintNumber: _twintNumberCtrl.text.trim(),
      );
      await settingsRepository.save(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.company_saved'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.company_save_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Info Section
            Text(
              'admin.company_info_section'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _companyNameCtrl,
              label: 'admin.company_name'.tr(),
              icon: Icons.business,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _companyOwnerCtrl,
              label: 'admin.company_owner'.tr(),
              icon: Icons.person,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _companyStreetCtrl,
              label: 'admin.company_street'.tr(),
              icon: Icons.location_on,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _companyCityCtrl,
              label: 'admin.company_city'.tr(),
              icon: Icons.location_city,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _companyPhoneCtrl,
              label: 'admin.company_phone'.tr(),
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _companyEmailCtrl,
              label: 'admin.company_email'.tr(),
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),

            // Payment Info Section
            Text(
              'admin.payment_info_section'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _bankIbanCtrl,
              label: 'admin.bank_iban'.tr(),
              icon: Icons.account_balance,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _twintNumberCtrl,
              label: 'admin.twint_number'.tr(),
              icon: Icons.payment,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text('common.save'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'admin.field_required'.tr();
        }
        return null;
      },
    );
  }
}
