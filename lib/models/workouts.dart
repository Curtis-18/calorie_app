import '../l10n/app_strings.dart';

/// The four slices of the weekly "Move plate". Every kind of movement fills one.
enum MoveSlice {
  strength,
  cardio,
  mobility,
  fun;

  static MoveSlice? parse(Object? raw) {
    for (final s in MoveSlice.values) {
      if (s.name == raw) return s;
    }
    return null;
  }

  String get label => switch (this) {
        MoveSlice.strength => tr('Strength'),
        MoveSlice.cardio => tr('Cardio'),
        MoveSlice.mobility => tr('Gentle movement'),
        MoveSlice.fun => tr('Dance and play'),
      };
}

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
String _str(Object? v) => v is String ? v : '';

/// One routine in the library list (no steps).
class WorkoutCard {
  const WorkoutCard({
    required this.id,
    required this.name,
    required this.minutes,
    required this.focus,
    required this.slice,
    required this.level,
    required this.levelLabel,
    required this.summary,
  });

  final String id;
  final String name;
  final int minutes;
  final String focus;
  final MoveSlice slice;

  /// easy | steady | strong
  final String level;
  final String levelLabel;
  final String summary;

  /// 2 to 5 minutes: a "Move bite".
  bool get isBite => minutes <= 5;

  static WorkoutCard? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final slice = MoveSlice.parse(raw['slice']);
    final minutes = _int(raw['minutes']);
    if (id is! String || slice == null || minutes <= 0) return null;
    return WorkoutCard(
      id: id,
      name: _str(raw['name']),
      minutes: minutes,
      focus: _str(raw['focus']),
      slice: slice,
      level: _str(raw['level']),
      levelLabel: _str(raw['level_label']),
      summary: _str(raw['summary']),
    );
  }
}

class WorkoutLibrary {
  const WorkoutLibrary(this.routines);

  final List<WorkoutCard> routines;

  factory WorkoutLibrary.fromJson(Map<String, dynamic> json) {
    final raw = json['routines'];
    return WorkoutLibrary([
      if (raw is List)
        for (final r in raw) ?WorkoutCard.fromJson(r),
    ]);
  }
}

enum StepMode { timed, reps, rest }

/// One screen of the player.
class PlayStep {
  const PlayStep({
    required this.mode,
    required this.name,
    required this.cue,
    required this.amount,
    required this.section,
    this.seconds,
    this.reps,
    this.side,
    this.round,
  });

  final StepMode mode;
  final String name;
  final String cue;
  final String amount;

  /// warm | main | cool
  final String section;
  final int? seconds;
  final int? reps;

  /// 1 or 2 when the same move is done on each side, in turn.
  final int? side;
  final int? round;

  static PlayStep? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final mode = switch (raw['mode']) {
      'timed' => StepMode.timed,
      'reps' => StepMode.reps,
      'rest' => StepMode.rest,
      _ => null,
    };
    if (mode == null) return null;
    final seconds = raw['seconds'] is num ? (raw['seconds'] as num).toInt() : null;
    final reps = raw['reps'] is num ? (raw['reps'] as num).toInt() : null;
    if (mode != StepMode.reps && (seconds == null || seconds <= 0)) return null;
    if (mode == StepMode.reps && (reps == null || reps <= 0)) return null;
    return PlayStep(
      mode: mode,
      name: _str(raw['name']),
      cue: _str(raw['cue']),
      amount: _str(raw['amount']),
      section: _str(raw['section']),
      seconds: seconds,
      reps: reps,
      side: raw['side'] is num ? (raw['side'] as num).toInt() : null,
      round: raw['round'] is num ? (raw['round'] as num).toInt() : null,
    );
  }
}

/// A routine opened: its reading sections and the flat list the player walks.
class WorkoutDetail {
  const WorkoutDetail({
    required this.card,
    required this.safety,
    required this.rounds,
    required this.play,
    required this.sections,
  });

  final WorkoutCard card;
  final String safety;
  final int rounds;
  final List<PlayStep> play;

  /// (title, lines) for reading before starting.
  final List<({String title, String? repeat, List<({String name, String amount, String cue})> steps})> sections;

  static WorkoutDetail? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final slice = MoveSlice.parse(raw['slice']);
    final minutes = _int(raw['minutes']);
    if (id is! String || slice == null || minutes <= 0) return null;
    final play = <PlayStep>[
      if (raw['play'] is List)
        for (final p in raw['play'] as List) ?PlayStep.fromJson(p),
    ];
    if (play.isEmpty) return null;
    final sections = <({String title, String? repeat, List<({String name, String amount, String cue})> steps})>[];
    if (raw['sections'] is List) {
      for (final s in raw['sections'] as List) {
        if (s is! Map<String, dynamic>) continue;
        final steps = <({String name, String amount, String cue})>[];
        if (s['steps'] is List) {
          for (final st in s['steps'] as List) {
            if (st is Map<String, dynamic>) {
              steps.add((name: _str(st['name']), amount: _str(st['amount']), cue: _str(st['cue'])));
            }
          }
        }
        sections.add((title: _str(s['title']), repeat: s['repeat'] is String ? s['repeat'] as String : null, steps: steps));
      }
    }
    return WorkoutDetail(
      card: WorkoutCard(
        id: id,
        name: _str(raw['name']),
        minutes: minutes,
        focus: _str(raw['focus']),
        slice: slice,
        level: _str(raw['level']),
        levelLabel: _str(raw['level_label']),
        summary: _str(raw['summary']),
      ),
      safety: _str(raw['safety']),
      rounds: _int(raw['rounds'], 1),
      play: play,
      sections: sections,
    );
  }
}

