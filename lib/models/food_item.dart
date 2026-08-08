class FoodItem {
  final int fdcId;
  final String description;
  final double? caloriesPer100g;

  FoodItem({
    required this.fdcId,
    required this.description,
    this.caloriesPer100g,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    double? calories;
    final nutrients = json['foodNutrients'] as List<dynamic>? ?? [];

    for (final n in nutrients) {
      if (n['nutrientName'] == 'Energy' && n['unitName'] == 'KCAL') {
        calories = (n['value'] as num).toDouble();
        break;
      }
    }

    return FoodItem(
      fdcId: json['fdcId'],
      description: json['description'] ?? 'Unknown food',
      caloriesPer100g: calories,
    );
  }
}