/// The order wizard fields that can be missing, with the step they live on
/// and the translation key of the hint shown at the field.
enum FormFieldId {
  eventType(0, 'offer.event_type_required'),
  eventDate(1, 'order_setup.required_date'),
  eventTime(1, 'order_wizard.required_time'),
  address(1, 'order_wizard.required_address'),
  name(2, 'order_setup.required_name'),
  phone(2, 'order_wizard.required_phone'),

  /// Not a "Weiter" gate (step 3 always proceeds), only checked on submit.
  cocktails(3, 'order_setup.required_cocktails');

  const FormFieldId(this.step, this.messageKey);

  /// The (new, 0..4) step that shows this field.
  final int step;

  /// Translation key of the hint at the field.
  final String messageKey;
}

/// The fields that must be filled before "Weiter" on [step], in the order
/// they appear on screen (the first missing one gets focus).
List<FormFieldId> requiredFieldsOf(int step) => switch (step) {
  0 => const [FormFieldId.eventType],
  1 => const [
    FormFieldId.eventDate,
    FormFieldId.eventTime,
    FormFieldId.address,
  ],
  2 => const [FormFieldId.name, FormFieldId.phone],
  _ => const [],
};
