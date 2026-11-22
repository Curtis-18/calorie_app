class DayTrend {
  final DateTime date;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  DayTrend({
    required this.date,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory DayTrend.fromJson(Map<String, dynamic> json) {
    return DayTrend(
      date: DateTime.parse(json['date'] as String),
      calories: (json['calories'] as num).toInt(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
    );
  }
}

class InsightsData {
  final String narrative;
  final List<DayTrend> weeklyTrend;
  final DateTime generatedAt;

  /// Entries in the week shown whose numbers are an estimate (0 from an older backend).
  final int estimatedEntries;

  /// Minutes of movement logged this week and on how many days (0 from an older backend or none logged).
  final int movementMinutes;
  final int movementDays;

  InsightsData({
    required this.narrative,
    required this.weeklyTrend,
    required this.generatedAt,
    this.estimatedEntries = 0,
    this.movementMinutes = 0,
    this.movementDays = 0,
  });

  factory InsightsData.fromJson(Map<String, dynamic> json) {
    return InsightsData(
      narrative: json['narrative'] as String,
      weeklyTrend: (json['weekly_trend'] as List)
          .map((e) => DayTrend.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generated_at'] as String),
      estimatedEntries: (json['estimated_entries'] as num?)?.toInt() ?? 0,
      movementMinutes: (json['movement_minutes'] as num?)?.toInt() ?? 0,
      movementDays: (json['movement_days'] as num?)?.toInt() ?? 0,
    );
  }
}