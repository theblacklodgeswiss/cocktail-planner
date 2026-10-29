import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/states.dart';

/// Shown instead of a page the current role may not open (the route guards
/// are unchanged; this is the in-screen fallback).
class AdminDeniedPage extends StatelessWidget {
  const AdminDeniedPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return LargeTitleScaffold(
      title: title,
      leading: GlassIconButton(
        icon: Icons.arrow_back,
        semanticLabel: 'ui.back'.tr(),
        onPressed: () => context.pop(),
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.lock_outline,
            title: 'admin.access_denied'.tr(),
          ),
        ),
      ],
    );
  }
}
