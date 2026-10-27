import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../order_form_state.dart';

/// Step 1: name and phone number.
class ContactStep extends StatelessWidget {
  const ContactStep({
    super.key,
    required this.form,
    required this.desktopActions,
  });

  /// The shared wizard state (read for display, mutated via `update`).
  final OrderFormState form;

  /// Builds the desktop back/next row (only shown at width >= 600).
  final Widget Function() desktopActions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_setup.basic_info_title'.tr(),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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
            controller: form.nameController,
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
            controller: form.phoneController,
            decoration: InputDecoration(
              labelText: '${'order_setup.phone_label'.tr()} *',
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
            desktopActions(),
          ],
        ],
      ),
    );
  }
}
