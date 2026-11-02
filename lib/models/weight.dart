enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.label);
  final String label;

  static const _lbPerKg = 2.20462262;

  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg * _lbPerKg;
  double toKg(double value) => this == WeightUnit.kg ? value : value / _lbPerKg;

  /// "72.4 kg" / "159.6 lb".
  String format(double kg, {int decimals = 1}) => '${fromKg(kg).toStringAsFixed(decimals)} $label';

  /// "–1.8 kg" / "+0.4 kg" for a change. An en dash, not U+2212 MINUS SIGN:
  /// that glyph is missing from some fonts and rendered as a box.
  String formatChange(double kg) {
    final v = fromKg(kg);
    if (v.abs() < 0.05) return '0.0 $label';
    return '${v < 0 ? '–' : '+'}${v.abs().toStringAsFixed(1)} $label';
  }
}

class WeightPoint {
  const WeightPoint({required this.date, required this.weightKg, required this.trendKg});

  final DateTime date;
  final double weightKg;
  final double trendKg;

  factory WeightPoint.fromJson(Map<String, dynamic> j) => WeightPoint(
        date: DateTime.parse(j['date'] as String),
        weightKg: (j['weight_kg'] as num).toDouble(),
        trendKg: (j['trend_kg'] as num).toDouble(),
      );
}

class WeightSummary {
  const WeightSummary({
    required this.startKg,
    required this.startDate,
    required this.currentKg,
    required this.trendKg,
    required this.changeKg,
    required this.lowestKg,
    required this.count,
    required this.daysSinceLast,
  });

  final double startKg;
  final DateTime startDate;
  final double currentKg;
  final double trendKg;

  /// Trend-based change since the first weigh-in.
  final double changeKg;
  final double lowestKg;
  final int count;
  final int daysSinceLast;

  factory WeightSummary.fromJson(Map<String, dynamic> j) => WeightSummary(
        startKg: (j['start_kg'] as num).toDouble(),
        startDate: DateTime.parse(j['start_date'] as String),
        currentKg: (j['current_kg'] as num).toDouble(),
        trendKg: (j['trend_kg'] as num).toDouble(),
        changeKg: (j['change_kg'] as num).toDouble(),
        lowestKg: (j['lowest_kg'] as num).toDouble(),
        count: (j['count'] as num).toInt(),
        daysSinceLast: (j['days_since_last'] as num).toInt(),
      );
}

class WeightHistory {
  const WeightHistory({required this.entries, this.summary});

  /// Oldest first.
  final List<WeightPoint> entries;
  final WeightSummary? summary;

  bool get isEmpty => entries.isEmpty;

  factory WeightHistory.fromJson(Map<String, dynamic> j) => WeightHistory(
        entries: (j['entries'] as List<dynamic>)
            .map((e) => WeightPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: j['summary'] == null ? null : WeightSummary.fromJson(j['summary'] as Map<String, dynamic>),
      );
}

class WeightSaveResult {
  const WeightSaveResult({required this.history, required this.targetsUpdated, this.notice});

  final WeightHistory history;
  final bool targetsUpdated;

  /// e.g. the goal was switched to Maintain at the bottom of the healthy range.
  final String? notice;

  factory WeightSaveResult.fromJson(Map<String, dynamic> j) => WeightSaveResult(
        history: WeightHistory.fromJson(j['history'] as Map<String, dynamic>),
        targetsUpdated: j['targets_updated'] == true,
        notice: j['notice'] as String?,
      );
}

/// Parse a typed weight in [unit] to kg, or null if it isn't a plausible
/// adult weight (20-400 kg, the server's bounds). Accepts "72,5".
double? parseWeightKg(String input, WeightUnit unit) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  if (value == null || value.isNaN) return null;
  final kg = unit.toKg(value);
  return (kg >= 20 && kg <= 400) ? kg : null;
}
