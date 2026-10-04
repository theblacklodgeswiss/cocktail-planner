import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../data/cocktail_repository.dart';

/// Edits a comma-separated cocktail list (kept in [controller], so callers
/// that read `controller.text` keep working) as removable chips plus an
/// "add" button that searches the recipe catalog.
class CocktailChipsField extends StatefulWidget {
  const CocktailChipsField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

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
      final data = await cocktailRepository.load();
      final names = data.recipes.map((r) => r.name).toSet().toList()..sort();
      if (mounted) setState(() => _catalog = names);
    } catch (_) {
      // Catalog unavailable (offline): custom names can still be typed.
    }
  }

  void _set(List<String> items) => widget.controller.text = items.join(', ');

  Future<void> _add() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
    return FormField<String>(
      initialValue: widget.controller.text,
      // Always validate the live controller text, not the stale field value.
      validator: (_) => widget.validator?.call(widget.controller.text),
      builder: (state) {
        final items = _selected;
        final scheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final name in items)
                  InputChip(
                    label: Text(name),
                    onDeleted: () {
                      _set(items.where((s) => s != name).toList());
                      state.validate();
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text('offer.add_cocktail'.tr()),
                  onPressed: () async {
                    await _add();
                    state.validate();
                  },
                ),
              ],
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.errorText!,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CocktailPicker extends StatefulWidget {
  const _CocktailPicker({
    required this.catalog,
    required this.alreadySelected,
  });

  final List<String> catalog;
  final Set<String> alreadySelected;

  @override
  State<_CocktailPicker> createState() => _CocktailPickerState();
}

class _CocktailPickerState extends State<_CocktailPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = widget.catalog
        .where((n) => !widget.alreadySelected.contains(n.toLowerCase()))
        .where((n) => q.isEmpty || n.toLowerCase().contains(q))
        .toList();
    final exact = widget.catalog.any((n) => n.toLowerCase() == q) ||
        widget.alreadySelected.contains(q);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'offer.search_cocktail'.tr(),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (q.isNotEmpty && !exact)
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(
                        'offer.add_custom_cocktail'.tr(
                          namedArgs: {'name': _query.trim()},
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(_query.trim()),
                    ),
                  for (final name in matches)
                    ListTile(
                      title: Text(name),
                      onTap: () => Navigator.of(context).pop(name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
