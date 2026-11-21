import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';
import 'pressable.dart';

/// One meal's total, for the collapsed summary.
class MealTotal {
  const MealTotal({required this.title, required this.calories, required this.icon});

  final String title;
  final int calories;
  final IconData icon;
}

/// "Today's meals" that folds away. Open, it shows the meal cards; folded, it
/// shrinks to a single row of little chips (one per meal with its calories) so
/// the first screen stays light but the day is still readable at a glance.
/// The header is the handle: tap it and the chevron turns while the content
/// glides open or shut.
class MealsFold extends StatelessWidget {
  const MealsFold({
    super.key,
    required this.label,
    required this.countLabel,
    required this.open,
    required this.onToggle,
    required this.totals,
    required this.child,
  });

  final String label;
  final String countLabel;
  final bool open;
  final VoidCallback onToggle;
  final List<MealTotal> totals;

  /// The meal cards, shown when open.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eaten = totals.where((t) => t.calories > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          label: '$label. $countLabel',
          excludeSemantics: true,
          child: Pressable(
            key: const ValueKey('meals_fold_header'),
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle();
            },
            scale: 0.99,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SectionHeader(
                label: label,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(countLabel, style: AppType.caption(color: TrackerColors.textTertiary, size: 11)),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: open ? 0 : -0.25,
                      duration: AppMotion.medium,
                      curve: AppMotion.spring,
                      child: Icon(CupertinoIcons.chevron_down, size: 14, color: TrackerColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSize(
          duration: AppMotion.sheet,
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppMotion.medium,
            switchInCurve: AppMotion.standard,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: open
                ? KeyedSubtree(key: const ValueKey('meals_open'), child: child)
                : KeyedSubtree(
                    key: const ValueKey('meals_folded'),
                    child: _Chips(totals: eaten, onTap: onToggle),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.totals, required this.onTap});

  final List<MealTotal> totals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            tr('Nothing logged yet. Tap to open your meals.'),
            style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < totals.length; i++)
          TweenAnimationBuilder<double>(
            key: ValueKey('chip_${totals[i].title}'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 380 + i * 70),
            curve: Interval((i * 70) / (380 + i * 70), 1, curve: AppMotion.spring),
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
            ),
            child: Pressable(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TrackerColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: TrackerColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(totals[i].icon, size: 14, color: TrackerColors.accentStartText),
                    const SizedBox(width: 6),
                    Text(context.tr(totals[i].title), style: AppType.caption(color: TrackerColors.textSecondary, size: 12)),
                    const SizedBox(width: 6),
                    Text('${totals[i].calories}', style: AppType.caption(color: TrackerColors.textPrimary, size: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
