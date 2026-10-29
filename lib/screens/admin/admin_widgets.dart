import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/floating_card.dart';
import '../../ui/widgets/floating_fab.dart';
import '../../ui/widgets/glass_icon_button.dart';
import '../../ui/widgets/large_title_scaffold.dart';
import '../../ui/widgets/pressable.dart';
import '../../ui/widgets/states.dart';

/// Common frame of every admin list page: large title, back button, an
/// optional header (tabs, search), the loading/error states and a floating
/// "+" button.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.slivers,
    this.header,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.onAdd,
    this.addLabel,
    this.onRefresh,
  });

  final String title;

  /// Content slivers; replaced by the loading or error state.
  final List<Widget> slivers;

  /// Box content right under the title (kept in every state).
  final Widget? header;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onAdd;
  final String? addLabel;

  /// Enables pull-to-refresh on the list.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scaffold = LargeTitleScaffold(
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      title: title,
      leading: GlassIconButton(
        icon: Icons.arrow_back,
        semanticLabel: 'ui.back'.tr(),
        onPressed: () => context.pop(),
      ),
      fab: onAdd == null
          ? null
          : FloatingFab(onPressed: onAdd!, semanticLabel: addLabel),
      slivers: [
        if (header != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                0,
                AppSpace.s16,
                AppSpace.s12,
              ),
              child: header,
            ),
          ),
        if (loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingState(),
          )
        else if (errorMessage != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: errorMessage!,
              onRetry: onRetry ?? () {},
            ),
          )
        else
          ...slivers,
      ],
    );
    if (onRefresh == null) return scaffold;
    return RefreshIndicator(onRefresh: onRefresh!, child: scaffold);
  }
}

/// Search field as a pill.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.onChanged, this.hint});

  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    OutlineInputBorder border([Color? color]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: AppSize.focusRing),
    );
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint ?? 'admin2.search_hint'.tr(),
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: p.card,
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(p.primary),
      ),
    );
  }
}

/// Plain count / helper line above a list.
class CountLine extends StatelessWidget {
  const CountLine({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: AppText.caption.copyWith(color: p.textSecondary)),
        ?trailing,
      ],
    );
  }
}

/// 44 px icon button used in list rows.
class RowIconButton extends StatelessWidget {
  const RowIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Pressable(
      onTap: onPressed,
      minSize: AppSize.minTap,
      radius: AppRadius.pill,
      semanticLabel: label,
      child: Icon(
        icon,
        size: AppSize.rowIcon,
        color: destructive ? p.error : p.textSecondary,
      ),
    );
  }
}

/// Drag handle of a reorderable row.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      label: 'admin2.drag_to_reorder'.tr(),
      child: ReorderableDragStartListener(
        index: index,
        child: SizedBox.square(
          dimension: AppSize.minTap,
          child: Icon(
            Icons.drag_handle,
            size: AppSize.rowIcon,
            color: p.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Small label (category, role) on a quiet pill.
class MiniPill extends StatelessWidget {
  const MiniPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s4,
        ),
        child: Text(
          text,
          style: AppText.pill.copyWith(color: p.textSecondary),
        ),
      ),
    );
  }
}

/// Row card of a list: optional leading, title/subtitle, trailing widgets.
/// Tapping the card edits.
class AdminRowCard extends StatelessWidget {
  const AdminRowCard({
    super.key,
    required this.title,
    this.subtitle,
    this.extra = const [],
    this.leading,
    this.trailing = const [],
    this.onTap,
    this.dimmed = false,
  });

  final String title;
  final String? subtitle;

  /// Further lines under the subtitle.
  final List<Widget> extra;
  final Widget? leading;
  final List<Widget> trailing;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget card = FloatingCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s4,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.minTap),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpace.s4),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.section.copyWith(color: p.text),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppText.body.copyWith(color: p.textSecondary),
                      ),
                    ...extra,
                  ],
                ),
              ),
            ),
            ...trailing,
          ],
        ),
      ),
    );
    if (dimmed) card = Opacity(opacity: AppSize.pressedOpacity, child: card);
    return card;
  }
}

/// List of padded rows, reorderable when [onReorder] is set. [itemBuilder]
/// gets a drag handle (null when not reorderable).
class AdminSliverList extends StatelessWidget {
  const AdminSliverList({
    super.key,
    required this.count,
    required this.idAt,
    required this.itemBuilder,
    this.onReorder,
  });

  final int count;
  final String Function(int index) idAt;
  final Widget Function(BuildContext context, int index, Widget? handle)
  itemBuilder;
  final ReorderCallback? onReorder;

  Widget _item(BuildContext context, int index) => KeyedSubtree(
    key: ValueKey(idAt(index)),
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: itemBuilder(
        context,
        index,
        onReorder == null ? null : DragHandle(index: index),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
      sliver: onReorder == null
          ? SliverList.builder(itemCount: count, itemBuilder: _item)
          : SliverReorderableList(
              itemCount: count,
              itemBuilder: _item,
              onReorder: onReorder!,
              proxyDecorator: (child, index, animation) =>
                  Material(type: MaterialType.transparency, child: child),
            ),
    );
  }
}

/// Content of a form sheet: title, scrolling fields, an inline error and a
/// primary button that stays visible above the keyboard. Put it into
/// `showAppSheet(scrollable: false)`.
///
/// [validate] runs first (return false to stop without a spinner); then
/// [onSubmit] performs the write and returns whether it worked. On success
/// the sheet pops with `true`; on failure it stays open with [errorText].
class AdminFormSheet extends StatefulWidget {
  const AdminFormSheet({
    super.key,
    required this.title,
    required this.fields,
    required this.saveLabel,
    required this.onSubmit,
    required this.errorText,
    this.validate,
  });

  final String title;
  final List<Widget> fields;
  final String saveLabel;
  final String errorText;
  final bool Function()? validate;
  final Future<bool> Function() onSubmit;

  /// Space between two fields.
  static const gap = SizedBox(height: AppSpace.s12);

  @override
  State<AdminFormSheet> createState() => _AdminFormSheetState();
}

class _AdminFormSheetState extends State<AdminFormSheet> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _submit() async {
    if (_saving) return;
    if (widget.validate != null && !widget.validate!()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final ok = await widget.onSubmit();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            widget.title,
            style: AppText.heroTitle.copyWith(color: p.text),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.fields,
            ),
          ),
        ),
        if (_failed) ...[
          const SizedBox(height: AppSpace.s8),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.errorText,
              style: AppText.body.copyWith(color: p.error),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        PrimaryButton(
          label: widget.saveLabel,
          loading: _saving,
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }
}

/// Shows a snackbar with a translated [key].
void showAdminSnack(BuildContext context, String key) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(key.tr())));
}
