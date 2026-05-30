class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    this.type = 'cocktail',
    this.ingredientAmounts = const {},
  });

  final String id;
  final String name;
  final List<String> ingredients;
  final String type;

  /// Amount per ingredient per drink, e.g. {"Vodka": "40ml", "Cranberry Saft": "50ml"}
  final Map<String, String> ingredientAmounts;

  bool get isShot => type == 'shot';
  bool get hasAmounts => ingredientAmounts.isNotEmpty;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final normalizedType =
        ((json['type'] as String?) ??
                (name.toLowerCase().startsWith('shot') ? 'shot' : 'cocktail'))
            .toLowerCase();
    final rawAmounts = json['ingredientAmounts'] as Map<String, dynamic>?;
    return Recipe(
      id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      name: name,
      ingredients:
          ((json['ingredients'] ?? json['zutaten']) as List<dynamic>)
              .cast<String>(),
      type: normalizedType,
      ingredientAmounts: rawAmounts != null
          ? rawAmounts.map((k, v) => MapEntry(k, v.toString()))
          : const {},
    );
  }
}
