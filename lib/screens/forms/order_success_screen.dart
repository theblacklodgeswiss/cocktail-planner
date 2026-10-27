import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';

/// Success screen shown after a customer submits their order request.
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, this.signedIn});

  /// Overrides the auth lookup (tests); null reads [authService].
  final bool? signedIn;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final signedIn = this.signedIn ?? authService.isSignedIn;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSize.maxBarWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.hero,
                        shape: BoxShape.circle,
                        boxShadow: AppShadow.hero,
                      ),
                      child: SizedBox.square(
                        dimension: AppSize.badge,
                        child: Icon(
                          Icons.check,
                          size: AppSize.badgeIcon,
                          color: p.onHero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s24),
                  Semantics(
                    header: true,
                    child: Text(
                      'order_form.thank_you_title'.tr(),
                      textAlign: TextAlign.center,
                      style: AppText.title.copyWith(color: p.text),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'order_form.thank_you_message'.tr(),
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: AppSpace.s24),
                  PrimaryButton(
                    label: signedIn
                        ? 'dashboard.my_requests_title'.tr()
                        : 'order_form.back_to_home'.tr(),
                    onPressed: () =>
                        context.go(signedIn ? '/my-requests' : '/'),
                  ),
                  if (signedIn)
                    TextAction(
                      label: 'order_form.back_to_home'.tr(),
                      onPressed: () => context.go('/'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
