enum Gender { male, female }
enum ActivityLevel {
  sedentary('sedentary'),
  light('light'),
  moderate('moderate'),
  active('active'),
  veryActive('very_active');

  const ActivityLevel(this.apiName);

  /// The backend's spelling (`very_active` rather than `veryActive`).
  final String apiName;

  static ActivityLevel? fromApi(String? value) {
    for (final level in values) {
      if (level.apiName == value) return level;
    }
    return null;
  }
}
enum Goal { lose, maintain, gain }

class UserProfile {
  final double weightKg;
  final double heightCm;
  final DateTime dateOfBirth;
  final Gender gender;
  final ActivityLevel activityLevel;
  final Goal goal;

  // Computed by the backend, null until the first successful /targets call
  final double? bmr;
  final double? tdee;
  final int? calorieTarget;
  final double? bmi;
  final int? proteinTargetG;
  final int? fatTargetG;
  final int? carbsTargetG;

  /// Daily reference amounts for fibre, sodium, iron and calcium, from the
  /// server (`fiber_g`, `sodium_limit_mg`, `iron_mg`, `calcium_mg`).
  final Map<String, int>? nutrientTargets;

  UserProfile({
    required this.weightKg,
    required this.heightCm,
    required this.dateOfBirth,
    required this.gender,
    required this.activityLevel,
    required this.goal,
    this.bmr,
    this.tdee,
    this.calorieTarget,
    this.bmi,
    this.proteinTargetG,
    this.fatTargetG,
    this.carbsTargetG,
    this.nutrientTargets,
  });

  /// Parse `nutrient_targets` from a `/targets` response (null if absent).
  static Map<String, int>? targetsFromApi(Object? json) => _targetsFrom(json);

  static Map<String, int>? _targetsFrom(Object? json) {
    if (json is! Map) return null;
    return {
      for (final e in json.entries)
        if (e.value case final num value) e.key as String: value.round(),
    };
  }

  // Pure calendar math, not a business-logic formula, safe to keep local
  int get age {
    final today = DateTime.now();
    int years = today.year - dateOfBirth.year;
    final hadBirthdayThisYear = (today.month > dateOfBirth.month) ||
        (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
    if (!hadBirthdayThisYear) years--;
    return years;
  }

  String get bmiCategory {
    final b = bmi;
    if (b == null) return 'Unknown';
    if (b < 18.5) return 'Underweight';
    if (b < 25) return 'Normal weight';
    if (b < 30) return 'Overweight';
    return 'Obese';
  }

  UserProfile copyWithTargets({
    required double bmr,
    required double tdee,
    required int calorieTarget,
    required double bmi,
    required int proteinTargetG,
    required int fatTargetG,
    required int carbsTargetG,
    Map<String, int>? nutrientTargets,
  }) {
    return UserProfile(
      weightKg: weightKg,
      heightCm: heightCm,
      dateOfBirth: dateOfBirth,
      gender: gender,
      activityLevel: activityLevel,
      goal: goal,
      bmr: bmr,
      tdee: tdee,
      calorieTarget: calorieTarget,
      bmi: bmi,
      proteinTargetG: proteinTargetG,
      fatTargetG: fatTargetG,
      carbsTargetG: carbsTargetG,
      nutrientTargets: nutrientTargets ?? this.nutrientTargets,
    );
  }

  Map<String, dynamic> toJson() => {
        'weightKg': weightKg,
        'heightCm': heightCm,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'gender': gender.name,
        'activityLevel': activityLevel.name,
        'goal': goal.name,
        'bmr': bmr,
        'tdee': tdee,
        'calorieTarget': calorieTarget,
        'bmi': bmi,
        'proteinTargetG': proteinTargetG,
        'fatTargetG': fatTargetG,
        'carbsTargetG': carbsTargetG,
        if (nutrientTargets != null) 'nutrientTargets': nutrientTargets,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        weightKg: json['weightKg'],
        heightCm: json['heightCm'],
        dateOfBirth: DateTime.parse(json['dateOfBirth']),
        gender: Gender.values.byName(json['gender']),
        activityLevel: ActivityLevel.values.byName(json['activityLevel']),
        goal: Goal.values.byName(json['goal']),
        bmr: (json['bmr'] as num?)?.toDouble(),
        tdee: (json['tdee'] as num?)?.toDouble(),
        calorieTarget: json['calorieTarget'] as int?,
        bmi: (json['bmi'] as num?)?.toDouble(),
        proteinTargetG: json['proteinTargetG'] as int?,
        fatTargetG: json['fatTargetG'] as int?,
        carbsTargetG: json['carbsTargetG'] as int?,
        nutrientTargets: _targetsFrom(json['nutrientTargets']),
      );

  /// Rebuild a full profile from `GET /targets`, or null if the response
  /// lacks the onboarding answers (an older backend) or has unknown values.
  ///
  /// This is what restores a profile on a new device or browser, where the
  /// local cache is empty.
  static UserProfile? fromTargetsJson(Map<String, dynamic> json) {
    try {
      final dob = DateTime.tryParse(json['date_of_birth'] as String? ?? '');
      final gender = Gender.values.asNameMap()[json['sex']];
      final activity = ActivityLevel.fromApi(json['activity_level'] as String?);
      final goal = Goal.values.asNameMap()[json['goal']];
      if (dob == null || gender == null || activity == null || goal == null) return null;

      return UserProfile(
        weightKg: (json['weight_kg'] as num).toDouble(),
        heightCm: (json['height_cm'] as num).toDouble(),
        dateOfBirth: dob,
        gender: gender,
        activityLevel: activity,
        goal: goal,
        bmr: (json['bmr'] as num?)?.toDouble(),
        tdee: (json['tdee'] as num?)?.toDouble(),
        calorieTarget: (json['calorie_target'] as num?)?.toInt(),
        bmi: (json['bmi'] as num?)?.toDouble(),
        proteinTargetG: (json['protein_g'] as num?)?.toInt(),
        fatTargetG: (json['fat_g'] as num?)?.toInt(),
        carbsTargetG: (json['carbs_g'] as num?)?.toInt(),
        nutrientTargets: _targetsFrom(json['nutrient_targets']),
      );
    } catch (_) {
      return null;
    }
  }
}
