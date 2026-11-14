import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/food_entry.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'glass.dart';
import 'pressable.dart';

/// How the person wants to add food.
enum LogMethod { photo, search }

typedef LogFoodChoice = ({MealType meal, LogMethod method});

/// The meal most people are eating at [hour] (0-23), preselected in the sheet.
MealType mealForHour(int hour) {
  if (hour >= 4 && hour < 11) return MealType.breakfast;
  if (hour >= 11 && hour < 15) return MealType.lunch;
  if (hour >= 17 && hour < 22) return MealType.dinner;
  return MealType.snack;
}

IconData mealIcon(MealType meal) => switch (meal) {
      MealType.breakfast => CupertinoIcons.sun_max_fill,
      MealType.lunch => CupertinoIcons.sun_max,
      MealType.dinner => CupertinoIcons.moon_stars_fill,
      MealType.snack => CupertinoIcons.circle_grid_hex_fill,
    };

String _title(MealType meal) => '${meal.name[0].toUpperCase()}${meal.name.substring(1)}';

/// One sheet for logging: pick the meal (already set from the time of day),
/// then take a photo or search. Replaces two floating buttons that each
/// opened a separate meal picker first.
Future<LogFoodChoice?> showLogFoodSheet(BuildContext context, {MealType? initialMeal}) {
  return showAppSheet<LogFoodChoice>(
    context: context,
    builder: (_) => AppSheet(child: _LogFoodSheet(initial: initialMeal ?? mealForHour(DateTime.now().hour))),
  );
}

class _LogFoodSheet extends StatefulWidget {
  const _LogFoodSheet({required this.initial});

  final MealType initial;

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> {
  late MealType _meal = widget.initial;

  void _choose(LogMethod method) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop((meal: _meal, method: method));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Log food', style: AppType.title(), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        Text('MEAL', style: AppType.sectionLabel()),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final meal in MealType.values) ...[
              Expanded(
                child: _MealChip(
                  key: ValueKey('meal_${meal.name}'),
                  meal: meal,
                  selected: meal == _meal,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _meal = meal);
                  },
                ),
              ),
              if (meal != MealType.values.last) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _MethodTile(
          key: const ValueKey('log_photo'),
          icon: CupertinoIcons.camera_fill,
          title: 'Take a photo',
          subtitle: 'We spot the foods and estimate portions',
          primary: true,
          onTap: () => _choose(LogMethod.photo),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MethodTile(
          key: const ValueKey('log_search'),
          icon: CupertinoIcons.search,
          title: 'Search by name',
          subtitle: 'Find a food and enter how much you had',
          onTap: () => _choose(LogMethod.search),
        ),
      ],
    );
  }
}

class _MealChip extends StatelessWidget {
  const _MealChip({super.key, required this.meal, required this.selected, required this.onTap});

  final MealType meal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: _title(meal),
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.buttonAll,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.1) : TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            border: Border.all(
              color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.65) : TrackerColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mealIcon(meal),
                size: 18,
                color: selected ? TrackerColors.accentStartText : TrackerColors.textSecondary,
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Text(
                  _title(meal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(
                    color: selected ? TrackerColors.textPrimary : TrackerColors.textSecondary,
                    size: 12,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The headline way to log: drawn on the brand gradient.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ink = primary ? TrackerColors.onAccent : TrackerColors.textPrimary;
    final quiet = primary ? TrackerColors.alpha(TrackerColors.onAccent, 0.8) : TrackerColors.textSecondary;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: primary ? TrackerColors.calorieGradient : null,
            color: primary ? null : TrackerColors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: primary ? null : Border.all(color: TrackerColors.border, width: 1),
            boxShadow: primary ? AppDecor.glow(TrackerColors.accentStart, blur: 22, opacity: 0.3) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary
                      ? TrackerColors.alpha(TrackerColors.onAccent, 0.12)
                      : TrackerColors.alpha(TrackerColors.textPrimary, 0.07),
                  borderRadius: AppRadii.smallAll,
                ),
                child: Icon(icon, size: 21, color: ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.headline(color: ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppType.caption(color: quiet, size: 12.5)),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, size: 15, color: quiet),
            ],
          ),
        ),
      ),
    );
  }
}
