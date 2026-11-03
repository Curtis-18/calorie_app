import 'progress.dart';
import 'weight.dart';

/// Everything the progress share card shows, worked out from the user's
/// progress and (optionally) weight history.
///
/// Deliberately leaves out calorie and macro numbers and absolute body
/// weight: the client decided a share card shows weight only as a *change*,
/// and only when the user opts in.
class ShareCardData {
  const ShareCardData({
    required this.date,
    required this.streakDays,
    required this.bestStreak,
    required this.tier,
    required this.level,
    required this.levelFraction,
    required this.totalXp,
    required this.badges,
    required this.badgeCount,
    required this.badgeTotal,
    this.weightChange,
    this.weightSince,
  });

  /// Most unlocked badges the card has room for.
  static const maxBadges = 6;

  final DateTime date;
  final int streakDays;
  final int bestStreak;
  final FlameTier tier;
  final int level;
  final double levelFraction;
  final int totalXp;

  /// Unlocked badges, newest first, at most [maxBadges].
  final List<AchievementInfo> badges;
  final int badgeCount;
  final int badgeTotal;

  /// e.g. "–2.4 kg", or null when weight isn't on the card.
  final String? weightChange;

  /// e.g. "since Sep 1", paired with [weightChange].
  final String? weightSince;

  bool get hasStreak => streakDays > 0;
  bool get showsWeight => weightChange != null;

  /// Weight can only be shared as a change, which needs two weigh-ins.
  static bool canShareWeight(WeightHistory? weight) =>
      weight != null && weight.entries.length >= 2 && weight.summary != null;

  factory ShareCardData.from({
    required ProgressData progress,
    WeightHistory? weight,
    bool includeWeight = false,
    WeightUnit unit = WeightUnit.kg,
  }) {
    final unlocked = progress.achievements.where((a) => a.unlocked).toList()
      ..sort((a, b) {
        final da = a.unlockedOn, db = b.unlockedOn;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
    final withWeight = includeWeight && canShareWeight(weight);
    final summary = withWeight ? weight!.summary! : null;

    return ShareCardData(
      date: progress.date,
      streakDays: progress.streak.current,
      bestStreak: progress.streak.best,
      tier: progress.streak.tier,
      level: progress.level.level,
      levelFraction: progress.level.fraction,
      totalXp: progress.level.xp,
      badges: unlocked.take(maxBadges).toList(),
      badgeCount: unlocked.length,
      badgeTotal: progress.achievements.length,
      weightChange: summary == null ? null : unit.formatChange(summary.changeKg),
      weightSince: summary == null ? null : 'since ${shortDate(summary.startDate)}',
    );
  }

  /// Text that goes with the image in the share sheet.
  String get shareText {
    if (hasStreak) {
      return "I'm on a $streakDays-day streak and level $level on Calorie Tracker 🔥";
    }
    return "I'm level $level on Calorie Tracker 🔥";
  }

  static String shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  String get longDate => '${shortDate(date)}, ${date.year}';
}
