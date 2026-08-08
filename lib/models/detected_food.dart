class DetectedFood {
  String name;
  double estimatedGrams;
  double? caloriesPer100g;

  DetectedFood({
    required this.name,
    required this.estimatedGrams,
    this.caloriesPer100g,
  });

  int get estimatedCalories =>
      ((caloriesPer100g ?? 0) / 100 * estimatedGrams).round();
}