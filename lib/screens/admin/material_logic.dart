import '../../models/material_item.dart';
import '../../models/recipe.dart';

/// A material/fixed value with its Firestore document id.
typedef MaterialRecord = ({String id, MaterialItem item});

/// A recipe with its Firestore document id.
typedef RecipeRecord = ({String id, Recipe item});

/// Sorts for the admin list: fixed values by manual sort order (unsorted
/// ones last, by name), materials by name. Sorts a copy.
List<MaterialRecord> sortMaterials(
  List<MaterialRecord> items, {
  required bool isFixedValue,
}) {
  final list = List.of(items);
  if (isFixedValue) {
    return list..sort((a, b) {
      final aOrder = a.item.sortOrder;
      final bOrder = b.item.sortOrder;
      if (aOrder != null && bOrder != null) return aOrder.compareTo(bOrder);
      if (aOrder != null) return -1;
      if (bOrder != null) return 1;
      return a.item.name.compareTo(b.item.name);
    });
  }
  return list..sort((a, b) => a.item.name.compareTo(b.item.name));
}

/// Hides archived items unless [showHidden], then keeps items whose name or
/// note contains [query] (case-insensitive).
List<MaterialRecord> filterMaterials(
  List<MaterialRecord> items, {
  String query = '',
  bool showHidden = false,
}) {
  final list = showHidden ? items : items.where((i) => i.item.visible).toList();
  if (query.isEmpty) return list;
  final q = query.toLowerCase();
  return list
      .where(
        (i) =>
            i.item.name.toLowerCase().contains(q) ||
            i.item.note.toLowerCase().contains(q),
      )
      .toList();
}

/// Moves a visible item and keeps the not-shown ones at the end, so the
/// returned order can be persisted as-is. [newIndex] is the raw
/// ReorderableList index (before the removal shift).
List<MaterialRecord> reorderMaterials(
  List<MaterialRecord> all,
  List<MaterialRecord> visible,
  int oldIndex,
  int newIndex,
) {
  if (newIndex > oldIndex) newIndex--;
  final moved = List.of(visible)
    ..removeAt(oldIndex)
    ..insert(newIndex, visible[oldIndex]);
  final shown = moved.map((e) => e.id).toSet();
  return [...moved, ...all.where((i) => !shown.contains(i.id))];
}

/// Recipes sorted by name, filtered by [query] on the name.
List<RecipeRecord> filterRecipes(List<RecipeRecord> items, String query) {
  final sorted = List.of(items)
    ..sort((a, b) => a.item.name.compareTo(b.item.name));
  if (query.isEmpty) return sorted;
  final q = query.toLowerCase();
  return sorted.where((i) => i.item.name.toLowerCase().contains(q)).toList();
}

/// Ingredient names matching [query], selected ones first, then A-Z.
List<String> filterIngredients(
  List<String> available,
  Set<String> selected,
  String query,
) {
  final q = query.toLowerCase();
  final list = q.isEmpty
      ? List.of(available)
      : available.where((m) => m.toLowerCase().contains(q)).toList();
  list.sort((a, b) {
    final aS = selected.contains(a);
    final bS = selected.contains(b);
    if (aS && !bS) return -1;
    if (!aS && bS) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  });
  return list;
}
