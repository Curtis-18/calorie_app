/// "Your week" from `GET /reports/weekly`: a few kind lines and any habit
/// pattern the logs support. Written by the server's code, not a language
/// model, so the app only ever shows what the numbers say.
class HabitPattern {
  const HabitPattern({required this.id, required this.text, required this.tip});

  final String id;
  final String text;
  final String tip;
}

class WeeklyReport {
  const WeeklyReport({
    required this.daysLogged,
    required this.proteinGoalDays,
    required this.message,
    required this.enoughData,
    required this.daysNeeded,
    required this.patterns,
  });

  final int daysLogged;

  /// Days this week that reached the protein goal; null without a plan.
  final int? proteinGoalDays;
  final String message;

  /// Whether there is enough history (about two weeks) to look for patterns.
  final bool enoughData;
  final int daysNeeded;
  final List<HabitPattern> patterns;

  static WeeklyReport? fromJson(Object? raw) {
    try {
      final j = raw as Map<String, dynamic>;
      return WeeklyReport(
        daysLogged: (j['days_logged'] as num).toInt(),
        proteinGoalDays: (j['protein_goal_days'] as num?)?.toInt(),
        message: (j['message'] as String?) ?? '',
        enoughData: j['enough_data'] == true,
        daysNeeded: ((j['days_needed'] as num?) ?? 0).toInt(),
        patterns: [
          for (final p in (j['patterns'] as List? ?? const []))
            HabitPattern(id: p['id'] as String, text: p['text'] as String, tip: (p['tip'] as String?) ?? ''),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}
