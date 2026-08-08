enum Gender { male, female }
enum ActivityLevel { sedentary, light, moderate, active, veryActive }
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
  });

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
      );
}