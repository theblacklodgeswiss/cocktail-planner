import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/offer.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/buttons.dart';
import '../../../utils/signed_number_input.dart';
import 'document_field.dart';

/// Add/edit sheet of a position (was a dialog). [prefix] is 'offer' or
/// 'invoice'. [extra] is the invoice's fields-mode "extra position": no
/// date, whole quantity >= 1 required, plain decimal price. Returns the
/// position, or null when dismissed.
Future<ExtraPosition?> showPositionSheet(
  BuildContext context, {
  required String prefix,
  required String currencyCode,
  String defaultDate = '',
  ExtraPosition? existing,
  bool extra = false,
}) {
  return showAppSheet<ExtraPosition>(
    context,
    builder: (_) => _PositionForm(
      prefix: prefix,
      currencyCode: currencyCode,
      defaultDate: defaultDate,
      existing: existing,
      extra: extra,
    ),
  );
}

/// Price validation of a position (required, signed decimal).
String? positionPriceErrorKey(String? v, String prefix) {
  if (v == null || v.trim().isEmpty) return '$prefix.field_required';
  if (parseDecimal(v) == null) return '$prefix.invalid_number';
  return null;
}

/// The position the sheet returns: empty quantity counts as 1.
ExtraPosition positionFromInput({
  required String date,
  required String name,
  required String quantity,
  required String price,
  required String remark,
}) => ExtraPosition(
  date: date.trim(),
  name: name.trim(),
  quantity: int.tryParse(quantity.trim()) ?? 1,
  price: parseDecimal(price) ?? 0,
  remark: remark.trim(),
);

/// Extra position quantity: required, whole number >= 1.
String? extraQuantityErrorKey(String? v) {
  if (v == null || v.trim().isEmpty) return 'invoice.field_required';
  final n = int.tryParse(v.trim());
  if (n == null || n < 1) return 'invoice.invalid_number';
  return null;
}

/// Extra position price: required, plain decimal.
String? extraPriceErrorKey(String? v) {
  if (v == null || v.trim().isEmpty) return 'invoice.field_required';
  if (double.tryParse(v.trim()) == null) return 'invoice.invalid_number';
  return null;
}

class _PositionForm extends StatefulWidget {
  const _PositionForm({
    required this.prefix,
    required this.currencyCode,
    required this.defaultDate,
    required this.existing,
    required this.extra,
  });

  final String prefix;
  final String currencyCode;
  final String defaultDate;
  final ExtraPosition? existing;
  final bool extra;

  @override
  State<_PositionForm> createState() => _PositionFormState();
}

class _PositionFormState extends State<_PositionForm> {
  late final _date = TextEditingController(
    text: widget.existing?.date.isNotEmpty == true
        ? widget.existing!.date
        : widget.defaultDate,
  );
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _quantity = TextEditingController(
    text: widget.existing != null ? widget.existing!.quantity.toString() : '1',
  );
  late final _price = TextEditingController(
    text: widget.existing != null
        ? widget.existing!.price.toStringAsFixed(2)
        : '',
  );
  late final _remark = TextEditingController(
    text: widget.existing?.remark ?? '',
  );
  bool _attempted = false;

  @override
  void dispose() {
    for (final c in [_date, _name, _quantity, _price, _remark]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _errors {
    final p = widget.prefix;
    return {
      if (_name.text.trim().isEmpty) 'name': '$p.field_required',
      if (widget.extra && extraQuantityErrorKey(_quantity.text) != null)
        'quantity': extraQuantityErrorKey(_quantity.text)!,
      if ((widget.extra
              ? extraPriceErrorKey(_price.text)
              : positionPriceErrorKey(_price.text, p)) !=
          null)
        'price': (widget.extra
            ? extraPriceErrorKey(_price.text)
            : positionPriceErrorKey(_price.text, p))!,
    };
  }

  void _save() {
    if (_errors.isNotEmpty) {
      setState(() => _attempted = true);
      return;
    }
    Navigator.of(context).pop(
      widget.extra
          ? ExtraPosition(
              name: _name.text.trim(),
              quantity: int.parse(_quantity.text.trim()),
              price: double.parse(_price.text.trim()),
              remark: _remark.text.trim(),
            )
          : positionFromInput(
              date: _date.text,
              name: _name.text,
              quantity: _quantity.text,
              price: _price.text,
              remark: _remark.text,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final prefix = widget.prefix;
    final errors = _errors;
    final hints = DocHints(
      hintOf: (f) => _attempted ? errors[f] : null,
      anchorOf: (_) => GlobalKey(),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.existing == null
              ? '$prefix.add_position'.tr()
              : '$prefix.edit_position'.tr(),
          style: AppText.heroTitle.copyWith(color: p.text),
        ),
        const SizedBox(height: AppSpace.s16),
        if (!widget.extra) ...[
          DocTextField(
            controller: _date,
            label: 'Datum',
            hintText: 'dd.MM.yyyy',
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: AppSpace.s12),
        ],
        DocTextField(
          controller: _name,
          label: '$prefix.position_name'.tr(),
          hints: hints,
          field: 'name',
        ),
        const SizedBox(height: AppSpace.s12),
        DocTextField(
          controller: _quantity,
          label: '$prefix.position_quantity'.tr(),
          hints: hints,
          field: 'quantity',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: AppSpace.s12),
        DocTextField(
          controller: _price,
          label: '${'$prefix.position_price'.tr()} (${widget.currencyCode})',
          hints: hints,
          field: 'price',
          keyboardType: widget.extra
              ? TextInputType.number
              : const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
          suffixIcon: widget.extra ? null : SignToggleButton(controller: _price),
        ),
        const SizedBox(height: AppSpace.s12),
        DocTextField(
          controller: _remark,
          label: '$prefix.position_remark'.tr(),
          minLines: 2,
          maxLines: widget.extra ? 2 : 3,
        ),
        const SizedBox(height: AppSpace.s24),
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
