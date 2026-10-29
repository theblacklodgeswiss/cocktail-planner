import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/app_sheet.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/pressable.dart';
import '../../ui/widgets/states.dart';
import 'admin_widgets.dart';
import 'material_logic.dart';

/// Width of the amount field next to a selected ingredient.
const double _amountWidth = 112;

typedef RecipeEditResult = ({
  String name,
  List<String> ingredients,
  Map<String, String> amounts,
});

/// Full-screen sheet to create or edit a recipe in two steps: the name, then
/// the ingredients with their amounts. Returns the saved result or null.
///
/// [loadMaterials] lists the selectable ingredient names, [onAddIngredient]
/// creates a new one, [onSave] performs the write (true = success).
Future<RecipeEditResult?> showRecipeEditSheet(
  BuildContext context, {
  String initialName = '',
  List<String> initialIngredients = const [],
  Map<String, String> initialAmounts = const {},
  required Future<List<String>> Function() loadMaterials,
  required Future<bool> Function(String name) onAddIngredient,
  required Future<bool> Function(RecipeEditResult result) onSave,
}) async {
  RecipeEditResult? saved;
  final ok = await showAppSheet<bool>(
    context,
    full: true,
    builder: (_) => RecipeEditForm(
      initialName: initialName,
      initialIngredients: initialIngredients,
      initialAmounts: initialAmounts,
      loadMaterials: loadMaterials,
      onAddIngredient: onAddIngredient,
      onSave: (r) async {
        final success = await onSave(r);
        if (success) saved = r;
        return success;
      },
    ),
  );
  return ok == true ? saved : null;
}

class RecipeEditForm extends StatefulWidget {
  const RecipeEditForm({
    super.key,
    required this.initialName,
    required this.initialIngredients,
    required this.initialAmounts,
    required this.loadMaterials,
    required this.onAddIngredient,
    required this.onSave,
  });

  final String initialName;
  final List<String> initialIngredients;
  final Map<String, String> initialAmounts;
  final Future<List<String>> Function() loadMaterials;
  final Future<bool> Function(String name) onAddIngredient;
  final Future<bool> Function(RecipeEditResult result) onSave;

  @override
  State<RecipeEditForm> createState() => _RecipeEditFormState();
}

