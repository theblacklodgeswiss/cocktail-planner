import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/offer.dart';
import '../../../utils/signed_number_input.dart';

/// Add/edit dialog for an offer position (offer screen and the invoice's
/// positions mode; moved verbatim, [prefix] is 'offer' or 'invoice').
/// Returns the new position, or null when cancelled.
Future<ExtraPosition?> showDocumentPositionDialog(
  BuildContext context, {
  required String prefix,
  required String currencyCode,
  required String defaultDate,
  ExtraPosition? existing,
}) async {
  final dateCtrl = TextEditingController(
    text: existing?.date.isNotEmpty == true ? existing!.date : defaultDate,
  );
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final quantityCtrl = TextEditingController(
    text: existing != null ? existing.quantity.toString() : '1',
  );
  final priceCtrl = TextEditingController(
    text: existing != null ? existing.price.toStringAsFixed(2) : '',
  );
  final remarkCtrl = TextEditingController(text: existing?.remark ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<ExtraPosition>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        existing == null
            ? '$prefix.add_position'.tr()
            : '$prefix.edit_position'.tr(),
      ),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Datum',
                    hintText: 'dd.MM.yyyy',
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: '$prefix.position_name'.tr(),
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? '$prefix.field_required'.tr()
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: quantityCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: '$prefix.position_quantity'.tr(),
                          prefixIcon: const Icon(Icons.numbers, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              '${'$prefix.position_price'.tr()} ($currencyCode)',
                          prefixIcon: const Icon(Icons.attach_money, size: 18),
                          suffixIcon: SignToggleButton(controller: priceCtrl),
                        ),
                        validator: (v) => positionPriceErrorKey(v, prefix)?.tr(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: remarkCtrl,
                  decoration: InputDecoration(
                    labelText: '$prefix.position_remark'.tr(),
                    prefixIcon: const Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(
                ctx,
                positionFromInput(
                  date: dateCtrl.text,
                  name: nameCtrl.text,
                  quantity: quantityCtrl.text,
                  price: priceCtrl.text,
                  remark: remarkCtrl.text,
                ),
              );
            }
          },
          child: Text('common.save'.tr()),
        ),
      ],
    ),
  );
}

/// Price validation of the position dialog (required, signed decimal).
String? positionPriceErrorKey(String? v, String prefix) {
  if (v == null || v.trim().isEmpty) return '$prefix.field_required';
  if (parseDecimal(v) == null) return '$prefix.invalid_number';
  return null;
}

/// The position the dialog returns: empty quantity counts as 1.
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
