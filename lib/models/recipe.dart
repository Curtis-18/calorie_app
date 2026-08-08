class RecipeSummary {
  final String id;
  final String name;
  final String thumbnailUrl;

  RecipeSummary({required this.id, required this.name, required this.thumbnailUrl});

  factory RecipeSummary.fromJson(Map<String, dynamic> json) {
    return RecipeSummary(
      id: json['idMeal'] as String,
      name: json['strMeal'] as String,
      thumbnailUrl: json['strMealThumb'] as String,
    );
  }
}

class RecipeIngredient {
  final String name;
  final String measure;

  RecipeIngredient({required this.name, required this.measure});
}

class RecipeDetail {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String instructions;
  final String category;
  final String area;
  final List<RecipeIngredient> ingredients;

  RecipeDetail({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.instructions,
    required this.category,
    required this.area,
    required this.ingredients,
  });

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    final ingredients = <RecipeIngredient>[];
    for (var i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'] as String?;
      final measure = json['strMeasure$i'] as String?;
      if (ingredient != null && ingredient.trim().isNotEmpty) {
        ingredients.add(RecipeIngredient(
          name: ingredient.trim(),
          measure: (measure ?? '').trim(),
        ));
      }
    }

    return RecipeDetail(
      id: json['idMeal'] as String,
      name: json['strMeal'] as String,
      thumbnailUrl: json['strMealThumb'] as String,
      instructions: (json['strInstructions'] as String?) ?? '',
      category: (json['strCategory'] as String?) ?? '',
      area: (json['strArea'] as String?) ?? '',
      ingredients: ingredients,
    );
  }
}