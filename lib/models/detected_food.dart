import 'food_item.dart';
import 'nutrients.dart';

class DetectedFood {
  String name;
  double estimatedGrams;
  double? caloriesPer100g;
  double? proteinPer100g;
  double? carbsPer100g;
  double? fatPer100g;
  Map<String, double> extrasPer100g; // fibre, iron etc. from the USDA match
  bool matched; // false if USDA had no match for this name
  String? matchedDescription; // the USDA food the numbers come from
  int? matchedFdcId;

  DetectedFood({
    required this.name,
    required this.estimatedGrams,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.extrasPer100g = const {},
    this.matched = false,
    this.matchedDescription,
    this.matchedFdcId,
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
        extrasPer100g: Nutrients.per100gFromApi(json),
        matched: json['matched'] == true,
        matchedDescription: json['matched_description'] as String?,
        matchedFdcId: (json['matched_fdc_id'] as num?)?.toInt(),
      );

  /// Point this item at [food]'s nutrition. Grams and the user's name stay.
  void applyMatch(FoodItem food) {
    caloriesPer100g = food.caloriesPer100g;
    proteinPer100g = food.proteinPer100g;
    carbsPer100g = food.carbsPer100g;
    fatPer100g = food.fatPer100g;
    extrasPer100g = food.extrasPer100g;
    matchedDescription = food.description;
    matchedFdcId = food.fdcId;
    matched = food.caloriesPer100g != null;
  }

  int get estimatedCalories => ((caloriesPer100g ?? 0) / 100 * estimatedGrams).round();
  double get estimatedProtein => (proteinPer100g ?? 0) / 100 * estimatedGrams;
  double get estimatedCarbs => (carbsPer100g ?? 0) / 100 * estimatedGrams;
  double get estimatedFat => (fatPer100g ?? 0) / 100 * estimatedGrams;
  Nutrients? get estimatedNutrients => Nutrients.forPortion(extrasPer100g, estimatedGrams);
}