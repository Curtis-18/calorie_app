class FoodItem {
  final int fdcId;
  final String description;
  final String? dataType;
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  FoodItem({
    required this.fdcId,
    required this.description,
    this.dataType,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    double? calories;
    double? protein;
    double? carbs;
    double? fat;
    final nutrients = json['foodNutrients'] as List<dynamic>? ?? [];

    for (final n in nutrients) {
      final name = n['nutrientName'];
      final value = (n['value'] as num?)?.toDouble();
      if (value == null) continue;

      switch (name) {
        case 'Energy':
          if (n['unitName'] == 'KCAL') calories = value;
          break;
        case 'Protein':
          protein = value;
          break;
        case 'Carbohydrate, by difference':
          carbs = value;
          break;
        case 'Total lipid (fat)':
          fat = value;
          break;
      }
    }

    return FoodItem(
      fdcId: json['fdcId'],
      description: json['description'] ?? 'Unknown food',
      dataType: json['dataType'] as String?,
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
    );
  }
}