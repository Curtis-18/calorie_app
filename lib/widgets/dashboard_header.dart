import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/progress.dart';
import '../screens/notifications_screen.dart' show UnreadDot;
import '../theme/tracker_colors.dart';
import 'dashboard_header_bits.dart';
import 'game/header_chips.dart';
import 'game/progress_sheet.dart';
import 'page_header.dart';
import 'pressable.dart';

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
    this.hasUnreadNotifications = false,
    this.onOpenNotifications,
  });

  /// Something new to read: shows a small bell with a dot (gone once read).
  final bool hasUnreadNotifications;
  final VoidCallback? onOpenNotifications;

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
        if (hasUnreadNotifications) _NewBell(onTap: onOpenNotifications),
        if (progress != null) ...[
          FlameStreakPill(streak: progress!.streak, onTap: () => showProgressSheet(context)),
          LevelBadge(level: progress!.level, size: 34, onTap: () => showProgressSheet(context)),
        ] else
          StreakPill(days: streakDays),
      ],
    );
  }
}


/// Only while there is something unread: a small bell with a dot that opens
/// Notifications (where "What's new" is). Gone once it has been opened, so the
/// bar stays as uncrowded as before.
class _NewBell extends StatelessWidget {
  const _NewBell({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: 'Notifications, something new',
        child: Pressable(
          key: const ValueKey('whats_new_bell'),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(CupertinoIcons.bell, size: 20, color: TrackerColors.textSecondary),
                const Positioned(top: 6, right: 7, child: UnreadDot()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
