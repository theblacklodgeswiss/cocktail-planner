import 'material_item.dart';
import 'recipe.dart';

class CocktailData {
  const CocktailData({
    required this.materials,
    required this.recipes,
    this.fixedValues = const [],
  });

  final List<MaterialItem> materials;
  final List<Recipe> recipes;
  final List<MaterialItem> fixedValues;

  factory CocktailData.fromJson(Map<String, dynamic> json) {
    return CocktailData(
      materials: ((json['materials'] ?? json['materialListe']) as List<dynamic>)
          .map((item) => MaterialItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      recipes: ((json['recipes'] ?? json['rezepte']) as List<dynamic>)
          .map((recipe) => Recipe.fromJson(recipe as Map<String, dynamic>))
          .toList(),
      fixedValues: ((json['fixedValues'] ?? json['wertigkeiten'])
                  as List<dynamic>? ??
              const [])
          .map((item) => MaterialItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
