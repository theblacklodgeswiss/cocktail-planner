import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import 'legal_content.dart';

export 'legal_content.dart' show LegalInfoType;

/// Screen displaying legal information (Impressum, AGB, Privacy) as a calm
/// reading column.
class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key, required this.type});

  final LegalInfoType type;

  String get _title => switch (type) {
    LegalInfoType.imprint => 'legal.imprint_title'.tr(),
    LegalInfoType.terms => 'legal.terms_title'.tr(),
    LegalInfoType.privacy => 'legal.privacy_title'.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return LargeTitleScaffold(
      title: _title,
      leading: GlassIconButton(
        icon: Icons.arrow_back,
        semanticLabel: 'ui.back'.tr(),
        onPressed: () => context.pop(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'legal.updated'.tr(),
                  style: AppText.caption.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: AppSpace.s24),
                for (final s in legalSections(type)) _Section(section: s),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              section.title,
              style: AppText.section.copyWith(color: p.text),
            ),
          ),
          for (final b in section.blocks) ...[
            const SizedBox(height: AppSpace.s12),
            switch (b) {
              LegalText() => SelectableText(
                b.text,
                style: AppText.body.copyWith(color: p.text),
              ),
              LegalContact() => _Contact(contact: b),
              LegalPairs() => _Pairs(pairs: b),
            },
          ],
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.contact});

  final LegalContact contact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contact.name,
          style: AppText.body.copyWith(
            color: p.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          contact.subtitle,
          style: AppText.body.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpace.s8),
        for (final line in [contact.address, contact.phone, contact.email])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s4),
            child: SelectableText(
              line,
              style: AppText.body.copyWith(color: p.text),
            ),
          ),
      ],
    );
  }
}

class _Pairs extends StatelessWidget {
  const _Pairs({required this.pairs});

  final LegalPairs pairs;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        for (var i = 0; i < pairs.rows.length; i++) ...[
          if (i > 0)
            Divider(
              height: AppSize.hairline,
              thickness: AppSize.hairline,
              color: p.border,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    pairs.rows[i].$1,
                    style: AppText.body.copyWith(
                      color: p.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  flex: 3,
                  child: Text(
                    pairs.rows[i].$2,
                    textAlign: TextAlign.end,
                    style: AppText.body.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
