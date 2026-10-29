import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../ui/widgets/states.dart';

/// Empty state widget when no ingredients are available.
class ShoppingEmptyState extends StatelessWidget {
  const ShoppingEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'shopping.no_ingredients'.tr(),
      ),
    );
  }
}
