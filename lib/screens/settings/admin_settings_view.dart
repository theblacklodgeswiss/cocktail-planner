import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/glass_cta_bar.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';

/// Progress or result line of a long-running admin action.
class AdminStatus {
  const AdminStatus(this.text, this.isError);

  final String text;
  final bool isError;
}

/// Pure admin settings layout; data and actions are injected so it carries no
/// Firestore/JS dependencies.
class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({
    super.key,
    required this.threshold,
    required this.claudeConfigured,
    required this.microsoftLoggedIn,
    required this.isImporting,
    required this.onImport,
    required this.isEnriching,
    required this.enrichStatus,
    required this.onEnrich,
    required this.isGenerating,
    required this.generateStatus,
    required this.onGenerate,
    required this.onSave,
    this.isSaving = false,
  });

  final int threshold;
  final bool claudeConfigured;
  final bool microsoftLoggedIn;
  final bool isImporting;
  final VoidCallback onImport;
  final bool isEnriching;
  final AdminStatus? enrichStatus;
  final VoidCallback onEnrich;
  final bool isGenerating;
  final AdminStatus? generateStatus;
  final ValueChanged<String> onGenerate;
  final Future<void> Function(int threshold) onSave;
  final bool isSaving;

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  late final _distance = TextEditingController(
    text: widget.threshold.toString(),
  );
  final _recipeInput = TextEditingController();

  @override
  void dispose() {
    _distance.dispose();
    _recipeInput.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_distance.text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.invalid_distance'.tr())),
      );
      return;
    }
    await widget.onSave(value);
  }

  void _generate() {
    if (widget.isGenerating) return;
    widget.onGenerate(_recipeInput.text);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return LargeTitleScaffold(
      title: 'settings.admin_section'.tr(),
      leading: GlassIconButton(
        icon: Icons.arrow_back,
        semanticLabel: 'ui.back'.tr(),
        onPressed: () => context.pop(),
      ),
      bottomBar: GlassCtaBar(
        label: 'common.save'.tr(),
        loading: widget.isSaving,
        onPressed: widget.isSaving ? null : _save,
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          sliver: SliverList.list(
            children: [
              _AdminCard(
                icon: Icons.tune,
                title: 'settings.distance_section'.tr(),
                description: 'settings.distance_description'.tr(),
                children: [
                  TextField(
                    key: const Key('threshold-field'),
                    controller: _distance,
                    decoration: InputDecoration(
                      labelText: 'settings.long_distance_threshold'.tr(),
                      suffixText: 'km',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
              _AdminCard(
                icon: Icons.auto_awesome,
                title: 'settings.claude_section'.tr(),
                badge: widget.claudeConfigured
                    ? 'settings.claude_active'.tr()
                    : null,
                description: 'settings.claude_description'.tr(),
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.verified,
                          size: AppSize.glassButtonIcon,
                          color: p.goldText,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          'settings.claude_from_env'.tr(),
                          style: AppText.body.copyWith(color: p.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s16),
                  Text(
                    'admin_settings.import_title'.tr(),
                    style: AppText.section.copyWith(color: p.text),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    'admin_settings.import_desc'.tr(),
                    style: AppText.caption.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  if (!widget.microsoftLoggedIn)
                    Text(
                      'admin_settings.import_login_hint'.tr(),
                      style: AppText.caption.copyWith(color: p.textSecondary),
                    )
                  else
                    SecondaryButton(
                      label: widget.isImporting
                          ? 'admin_settings.import_running'.tr()
                          : 'admin_settings.import_button'.tr(),
                      loading: widget.isImporting,
                      onPressed: widget.isImporting ? null : widget.onImport,
                    ),
                ],
              ),
              _AdminCard(
                icon: Icons.menu_book,
                title: 'admin_settings.enrich_title'.tr(),
                description: 'admin_settings.enrich_desc'.tr(),
                children: [
                  if (widget.enrichStatus != null) ...[
                    _StatusLine(status: widget.enrichStatus!),
                    const SizedBox(height: AppSpace.s12),
                  ],
                  PrimaryButton(
                    label: widget.isEnriching
                        ? 'admin_settings.enrich_running'.tr()
                        : 'admin_settings.enrich_button'.tr(),
                    loading: widget.isEnriching,
                    onPressed: widget.isEnriching ? null : widget.onEnrich,
                  ),
                ],
              ),
              _AdminCard(
                icon: Icons.add_circle_outline,
                title: 'admin_settings.generate_title'.tr(),
                description: 'admin_settings.generate_desc'.tr(),
                children: [
                  TextField(
                    controller: _recipeInput,
                    decoration: InputDecoration(
                      hintText: 'admin_settings.generate_hint'.tr(),
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  PrimaryButton(
                    label: 'admin_settings.generate_button'.tr(),
                    loading: widget.isGenerating,
                    onPressed: widget.isGenerating ? null : _generate,
                  ),
                  if (widget.generateStatus != null) ...[
                    const SizedBox(height: AppSpace.s12),
                    _StatusLine(status: widget.generateStatus!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? badge;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: FloatingCard(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: AppSize.glassButtonIcon,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppText.section.copyWith(color: p.text),
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: AppSpace.s8),
                  Text(
                    badge!,
                    style: AppText.pill.copyWith(color: p.goldText),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              description,
              style: AppText.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: AppSpace.s16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final AdminStatus status;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        status.text,
        style: AppText.body.copyWith(
          color: status.isError ? p.error : p.goldText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
