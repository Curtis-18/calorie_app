import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/food_entry.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';
import 'pressable.dart';

/// Meal card: title + kcal total + camera and search buttons, then food rows with a
/// right-aligned calorie pill. Tap a row to edit it, swipe it to delete.
class MealSection extends StatelessWidget {
  const MealSection({
    super.key,
    required this.title,
    required this.entries,
    required this.onPhoto,
    required this.onSearch,
    required this.onRemove,
    this.onEdit,
    this.accent = TrackerColors.accentStart,
  });

  final String title;
  final List<FoodEntry> entries;
  /// Photograph this meal: the app's main way to log, so it is the filled
  /// button. Null hides both buttons and the swipe to delete (a past day,
  /// which is read-only: they used to act on today's log while showing
  /// another day).
  final VoidCallback? onPhoto;

  /// Search for a food by name: the quieter, secondary button.
  final VoidCallback? onSearch;
  final void Function(String id)? onRemove;

  /// Tapping a row; null makes rows read-only (a past day).
  final void Function(FoodEntry entry)? onEdit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final mealTotal = entries.totalCalories;

    return Container(
      width: double.infinity,
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: AppDecor.glow(accent, blur: 8, opacity: 0.6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: AppType.sectionLabel(color: TrackerColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entries.isEmpty
                            ? 'Nothing logged'
                            : '$mealTotal kcal · ${entries.length} item${entries.length == 1 ? '' : 's'}',
                        style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
                      ),
                    ],
                  ),
                ),
                if (onSearch != null)
                  Semantics(
                    button: true,
                    label: 'Search for a food for $title',
                    child: Pressable(
                      key: ValueKey('meal_search_$title'),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSearch!();
                      },
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
                          shape: BoxShape.circle,
                          border: Border.all(color: TrackerColors.border, width: 1),
                        ),
                        child: Icon(CupertinoIcons.search, size: 15, color: TrackerColors.textSecondary),
                      ),
                    ),
                  ),
                if (onPhoto != null) ...[
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Take a photo of your $title',
                    child: Pressable(
                      key: ValueKey('meal_photo_$title'),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onPhoto!();
                      },
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: TrackerColors.calorieGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 12, opacity: 0.3),
                        ),
                        child: const Icon(CupertinoIcons.camera_fill, size: 18, color: TrackerColors.onAccent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entries.isNotEmpty) const AppDivider(indent: 18),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Text(
                onPhoto == null ? 'Nothing was logged for this meal.' : 'Take a photo of your meal, or search by name.',
                style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
              ),
            )
          else
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: Column(
                key: ValueKey(entries.map((entry) => entry.id).join('|')),
                children: entries
                    .map(
                      (entry) => onRemove == null
                          ? _FoodRow(key: ValueKey(entry.id), entry: entry)
                          : Dismissible(
                        key: ValueKey(entry.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                TrackerColors.alpha(TrackerColors.error, 0.0),
                                TrackerColors.alpha(TrackerColors.error, 0.32),
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: TrackerColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(CupertinoIcons.delete, color: TrackerColors.error, size: 18),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          HapticFeedback.lightImpact();
                          onRemove!(entry.id);
                        },
                        child: onEdit == null
                            ? _FoodRow(entry: entry)
                            : Pressable(
                                key: ValueKey('edit_${entry.id}'),
                                onTap: () => onEdit!(entry),
                                scale: 0.99,
                                child: _FoodRow(entry: entry),
                              ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({super.key, required this.entry});

  final FoodEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x00000000),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 14),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _MacroTag(value: entry.proteinG, color: TrackerColors.macroProtein),
                    const SizedBox(width: AppSpacing.sm),
                    _MacroTag(value: entry.carbsG, color: TrackerColors.macroCarbs),
                    const SizedBox(width: AppSpacing.sm),
                    _MacroTag(value: entry.fatG, color: TrackerColors.macroFat),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppPill(
            label: '${entry.calories} kcal',
            color: TrackerColors.accentStartText,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _MacroTag extends StatelessWidget {
  const _MacroTag({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: TrackerColors.alpha(color, 0.9),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${value.round()}g',
          style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
        ),
      ],
    );
  }
}
