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

  int get estimatedCalories => ((caloriesPer100g ?? 0) / 100 * estimatedGrams).round();
  double get estimatedProtein => (proteinPer100g ?? 0) / 100 * estimatedGrams;
  double get estimatedCarbs => (carbsPer100g ?? 0) / 100 * estimatedGrams;
  double get estimatedFat => (fatPer100g ?? 0) / 100 * estimatedGrams;
}