class _RecipeEditFormState extends State<RecipeEditForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late final Set<String> _selected = Set.of(widget.initialIngredients);
  late final Map<String, TextEditingController> _amounts = {
    for (final ing in widget.initialIngredients)
      ing: TextEditingController(text: widget.initialAmounts[ing] ?? ''),
  };
  List<String> _available = [];
  bool _loading = true;
  bool _loadFailed = false;
  String _query = '';
  int _step = 0;
  bool _nameMissing = false;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final names = await widget.loadMaterials();
      if (!mounted) return;
      setState(() {
        _available = List.of(names)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  void _toggle(String name, bool on) {
    setState(() {
      if (on) {
        _selected.add(name);
        _amounts.putIfAbsent(name, () => TextEditingController());
      } else {
        _selected.remove(name);
      }
    });
  }

  Map<String, String> get _currentAmounts => {
    for (final ing in _selected)
      if ((_amounts[ing]?.text.trim() ?? '').isNotEmpty)
        ing: _amounts[ing]!.text.trim(),
  };

  void _next() {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    setState(() {
      _nameMissing = false;
      _step = 1;
    });
  }

  Future<void> _addIngredient() async {
    String? name;
    await showAppSheet<bool>(
      context,
      scrollable: false,
      builder: (_) => _NewIngredientForm(
        onAdd: (n) async {
          final ok = await widget.onAddIngredient(n);
          if (ok) name = n;
          return ok;
        },
      ),
    );
    final added = name;
    if (added == null || !mounted) return;
    setState(() {
      _available
        ..add(added)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _selected.add(added);
      _amounts[added] = TextEditingController();
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final result = (
      name: _name.text,
      ingredients: _selected.toList(),
      amounts: _currentAmounts,
    );
    final ok = await widget.onSave(result);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isNew = widget.initialName.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            isNew ? 'admin2.new_recipe'.tr() : 'admin2.edit_recipe'.tr(),
            style: AppText.heroTitle.copyWith(color: p.text),
          ),
        ),
        Text(
          'ui.step_of'.tr(args: ['${_step + 1}', '2']),
          style: AppText.caption.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpace.s12),
        Expanded(child: _step == 0 ? _nameStep() : _ingredientsStep(p)),
        if (_saveFailed) ...[
          const SizedBox(height: AppSpace.s8),
          Semantics(
            liveRegion: true,
            child: Text(
              'admin2.save_error'.tr(),
              style: AppText.body.copyWith(color: p.error),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s12),
        if (_step == 0)
          PrimaryButton(label: 'common.next'.tr(), onPressed: _next)
        else
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'common.back'.tr(),
                  onPressed: _saving ? null : () => setState(() => _step = 0),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: PrimaryButton(
                  label: 'common.save'.tr(),
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _nameStep() {
    final p = AppPalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('recipe-name'),
            controller: _name,
            autofocus: true,
            onChanged: (_) {
              if (_nameMissing) setState(() => _nameMissing = false);
            },
            decoration: InputDecoration(
              labelText: 'admin2.f_name'.tr(),
              hintText: 'admin2.recipe_name_hint'.tr(),
            ),
          ),
          if (_nameMissing) ...[
            const SizedBox(height: AppSpace.s8),
            Semantics(
              liveRegion: true,
              child: Text(
                'admin2.recipe_name_required'.tr(),
                style: AppText.body.copyWith(color: p.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ingredientsStep(AppPalette p) {
    final list = filterIngredients(_available, _selected, _query);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CountLine(
                text: 'admin2.selected_count'.tr(args: ['${_selected.length}']),
                trailing: TextAction(
                  label: 'admin2.new_ingredient'.tr(),
                  onPressed: _addIngredient,
                ),
              ),
              SearchPill(
                hint: 'admin2.ingredient_search'.tr(),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpace.s8),
            ],
          ),
        ),
        if (_loading)
          const SliverFillRemaining(hasScrollBody: false, child: LoadingState())
        else if (_loadFailed)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: 'admin2.load_error'.tr(),
              onRetry: _load,
            ),
          )
        else if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off,
              title: 'admin2.no_ingredients'.tr(),
            ),
          )
        else
          SliverList.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final name = list[i];
              final on = _selected.contains(name);
              return _IngredientRow(
                key: ValueKey(name),
                name: name,
                selected: on,
                controller: on ? _amounts[name] : null,
                onToggle: (v) => _toggle(name, v),
              );
            },
          ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    super.key,
    required this.name,
    required this.selected,
    required this.onToggle,
    this.controller,
  });

  final String name;
  final bool selected;
  final TextEditingController? controller;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: () => onToggle(!selected),
            minSize: AppSize.minTap,
            selected: selected,
            semanticLabel: name,
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: AppSize.checkMark,
                  color: selected ? p.primary : p.textSecondary,
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    name,
                    style: AppText.body.copyWith(color: p.text),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected && controller != null)
          SizedBox(
            width: _amountWidth,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'admin2.amount_hint'.tr(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s8,
                  vertical: AppSpace.s12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NewIngredientForm extends StatefulWidget {
  const _NewIngredientForm({required this.onAdd});

  final Future<bool> Function(String name) onAdd;

  @override
  State<_NewIngredientForm> createState() => _NewIngredientFormState();
}

class _NewIngredientFormState extends State<_NewIngredientForm> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormSheet(
      title: 'admin2.new_ingredient_title'.tr(),
      saveLabel: 'common.add'.tr(),
      errorText: 'common.add_error'.tr(),
      validate: () => _name.text.trim().isNotEmpty,
      onSubmit: () => widget.onAdd(_name.text.trim()),
      fields: [
        TextField(
          key: const Key('ingredient-name'),
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'admin2.ingredient_name'.tr(),
            hintText: 'admin2.ingredient_name_hint'.tr(),
          ),
        ),
      ],
    );
  }
}
