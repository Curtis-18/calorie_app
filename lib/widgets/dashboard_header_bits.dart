import 'package:flutter/cupertino.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'glass.dart';
import 'pressable.dart';

/// Warm-accent glass pill showing the current logging streak.
class StreakPill extends StatelessWidget {
  const StreakPill({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    if (days <= 0) return const SizedBox.shrink();

    return FrostedGlass(
      opacity: 0.14,
      tint: TrackerColors.accentEnd,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      border: Border.all(color: TrackerColors.alpha(TrackerColors.accentEnd, 0.28), width: 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.flame_fill,
              size: 13,
              color: TrackerColors.accentEndText,
              shadows: AppDecor.glow(TrackerColors.accentEnd, blur: 8, opacity: 0.7),
            ),
            const SizedBox(width: 5),
            Text(
              '$days day${days == 1 ? '' : 's'}',
              style: AppType.caption(color: TrackerColors.accentEndText, size: 12)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Previous-day / next-day arrows in a small glass pill, shown next to the
/// day's name in the Today header. "Next" is disabled on today.
class DayArrows extends StatelessWidget {
  const DayArrows({super.key, required this.onPrevious, required this.onNext, this.canGoNext = false});

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      opacity: 0.07,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: 'Previous day',
              child: _Arrow(key: const ValueKey('day_previous'), icon: CupertinoIcons.chevron_left, onTap: onPrevious),
            ),
            Semantics(
              button: true,
              label: 'Next day',
              child: _Arrow(
                key: const ValueKey('day_next'),
                icon: CupertinoIcons.chevron_right,
                onTap: canGoNext ? onNext : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptics: true,
      dimWhenDisabled: true,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 14, color: TrackerColors.textPrimary),
      ),
    );
  }
}
