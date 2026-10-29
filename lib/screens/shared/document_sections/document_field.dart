import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/pressable.dart';
import '../../forms/steps/wizard_widgets.dart' show FieldHint, FieldLabel;

/// Where a section finds the hint of a field and its scroll anchor (the
/// flow's [DocumentStepFlow.hintOf] / [DocumentStepFlow.anchorOf]).
class DocHints {
  const DocHints({required this.hintOf, required this.anchorOf});

  /// No hints (e.g. tests of a single section).
  DocHints.none() : hintOf = _noHint, anchorOf = _newKey;

  final String? Function(String field) hintOf;
  final GlobalKey Function(String field) anchorOf;

  static String? _noHint(String _) => null;
  static GlobalKey _newKey(String _) => GlobalKey();
}

/// A captioned text field of the offer/invoice flows (the former `_field`
/// helper): label above, red frame and hint below when [field] has an
/// issue, keyboard "next" moves to the following field.
class DocTextField extends StatelessWidget {
  const DocTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hints,
    this.field,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.minLines,
    this.suffixText,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final DocHints? hints;

  /// Field id for hints and anchors; null for optional fields.
  final String? field;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final int? maxLines;
  final int? minLines;
  final String? suffixText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final errorKey = field == null ? null : hints?.hintOf(field!);
    final multiline = maxLines == null || maxLines! > 1;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: multiline ? TextInputType.multiline : keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: multiline ? TextInputAction.newline : textInputAction,
          onSubmitted: multiline || textInputAction != TextInputAction.next
              ? null
              : (_) => FocusScope.of(context).nextFocus(),
          minLines: minLines,
          maxLines: maxLines,
          style: AppText.button.copyWith(
            color: p.text,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            suffixText: suffixText,
            suffixIcon: suffixIcon,
            hintStyle: AppText.button.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w400,
            ),
            enabledBorder: errorKey == null
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    borderSide: BorderSide(color: p.error),
                  ),
          ),
        ),
        FieldHint(errorKey),
      ],
    );
    if (field == null || hints == null) return body;
    return KeyedSubtree(key: hints!.anchorOf(field!), child: body);
  }
}

/// A 44 px round icon action (edit/delete on position cards).
class DocIconAction extends StatelessWidget {
  const DocIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: label,
      onTap: onTap,
      child: SizedBox.square(
        dimension: AppSize.minTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
          child: Icon(
            icon,
            size: AppSize.rowIcon,
            color: destructive ? p.error : p.text,
          ),
        ),
      ),
    );
  }
}

/// Label/value line of a price breakdown; both sides wrap instead of
/// overflowing at large text.
class DocAmountRow extends StatelessWidget {
  const DocAmountRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = (bold ? AppText.section : AppText.body).copyWith(
      color: p.text,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: AppSpace.s12),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

/// Thin rule between breakdown blocks.
class DocDivider extends StatelessWidget {
  const DocDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
    child: Divider(
      height: AppSize.hairline,
      thickness: AppSize.hairline,
      color: AppPalette.of(context).border,
    ),
  );
}

/// "tbd" for positions without quantity.
String tbdOr(bool tbd, String value) => tbd ? 'tbd' : value;

/// Translated "required" marker appended to a label.
String requiredLabel(String key) => '${key.tr()} *';
