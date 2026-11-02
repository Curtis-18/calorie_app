class DetectedFood {
  String name;
  double estimatedGrams;
  double? caloriesPer100g;
  double? proteinPer100g;
  double? carbsPer100g;
  double? fatPer100g;
  bool matched; // false if USDA had no match for this name

  DetectedFood({
    required this.name,
    required this.estimatedGrams,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.matched = false,
  });

  /// One item from `POST /estimate-photo`. Macros are present when the
  /// backend matched the food in USDA (`matched: true`).
  factory DetectedFood.fromApiJson(Map<String, dynamic> json) => DetectedFood(
        name: json['name'] as String,
        estimatedGrams: (json['estimated_grams'] as num).toDouble(),
        caloriesPer100g: (json['calories_per_100g'] as num?)?.toDouble(),
        proteinPer100g: (json['protein_g_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (json['carbs_g_per_100g'] as num?)?.toDouble(),
        fatPer100g: (json['fat_g_per_100g'] as num?)?.toDouble(),
        matched: json['matched'] == true,
      );

  int get estimatedCalories => ((caloriesPer100g ?? 0) / 100 * estimatedGrams).round();
  double get estimatedProtein => (proteinPer100g ?? 0) / 100 * estimatedGrams;
  double get estimatedCarbs => (carbsPer100g ?? 0) / 100 * estimatedGrams;
  double get estimatedFat => (fatPer100g ?? 0) / 100 * estimatedGrams;
}