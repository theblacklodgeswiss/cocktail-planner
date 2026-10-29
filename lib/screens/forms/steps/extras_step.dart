import 'package:flutter/material.dart';

import '../order_form_state.dart';
import 'additional_services_section.dart';
import 'overview_section.dart';

/// Step 4 "Noch etwas dazu?": additional services, then the summary. The
/// single submit button is in the bottom bar.
class ExtrasStep extends StatelessWidget {
  const ExtrasStep({
    super.key,
    required this.form,
    required this.isEmployeeOrHigher,
    required this.onEditStep,
  });

  final OrderFormState form;
  final bool isEmployeeOrHigher;

  /// Jumps back to a step from the summary.
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdditionalServicesSection(form: form),
        OverviewSection(
          form: form,
          isEmployeeOrHigher: isEmployeeOrHigher,
          onEditStep: onEditStep,
        ),
      ],
    );
  }
}
