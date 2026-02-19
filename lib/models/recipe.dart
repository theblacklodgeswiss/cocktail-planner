class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    this.type = 'cocktail',
  });

  final String id;
  final String name;
  final List<String> ingredients;
  final String type;

  bool get isShot => type == 'shot';

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final normalizedType =
        ((json['type'] as String?) ??
                (name.toLowerCase().startsWith('shot') ? 'shot' : 'cocktail'))
            .toLowerCase();
    return Recipe(
      id: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      name: name,
      ingredients:
          ((json['ingredients'] ?? json['zutaten']) as List<dynamic>)
              .cast<String>(),
      type: normalizedType,
    );
  }
}
