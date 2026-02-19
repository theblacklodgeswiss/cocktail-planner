import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

String translate(BuildContext context, String key) {
  if (EasyLocalization.of(context) == null) {
    return key;
  }
  return key.tr();
}
