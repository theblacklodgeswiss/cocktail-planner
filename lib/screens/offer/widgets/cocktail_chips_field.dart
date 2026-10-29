import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../data/cocktail_repository.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/pressable.dart';
import '../../forms/steps/wizard_widgets.dart';

/// Edits a comma-separated cocktail list (kept in [controller], so callers
/// that read `controller.text` keep working) as removable pills plus an
/// "add" pill that searches the recipe catalog in a sheet.
class CocktailChipsField extends StatefulWidget {
  const CocktailChipsField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.loadCatalog,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  /// Recipe names for the "add" search; defaults to the cocktail repository.
  final Future<List<String>> Function()? loadCatalog;

  @override
  State<CocktailChipsField> createState() => _CocktailChipsFieldState();
}

class _CocktailChipsFieldState extends State<CocktailChipsField> {
  List<String> _catalog = [];

  List<String> get _selected => widget.controller.text
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _loadCatalog();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCatalog() async {
    try {
      final loaded = widget.loadCatalog != null
          ? await widget.loadCatalog!()
          : (await cocktailRepository.load()).recipes.map((r) => r.name);
      final names = loaded.toSet().toList()..sort();
      if (mounted) setState(() => _catalog = names);
    } catch (_) {
      // Catalog unavailable (offline): custom names can still be typed.
    }
  }

  void _set(List<String> items) => widget.controller.text = items.join(', ');

  Future<void> _add() async {
    final picked = await showAppSheet<String>(
      context,
      full: true,
      scrollable: false,
      builder: (_) => _CocktailPicker(
        catalog: _catalog,
        alreadySelected: _selected.map((s) => s.toLowerCase()).toSet(),
      ),
    );
    if (picked == null || picked.trim().isEmpty) return;
    final items = _selected;
    if (items.any((s) => s.toLowerCase() == picked.trim().toLowerCase())) return;
    _set([...items, picked.trim()]);
  }

  @override
  Widget build(BuildContext context) {
    final items = _selected;
    final error = widget.validator?.call(widget.controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(widget.label),
        PillGroup(
          children: [
            for (final name in items)
              SelectPill(
                label: name,
                selected: true,
                onTap: () => _set(items.where((s) => s != name).toList()),
              ),
            SelectPill(
              label: 'offer.add_cocktail'.tr(),
              selected: false,
              icon: Icons.add,
              onTap: _add,
            ),
          ],
        ),
        if (error != null) FieldHint(error),
      ],
    );
  }
}

class _CocktailPicker extends StatefulWidget {
  const _CocktailPicker({required this.catalog, required this.alreadySelected});

  final List<String> catalog;
  final Set<String> alreadySelected;

  @override
  State<_CocktailPicker> createState() => _CocktailPickerState();
}

class _CocktailPickerState extends State<_CocktailPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final q = _query.trim().toLowerCase();
    final matches = widget.catalog
        .where((n) => !widget.alreadySelected.contains(n.toLowerCase()))
        .where((n) => q.isEmpty || n.toLowerCase().contains(q))
        .toList();
    final exact =
        widget.catalog.any((n) => n.toLowerCase() == q) ||
        widget.alreadySelected.contains(q);

    Widget row(IconData? icon, String text, String result) => Pressable(
      minSize: AppSize.minTap,
      onTap: () => Navigator.of(context).pop(result),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.minTap),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSize.rowIcon, color: p.text),
              const SizedBox(width: AppSpace.s12),
            ],
            Expanded(
              child: Text(text, style: AppText.button.copyWith(color: p.text)),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          style: AppText.button.copyWith(color: p.text),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'offer.search_cocktail'.tr(),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpace.s8),
        Expanded(
          child: ListView(
            children: [
              if (q.isNotEmpty && !exact)
                row(
                  Icons.edit_outlined,
                  'offer.add_custom_cocktail'.tr(
                    namedArgs: {'name': _query.trim()},
                  ),
                  _query.trim(),
                ),
              for (final name in matches) row(null, name, name),
            ],
          ),
        ),
      ],
    );
  }
}
