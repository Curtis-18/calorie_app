import 'package:flutter/cupertino.dart';
import '../models/progress.dart';
import 'dashboard_header_bits.dart';
import 'game/header_chips.dart';
import 'game/progress_sheet.dart';
import 'page_header.dart';

/// Today's top bar: the greeting, the day on screen with arrows to move
/// between days, and the streak flame and level on the right (both open the
/// progress sheet). Profile, notifications and log out live in the Profile
/// tab now; they used to crowd this bar.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.streakDays,
    this.progress,
    required this.dateLabel,
    this.onPreviousDay,
    this.onNextDay,
    this.canGoNext = false,
  });

  /// Local fallback streak, used until [progress] has loaded (or offline).
  final int streakDays;

  /// Server-side game state: streak tier, freezes and level.
  final ProgressData? progress;
  final String dateLabel;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;
  final bool canGoNext;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return PageHeader(
      eyebrow: _greeting,
      title: dateLabel,
      titleAccessory: DayArrows(onPrevious: onPreviousDay, onNext: onNextDay, canGoNext: canGoNext),
      actions: [
        if (progress != null) ...[
          FlameStreakPill(streak: progress!.streak, onTap: () => showProgressSheet(context)),
          LevelBadge(level: progress!.level, size: 34, onTap: () => showProgressSheet(context)),
        ] else
          StreakPill(days: streakDays),
      ],
    );
  }
}
