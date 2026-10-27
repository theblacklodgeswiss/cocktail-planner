import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/order_repository.dart';
import '../../services/auth_service.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import 'widgets/my_request_detail_sheet.dart';
import 'widgets/my_requests_list.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return LargeTitleScaffold(
      title: 'dashboard.my_requests_title'.tr(),
      actions: [
        GlassIconButton(
          icon: Icons.arrow_back,
          semanticLabel: 'ui.back'.tr(),
          onPressed: () => context.go('/'),
        ),
      ],
      slivers: [
        if (!authService.isSignedIn)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'dashboard.sign_in_to_see_requests'.tr(),
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: p.textSecondary),
              ),
            ),
          )
        else
          MyRequestsContent(
            streamFactory: () => orderRepository.watchOrdersForOwner(
              authService.currentUser!.uid,
            ),
            onOpen: (request) => showMyRequestDetails(context, request),
          ),
      ],
    );
  }
}
