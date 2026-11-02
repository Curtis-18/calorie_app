import 'package:flutter/cupertino.dart';

/// Streak flame tiers, by current streak length.
enum FlameTier {
  spark('Spark', 0),
  ember('Ember', 3),
  flame('Flame', 7),
  blaze('Blaze', 14),
  inferno('Inferno', 30);

  const FlameTier(this.label, this.minDays);

  final String label;
  final int minDays;

  static FlameTier fromApi(String? name) =>
      values.asNameMap()[name] ?? FlameTier.spark;

  /// The next tier up, or null at the top.
  FlameTier? get next => index + 1 < values.length ? values[index + 1] : null;
}

class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.best,
    required this.tier,
    required this.freezes,
    required this.maxFreezes,
    required this.loggedToday,
  });

  final int current;
  final int best;
  final FlameTier tier;
  final int freezes;
  final int maxFreezes;
  final bool loggedToday;

  /// A streak that ends today unless something is logged.
  bool get atRisk => current > 0 && !loggedToday;

  factory StreakInfo.fromJson(Map<String, dynamic> j) => StreakInfo(
        current: (j['current'] as num).toInt(),
        best: (j['best'] as num).toInt(),
        tier: FlameTier.fromApi(j['tier'] as String?),
        freezes: (j['freezes'] as num).toInt(),
        maxFreezes: (j['max_freezes'] as num).toInt(),
        loggedToday: j['logged_today'] == true,
      );
}

class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.xp,
    required this.levelXp,
    required this.nextLevelXp,
  });

  final int level;
  final int xp;
  final int levelXp;
  final int nextLevelXp;

  int get xpIntoLevel => xp - levelXp;
  int get xpForLevel => nextLevelXp - levelXp;
  double get fraction => xpForLevel <= 0 ? 0 : (xpIntoLevel / xpForLevel).clamp(0.0, 1.0);

  factory LevelInfo.fromJson(Map<String, dynamic> j) => LevelInfo(
        level: (j['level'] as num).toInt(),
        xp: (j['xp'] as num).toInt(),
        levelXp: (j['level_xp'] as num).toInt(),
        nextLevelXp: (j['next_level_xp'] as num).toInt(),
      );
}

class TodayInfo {
  const TodayInfo({required this.xp, required this.perfectDay});

  final int xp;
  final bool perfectDay;

  factory TodayInfo.fromJson(Map<String, dynamic> j) => TodayInfo(
        xp: (j['xp'] as num).toInt(),
        perfectDay: j['perfect_day'] == true,
      );
}

class AchievementInfo {
  const AchievementInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.progress,
    required this.goal,
    this.unlockedOn,
  });

  final String id;
  final String title;
  final String description;
  final bool unlocked;
  final DateTime? unlockedOn;
  final int progress;
  final int goal;

  double get fraction => goal <= 0 ? 0 : (progress / goal).clamp(0.0, 1.0);

  IconData get icon => switch (id) {
        'first_bite' => CupertinoIcons.flag_fill,
        'snapshot' => CupertinoIcons.camera_fill,
        'early_bird' => CupertinoIcons.sunrise_fill,
        'full_house' => CupertinoIcons.square_grid_2x2_fill,
        'bullseye' => CupertinoIcons.scope,
        'protein_pro' => CupertinoIcons.bolt_fill,
        'on_fire' => CupertinoIcons.flame_fill,
        'inferno' => CupertinoIcons.flame,
        'centurion' => CupertinoIcons.rosette,
        _ => CupertinoIcons.star_fill,
      };

  factory AchievementInfo.fromJson(Map<String, dynamic> j) => AchievementInfo(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        unlocked: j['unlocked'] == true,
        unlockedOn: DateTime.tryParse(j['unlocked_on'] as String? ?? ''),
        progress: (j['progress'] as num).toInt(),
        goal: (j['goal'] as num).toInt(),
      );
}

/// `GET /progress`: everything the game layer shows.
class ProgressData {
  const ProgressData({
    required this.date,
    required this.streak,
    required this.level,
    required this.today,
    required this.achievements,
  });

  final DateTime date;
  final StreakInfo streak;
  final LevelInfo level;
  final TodayInfo today;
  final List<AchievementInfo> achievements;

  int get unlockedCount => achievements.where((a) => a.unlocked).length;

  factory ProgressData.fromJson(Map<String, dynamic> j) => ProgressData(
        date: DateTime.parse(j['date'] as String),
        streak: StreakInfo.fromJson(j['streak'] as Map<String, dynamic>),
        level: LevelInfo.fromJson(j['level'] as Map<String, dynamic>),
        today: TodayInfo.fromJson(j['today'] as Map<String, dynamic>),
        achievements: (j['achievements'] as List<dynamic>)
            .map((a) => AchievementInfo.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

/// Something worth a celebration, found by comparing progress over time.
sealed class Celebration {
  const Celebration();
}

class PerfectDayCelebration extends Celebration {
  const PerfectDayCelebration();
}

class LevelUpCelebration extends Celebration {
  const LevelUpCelebration(this.level);
  final int level;
}

class AchievementCelebration extends Celebration {
  const AchievementCelebration(this.achievement);
  final AchievementInfo achievement;
}
