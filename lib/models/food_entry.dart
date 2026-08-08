enum MealType { breakfast, lunch, dinner, snack }
enum FoodSource { manual, photo }

class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final MealType mealType;
  final FoodSource source;
  final DateTime timestamp;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    required this.mealType,
    required this.source,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'mealType': mealType.name,
        'source': source.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'],
        name: json['name'],
        calories: json['calories'],
        proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
        fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
        mealType: MealType.values.byName(json['mealType']),
        source: FoodSource.values.byName(json['source']),
        timestamp: DateTime.parse(json['timestamp']),
      );

  factory FoodEntry.fromApiJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'],
        name: json['name'],
        calories: json['calories'],
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
        mealType: MealType.values.byName(json['meal_type']),
        source: FoodSource.values.byName(json['source']),
        timestamp: DateTime.parse(json['timestamp']),
      );
}

extension FoodEntryListX on List<FoodEntry> {
  int get totalCalories => fold(0, (sum, e) => sum + e.calories);
  double get totalProtein => fold(0.0, (sum, e) => sum + e.proteinG);
  double get totalCarbs => fold(0.0, (sum, e) => sum + e.carbsG);
  double get totalFat => fold(0.0, (sum, e) => sum + e.fatG);
  List<FoodEntry> forMeal(MealType meal) => where((e) => e.mealType == meal).toList();
}