import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/food_entry.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';
import 'pressable.dart';

/// How the person wants to add food.
enum LogMethod { photo, search }

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

/// Which meal is this for? Shown before the camera opens (or the search),
/// with the meal already set from the time of day, so it is usually one tap.
Future<MealType?> showLogFoodSheet(BuildContext context, {required LogMethod method, MealType? initialMeal}) {
  return showAppSheet<MealType>(
    context: context,
    builder: (_) => AppSheet(
      child: _LogFoodSheet(method: method, initial: initialMeal ?? mealForHour(DateTime.now().hour)),
    ),
  );
}

class _LogFoodSheet extends StatefulWidget {
  const _LogFoodSheet({required this.method, required this.initial});

  final LogMethod method;
  final MealType initial;

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> {
  late MealType _meal = widget.initial;

  @override
  Widget build(BuildContext context) {
    final photo = widget.method == LogMethod.photo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(photo ? 'Snap your meal' : 'Search for a food', style: AppType.title(), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          photo
              ? "We'll spot the foods and estimate portions for you to check."
              : 'Find a food by name and enter how much you had.',
          style: AppType.callout(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('WHICH MEAL?', style: AppType.sectionLabel()),
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
        if (photo)
          AppButton(
            key: const ValueKey('log_continue'),
            label: 'Open camera',
            icon: CupertinoIcons.camera_fill,
            onPressed: () => Navigator.of(context).pop(_meal),
          )
        else
          AppButton.glass(
            key: const ValueKey('log_continue'),
            label: 'Search',
            icon: CupertinoIcons.search,
            onPressed: () => Navigator.of(context).pop(_meal),
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
