import 'nutrients.dart';

/// One of the person's own recipes ("house recipes"), from `/recipes`. The
/// server computes the numbers from the ingredients; the app only shows them.
class HouseIngredient {
  const HouseIngredient({required this.name, required this.grams, this.isBaseline = false});

  final String name;
  final double grams;
  final bool isBaseline;

  static HouseIngredient? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final name = raw['name'];
    final grams = raw['grams'];
    if (name is! String || grams is! num) return null;
    return HouseIngredient(name: name, grams: grams.toDouble(), isBaseline: raw['is_baseline'] == true);
  }
}

class HouseRecipe {
  const HouseRecipe({
    required this.id,
    required this.title,
    required this.servings,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.estimated,
    this.mine = true,
    this.ownerName,
    this.nutrients,
    this.description,
    this.steps = const [],
    this.ingredients = const [],
  });

  final String id;
  final String title;
  final double servings;

  /// Per serving.
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  /// Shown as "estimated": something in it was typed rather than looked up.
  final bool estimated;

  /// False for a recipe a friend shared with me.
  final bool mine;
  final String? ownerName;
  final Nutrients? nutrients;
  final String? description;
  final List<String> steps;
  final List<HouseIngredient> ingredients;

  /// The food-log amounts for eating [portions] servings.
  int caloriesFor(double portions) => (calories * portions).round();

  static HouseRecipe? fromJson(Object? raw) {
    try {
      final j = raw as Map<String, dynamic>;
      return HouseRecipe(
        id: j['id'] as String,
        title: j['title'] as String,
        servings: (j['servings'] as num).toDouble(),
        calories: (j['calories_per_serving'] as num).toInt(),
        proteinG: ((j['protein_g'] as num?) ?? 0).toDouble(),
        carbsG: ((j['carbs_g'] as num?) ?? 0).toDouble(),
        fatG: ((j['fat_g'] as num?) ?? 0).toDouble(),
        estimated: j['estimated'] == true,
        mine: j['mine'] != false,
        ownerName: j['owner_name'] as String?,
        nutrients: Nutrients.fromJson(j['nutrients']),
        description: j['description'] as String?,
        steps: [for (final s in (j['steps'] as List? ?? const [])) s as String],
        ingredients: [
          for (final i in (j['ingredients'] as List? ?? const [])) ?HouseIngredient.fromJson(i),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

/// An ingredient being added to a new recipe: either a USDA food (the server
/// looks the numbers up) or one the person types (always shown as estimated).
class DraftIngredient {
  const DraftIngredient({
    required this.name,
    required this.grams,
    this.fdcId,
    this.caloriesPer100g,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatPer100g = 0,
    this.isBaseline = false,
  });

  final String name;
  final double grams;
  final int? fdcId;
  final double? caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final bool isBaseline;

  bool get typedByHand => fdcId == null;

  Map<String, Object?> toJson() => {
        'name': name,
        'grams': grams,
        if (fdcId != null) 'fdc_id': fdcId,
        // Only for an ingredient with no USDA id; the server ignores it otherwise.
        if (fdcId == null && caloriesPer100g != null)
          'per_100g': {
            'calories': caloriesPer100g,
            'protein_g': proteinPer100g,
            'carbs_g': carbsPer100g,
            'fat_g': fatPer100g,
          },
        if (isBaseline) 'is_baseline': true,
      };
}

/// A rough preview while building a recipe. The server's number is the real one.
int? previewCaloriesPerServing(List<DraftIngredient> items, double servings) {
  if (items.isEmpty || servings <= 0) return null;
  var total = 0.0;
  for (final i in items) {
    final c = i.caloriesPer100g;
    if (c == null) return null;
    total += c * i.grams / 100;
  }
  return (total / servings).round();
}


/// A recipe as listed inside a collection or in Highlights.
class RecipeBrief {
  const RecipeBrief({required this.id, required this.title, required this.calories, required this.estimated, required this.mine});

  final String id;
  final String title;
  final int calories;
  final bool estimated;
  final bool mine;

  static RecipeBrief? fromJson(Object? raw) {
    try {
      final j = raw as Map<String, dynamic>;
      return RecipeBrief(
        id: j['id'] as String,
        title: j['title'] as String,
        calories: (j['calories_per_serving'] as num).toInt(),
        estimated: j['estimated'] == true,
        mine: j['mine'] != false,
      );
    } catch (_) {
      return null;
    }
  }
}

class RecipeCollection {
  const RecipeCollection({required this.id, required this.name, required this.isDefault, this.items = const []});

  final String id;
  final String name;

  /// "Saved": made automatically, can't be deleted.
  final bool isDefault;
  final List<RecipeBrief> items;

  bool contains(String recipeId) => items.any((i) => i.id == recipeId);

  static RecipeCollection? fromJson(Object? raw) {
    try {
      final j = raw as Map<String, dynamic>;
      return RecipeCollection(
        id: j['id'] as String,
        name: j['name'] as String,
        isDefault: j['is_default'] == true,
        items: [for (final i in (j['items'] as List? ?? const [])) ?RecipeBrief.fromJson(i)],
      );
    } catch (_) {
      return null;
    }
  }
}
