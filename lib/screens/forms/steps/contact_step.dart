import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../order_form_state.dart';
import 'wizard_widgets.dart';

/// Step 2 "Wie erreichen wir dich?": name, phone (both required) and
/// remarks. The keyboard's next key walks name -> phone -> remarks.
class ContactStep extends StatelessWidget {
  const ContactStep({super.key, required this.form});

  final OrderFormState form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardSection(
          caption: 'order_wizard.contact_caption'.tr(),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: form.fieldKeys[FormFieldId.name],
                  child: WizardTextField(
                    controller: form.nameController,
                    focusNode: form.nameFocus,
                    label: 'order_setup.order_name_label'.tr(),
                    hintText: 'order_setup.order_name_hint'.tr(),
                    errorKey: form.visibleHint(FormFieldId.name),
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    onSubmitted: (_) => form.phoneFocus.requestFocus(),
                  ),
                ),
                const SizedBox(height: AppSpace.s12),
                KeyedSubtree(
                  key: form.fieldKeys[FormFieldId.phone],
                  child: WizardTextField(
                    controller: form.phoneController,
                    focusNode: form.phoneFocus,
                    label: '${'order_setup.phone_label'.tr()} *',
                    hintText: 'order_setup.phone_hint'.tr(),
                    errorKey: form.visibleHint(FormFieldId.phone),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    onSubmitted: (_) => form.remarksFocus.requestFocus(),
                  ),
                ),
              ],
            ),
          ),
        ),
        WizardSection(
          caption: 'order_wizard.remarks_caption'.tr(),
          child: WizardTextField(
            controller: form.remarksController,
            focusNode: form.remarksFocus,
            label: 'order_setup.remarks_subtitle'.tr(),
            hintText: 'order_setup.remarks_hint'.tr(),
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: 5,
          ),
        ),
      ],
    );
  }
}
