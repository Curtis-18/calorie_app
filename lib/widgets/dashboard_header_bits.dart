import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
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
              color: TrackerColors.accentEnd,
              shadows: AppDecor.glow(TrackerColors.accentEnd, blur: 8, opacity: 0.7),
            ),
            const SizedBox(width: 5),
            Text(
              '$days day${days == 1 ? '' : 's'}',
              style: AppType.caption(color: TrackerColors.accentEnd, size: 12)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable date pill with previous/next arrows.
class DateSwitcher extends StatelessWidget {
  const DateSwitcher({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.canGoNext = false,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      opacity: 0.07,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Arrow(icon: CupertinoIcons.chevron_left, onTap: onPrevious),
            AnimatedSwitcher(
              duration: AppMotion.quick,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                label,
                key: ValueKey(label),
                style: AppType.caption(color: TrackerColors.textPrimary, size: 12)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _Arrow(icon: CupertinoIcons.chevron_right, onTap: canGoNext ? onNext : null),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptics: true,
      dimWhenDisabled: true,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 13, color: TrackerColors.textPrimary),
      ),
    );
  }
}
