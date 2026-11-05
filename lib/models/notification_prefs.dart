/// The person's notification choices, as the server keeps them.
///
/// Push delivery is not switched on yet (it needs the iOS build), so these
/// are saved now and take effect when it is. See [NotificationPrefs.pushLive].
class NotificationPrefs {
  const NotificationPrefs({
    this.friendSnaps = true,
    this.reactions = true,
    this.streakReminders = true,
    this.milestones = true,
    this.mealNudgeHour,
    this.quietStart = 22,
    this.quietEnd = 8,
    this.utcOffsetMinutes = 0,
    this.pausedUntil,
    this.dailyCap = 2,
  });

  /// Flip to true when push delivery ships (iOS build with Apple/Firebase
  /// credentials). Until then the settings screen says so honestly.
  static const bool pushLive = false;

  final bool friendSnaps;
  final bool reactions;
  final bool streakReminders;
  final bool milestones;

  /// Local hour for the optional meal reminder; null means off.
  final int? mealNudgeHour;
  final int quietStart;
  final int quietEnd;
  final int utcOffsetMinutes;
  final DateTime? pausedUntil;
  final int dailyCap;

  bool isPausedAt(DateTime now) => pausedUntil != null && now.isBefore(pausedUntil!);

  NotificationPrefs copyWith({
    bool? friendSnaps,
    bool? reactions,
    bool? streakReminders,
    bool? milestones,
    Object? mealNudgeHour = _keep,
    int? quietStart,
    int? quietEnd,
    Object? pausedUntil = _keep,
  }) =>
      NotificationPrefs(
        friendSnaps: friendSnaps ?? this.friendSnaps,
        reactions: reactions ?? this.reactions,
        streakReminders: streakReminders ?? this.streakReminders,
        milestones: milestones ?? this.milestones,
        mealNudgeHour: identical(mealNudgeHour, _keep) ? this.mealNudgeHour : mealNudgeHour as int?,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        utcOffsetMinutes: utcOffsetMinutes,
        pausedUntil: identical(pausedUntil, _keep) ? this.pausedUntil : pausedUntil as DateTime?,
        dailyCap: dailyCap,
      );

  static const Object _keep = Object();

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        friendSnaps: j['friend_snaps'] as bool? ?? true,
        reactions: j['reactions'] as bool? ?? true,
        streakReminders: j['streak_reminders'] as bool? ?? true,
        milestones: j['milestones'] as bool? ?? true,
        mealNudgeHour: (j['meal_nudge_hour'] as num?)?.toInt(),
        quietStart: (j['quiet_start'] as num?)?.toInt() ?? 22,
        quietEnd: (j['quiet_end'] as num?)?.toInt() ?? 8,
        utcOffsetMinutes: (j['utc_offset_minutes'] as num?)?.toInt() ?? 0,
        pausedUntil: j['paused_until'] == null ? null : DateTime.parse(j['paused_until'] as String).toLocal(),
        dailyCap: (j['daily_cap'] as num?)?.toInt() ?? 2,
      );
}

/// "8 AM", "12 PM", "10 PM".
String hourLabel(int hour) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h ${hour < 12 ? 'AM' : 'PM'}';
}

/// "10 PM to 8 AM", or "Off" when the two are the same hour.
String quietHoursLabel(int start, int end) => start == end ? 'Off' : '${hourLabel(start)} to ${hourLabel(end)}';
