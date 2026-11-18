/// The weekly calorie budget from `GET /budget/week`. The server does the
/// maths (and enforces the floor and the limits); the app only shows it.
class BudgetPrefs {
  const BudgetPrefs({
    this.weekly = false,
    this.nudges = false,
    this.weekStartDay = 0,
    this.weights,
  });

  /// Use the flexible weekly allowance instead of the same target every day.
  final bool weekly;

  /// Show the gentle "want to spread it?" card after a bigger day.
  final bool nudges;

  /// 0 = Monday ... 6 = Sunday.
  final int weekStartDay;

  /// Seven numbers adding to 7 ("weekend flex"), from the first day of the week.
  final List<double>? weights;

  bool get weekendFlex => weights != null;

  static BudgetPrefs fromJson(Map<String, dynamic> j) => BudgetPrefs(
        weekly: j['mode'] == 'weekly',
        nudges: j['nudges'] == true,
        weekStartDay: ((j['week_start_day'] as num?) ?? 0).toInt().clamp(0, 6),
        weights: (j['weights'] as List?)?.map((w) => (w as num).toDouble()).toList(),
      );
}

/// "Weekend flex": a little more on Saturday and Sunday, a little less on the
/// other days, adding up to the same week. Listed from [weekStartDay].
List<double> weekendFlexWeights(int weekStartDay) => [
      for (var i = 0; i < 7; i++) ((weekStartDay + i) % 7) >= 5 ? 1.15 : 0.94,
    ];

enum BudgetDayState { pastLogged, pastUnlogged, today, future }

class BudgetDay {
  const BudgetDay({required this.date, required this.base, required this.eaten, required this.state, required this.allowance});

  final DateTime date;
  final int base;
  final int? eaten;
  final BudgetDayState state;
  final int allowance;

  static BudgetDay fromJson(Map<String, dynamic> j) => BudgetDay(
        date: DateTime.parse(j['date'] as String),
        base: (j['base'] as num).toInt(),
        eaten: (j['eaten'] as num?)?.toInt(),
        allowance: (j['allowance'] as num).toInt(),
        state: switch (j['state']) {
          'past_logged' => BudgetDayState.pastLogged,
          'past_unlogged' => BudgetDayState.pastUnlogged,
          'today' => BudgetDayState.today,
          _ => BudgetDayState.future,
        },
      );
}

class BudgetNudge {
  const BudgetNudge({required this.canSpread, required this.message, this.perDay, this.days = 0});

  /// False when the overage is too big to spread: the card is then only a kind
  /// line with no action.
  final bool canSpread;
  final String message;
  final int? perDay;
  final int days;

  static BudgetNudge? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final message = raw['message'];
    if (message is! String || message.isEmpty) return null;
    return BudgetNudge(
      canSpread: raw['kind'] == 'spread',
      message: message,
      perDay: (raw['per_day'] as num?)?.toInt(),
      days: ((raw['days'] as num?) ?? 0).toInt(),
    );
  }
}

class WeekBudgetData {
  const WeekBudgetData({
    required this.weekly,
    required this.weekStart,
    required this.allowanceToday,
    required this.dailyTarget,
    required this.bank,
    required this.explanation,
    required this.days,
    this.nudge,
  });

  final bool weekly;
  final DateTime weekStart;

  /// What to aim for today: the flexible allowance in weekly mode, otherwise
  /// the usual target.
  final int allowanceToday;
  final int dailyTarget;
  final int bank;
  final String explanation;
  final List<BudgetDay> days;
  final BudgetNudge? nudge;

  static WeekBudgetData? fromJson(Map<String, dynamic> j) {
    try {
      return WeekBudgetData(
        weekly: j['mode'] == 'weekly',
        weekStart: DateTime.parse(j['week_start'] as String),
        allowanceToday: (j['allowance_today'] as num).toInt(),
        dailyTarget: (j['daily_target'] as num).toInt(),
        bank: (j['bank'] as num).toInt(),
        explanation: (j['explanation'] as String?) ?? '',
        days: [for (final d in j['days'] as List) BudgetDay.fromJson(d as Map<String, dynamic>)],
        nudge: BudgetNudge.fromJson(j['nudge']),
      );
    } catch (_) {
      return null;
    }
  }
}
