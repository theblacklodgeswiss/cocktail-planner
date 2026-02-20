import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Empty state widget when no ingredients are available.
class ShoppingEmptyState extends StatelessWidget {
  const ShoppingEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'shopping.no_ingredients'.tr(),
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
