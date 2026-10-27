import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/order.dart';
import '../../services/auth_service.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/glass_cta_bar.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/hero_card.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import 'user_menu_sheet.dart';
import 'widgets/my_requests_list.dart';

const _brand = 'BlackLodge';

/// Start page for guests and customers. [orders] is the stream of the
/// signed-in user's own requests; guests pass null and see a sign-in hint.
class CustomerStart extends StatelessWidget {
  const CustomerStart({
    super.key,
    required this.signedIn,
    required this.onOpenRequest,
    this.orders,
  });

  final bool signedIn;
  final void Function(SavedOrder request) onOpenRequest;
  final Stream<List<SavedOrder>>? orders;

  Future<void> _linkGoogle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await authService.linkWithGoogle();
      messenger.showSnackBar(
        SnackBar(content: Text('drawer.link_success'.tr())),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${'common.error'.tr()}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final steps = [
      ('start.step_request', 'start.step_request_desc'),
      ('start.step_offer', 'start.step_offer_desc'),
      ('start.step_party', 'start.step_party_desc'),
    ];

    return LargeTitleScaffold(
      title: _brand,
      actions: [
        GlassIconButton(
          icon: Icons.settings_outlined,
          semanticLabel: 'settings.title'.tr(),
          onPressed: () => context.push('/settings'),
        ),
        GlassIconButton(
          icon: Icons.person_outline,
          semanticLabel: 'start.account'.tr(),
          onPressed: () => showUserMenu(context),
        ),
      ],
      bottomBar: GlassCtaBar(
        label: 'start.cta'.tr(),
        onPressed: () => context.push('/order-form'),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          sliver: SliverList.list(
            children: [
              HeroCard(
                kicker: 'start.kicker'.tr(),
                title: 'start.title'.tr(),
                titleStyle: AppText.display,
                meta: 'start.subtitle'.tr(),
              ),
              const SizedBox(height: AppSpace.s16),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: FloatingCard(
                    child: Row(
                      children: [
                        SizedBox(
                          width: AppSize.stepDigit,
                          child: Text(
                            '${i + 1}',
                            style: AppText.number.copyWith(color: p.goldText),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                steps[i].$1.tr(),
                                style: AppText.section.copyWith(color: p.text),
                              ),
                              Text(
                                steps[i].$2.tr(),
                                style: AppText.body.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.s16),
              if (signedIn)
                _MyRequestsSection(orders: orders, onOpen: onOpenRequest)
              else
                FloatingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'dashboard.sign_in_to_see_requests'.tr(),
                        style: AppText.body.copyWith(color: p.textSecondary),
                      ),
                      TextAction(
                        label: 'drawer.link_google_title'.tr(),
                        onPressed: () => _linkGoogle(context),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Meine Anfragen" block: the newest three plus a link to the full list.
/// Task 5 swaps [MyRequestsList] for the redesigned cards.
class _MyRequestsSection extends StatelessWidget {
  const _MyRequestsSection({required this.orders, required this.onOpen});

  final Stream<List<SavedOrder>>? orders;
  final void Function(SavedOrder request) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s8),
          child: Text(
            'dashboard.my_requests_title'.tr(),
            style: AppText.section.copyWith(color: p.text),
          ),
        ),
        StreamBuilder<List<SavedOrder>>(
          stream: orders,
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            return Column(
              children: [
                MyRequestsList(requests: all.take(3).toList(), onTap: onOpen),
                if (all.length > 3)
                  TextAction(
                    label: 'dashboard.show_all_requests'.tr(),
                    onPressed: () => context.push('/my-requests'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