class SliceTotal {
  const SliceTotal({this.minutes = 0, this.sessions = 0});
  final int minutes;
  final int sessions;
}

/// This week, Monday to Sunday.
class MoveWeek {
  const MoveWeek({
    this.minutes = 0,
    this.sessions = 0,
    this.activeDays = 0,
    this.movedDays = const [false, false, false, false, false, false, false],
    this.todayIndex = 0,
    this.bySlice = const {},
    this.strengthDays = 0,
    this.todayMinutes = 0,
    this.todaySessions = 0,
    this.goalMinutes = 150,
    this.strengthDaysGoal = 2,
    this.weekMoved = false,
    this.streak = 0,
    this.eatBackPercent = 0,
    this.eatBackKcal = 0,
  });

  final int minutes;
  final int sessions;
  final int activeDays;
  final List<bool> movedDays;
  final int todayIndex;
  final Map<MoveSlice, SliceTotal> bySlice;
  final int strengthDays;
  final int todayMinutes;
  final int todaySessions;
  final int goalMinutes;
  final int strengthDaysGoal;
  final bool weekMoved;
  final int streak;

  /// The opt-in share of today's rough estimates added to today's calorie plan (0 = off), and the kcal that is today.
  final int eatBackPercent;
  final int eatBackKcal;

  SliceTotal slice(MoveSlice s) => bySlice[s] ?? const SliceTotal();

  /// 0.0 to 1.0 toward the weekly guide; never over-celebrated beyond 1.
  double get progress => goalMinutes <= 0 ? 0 : (minutes / goalMinutes).clamp(0.0, 1.0);

  factory MoveWeek.fromJson(Map<String, dynamic> json) {
    final days = json['moved_days'];
    final by = <MoveSlice, SliceTotal>{};
    final rawBy = json['by_slice'];
    if (rawBy is Map<String, dynamic>) {
      for (final s in MoveSlice.values) {
        final v = rawBy[s.name];
        if (v is Map<String, dynamic>) by[s] = SliceTotal(minutes: _int(v['minutes']), sessions: _int(v['sessions']));
      }
    }
    return MoveWeek(
      minutes: _int(json['minutes']),
      sessions: _int(json['sessions']),
      activeDays: _int(json['active_days']),
      movedDays: days is List && days.length == 7 ? [for (final d in days) d == true] : const [false, false, false, false, false, false, false],
      todayIndex: _int(json['today_index']).clamp(0, 6),
      bySlice: by,
      strengthDays: _int(json['strength_days']),
      todayMinutes: _int(json['today_minutes']),
      todaySessions: _int(json['today_sessions']),
      goalMinutes: _int(json['goal_minutes'], 150),
      strengthDaysGoal: _int(json['strength_days_goal'], 2),
      weekMoved: json['week_moved'] == true,
      streak: _int(json['streak']),
      eatBackPercent: _int(json['eat_back_percent']).clamp(0, 50),
      eatBackKcal: _int(json['eat_back_kcal']).clamp(0, 500),
    );
  }
}

/// One thing that was logged.
class MovementEntry {
  const MovementEntry({
    required this.id,
    required this.date,
    required this.label,
    required this.slice,
    required this.minutes,
    required this.intensity,
    required this.source,
    this.routineId,
    this.estKcal,
  });

  final String id;
  final String date;
  final String label;
  final MoveSlice slice;
  final int minutes;
  final String intensity;
  final String source;
  final String? routineId;
  final int? estKcal;

  static MovementEntry? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final slice = MoveSlice.parse(raw['slice']);
    if (id is! String || slice == null) return null;
    return MovementEntry(
      id: id,
      date: _str(raw['date']),
      label: _str(raw['label']),
      slice: slice,
      minutes: _int(raw['minutes']),
      intensity: _str(raw['intensity']),
      source: _str(raw['source']),
      routineId: raw['routine_id'] is String ? raw['routine_id'] as String : null,
      estKcal: raw['est_kcal'] is num ? (raw['est_kcal'] as num).toInt() : null,
    );
  }
}

/// An activity that can be logged by hand.
class ActivityChoice {
  const ActivityChoice({required this.key, required this.label, required this.slice});
  final String key;
  final String label;
  final MoveSlice slice;

  static ActivityChoice? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final slice = MoveSlice.parse(raw['slice']);
    final key = raw['key'];
    if (key is! String || slice == null) return null;
    return ActivityChoice(key: key, label: _str(raw['label']), slice: slice);
  }
}
