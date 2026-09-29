import 'package:flutter/cupertino.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'dashboard_header_bits.dart';
import 'profile_sheet.dart';

/// Minimal top bar: greeting, streak pill, date switcher and a profile
/// affordance. Sits inside the frosted header of the dashboard.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.streakDays,
    required this.dateLabel,
    this.onPreviousDay,
    this.onNextDay,
    this.canGoNext = false,
    this.onProfileTap,
  });

  final int streakDays;
  final String dateLabel;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;
  final bool canGoNext;
  final VoidCallback? onProfileTap;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_greeting, style: AppType.title()),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StreakPill(days: streakDays),
                    const SizedBox(width: 8),
                    Flexible(
                      child: DateSwitcher(
                        label: dateLabel,
                        onPrevious: onPreviousDay,
                        onNext: onNextDay,
                        canGoNext: canGoNext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppIconButton(
            icon: CupertinoIcons.person_crop_circle,
            size: 44,
            iconSize: 22,
            color: TrackerColors.textPrimary,
            onPressed: onProfileTap ?? () => showProfileSheet(context),
          ),
        ],
      ),
    );
  }
}
