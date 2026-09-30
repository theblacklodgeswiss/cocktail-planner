import 'package:flutter/material.dart';

/// Parses a decimal number, accepting both "." and "," as decimal separator.
double? parseDecimal(String input) =>
    double.tryParse(input.trim().replaceAll(',', '.'));

/// Suffix button that toggles the sign of the number in [controller].
///
/// iOS numeric keyboards have no minus key (the `signed` option of
/// [TextInputType.numberWithOptions] is ignored there), so negative values
/// such as discounts need an explicit toggle.
class SignToggleButton extends StatelessWidget {
  const SignToggleButton({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.exposure),
      tooltip: '+/−',
      onPressed: () {
        final text = controller.text.trim();
        final toggled = text.startsWith('-') ? text.substring(1) : '-$text';
        controller.value = TextEditingValue(
          text: toggled,
          selection: TextSelection.collapsed(offset: toggled.length),
        );
      },
    );
  }
}
