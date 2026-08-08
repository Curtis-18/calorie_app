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
  final List<String> tips;
  final List<DayTrend> weeklyTrend;
  final DateTime generatedAt;

  InsightsData({
    required this.narrative,
    required this.tips,
    required this.weeklyTrend,
    required this.generatedAt,
  });

  factory InsightsData.fromJson(Map<String, dynamic> json) {
    return InsightsData(
      narrative: json['narrative'] as String,
      tips: (json['tips'] as List).map((e) => e as String).toList(),
      weeklyTrend: (json['weekly_trend'] as List)
          .map((e) => DayTrend.fromJson(e as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }
}