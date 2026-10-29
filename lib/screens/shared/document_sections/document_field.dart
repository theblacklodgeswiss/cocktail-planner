import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The `_field` helper that the offer and invoice screens each had: a
/// labelled [TextFormField] that rebuilds the screen on every edit.
///
/// [requiredKey] is the "required" message ('offer.field_required' or
/// 'invoice.field_required'). [autovalidate] null leaves the field's
/// default (invoice), true/false switch on-interaction validation (offer).
class DocumentField extends StatelessWidget {
  const DocumentField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    required this.requiredKey,
    this.hint,
    this.required = false,
    this.validator,
    this.keyboard,
    this.inputFormatters,
    this.maxLines = 1,
    this.autovalidate,
    this.alignLabelWithHint = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final String requiredKey;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool? autovalidate;
  final bool alignLabelWithHint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: alignLabelWithHint ? maxLines > 1 : null,
      ),
      autovalidateMode: autovalidate == null
          ? null
          : (autovalidate!
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled),
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? requiredKey.tr() : null
              : null),
      onChanged: (_) => onChanged(),
    );
  }
}

/// Builds [DocumentField]s with one screen's settings.
class DocumentFieldFactory {
  const DocumentFieldFactory({
    required this.requiredKey,
    required this.onChanged,
    this.autovalidate,
    this.alignLabelWithHint = false,
  });

  final String requiredKey;
  final VoidCallback onChanged;
  final bool? autovalidate;
  final bool alignLabelWithHint;

  Widget call({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    FormFieldValidator<String>? validator,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) => DocumentField(
    controller: controller,
    label: label,
    hint: hint,
    required: required,
    requiredKey: requiredKey,
    validator: validator,
    keyboard: keyboard,
    inputFormatters: inputFormatters,
    maxLines: maxLines,
    autovalidate: autovalidate,
    alignLabelWithHint: alignLabelWithHint,
    onChanged: onChanged,
  );
}
