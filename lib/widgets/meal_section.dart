import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/food_entry.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';
import 'pressable.dart';

/// Meal card: title + kcal total + add button, then swipe-to-delete food rows
/// with a right-aligned calorie pill.
class MealSection extends StatelessWidget {
  const MealSection({
    super.key,
    required this.title,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
    this.accent = TrackerColors.accentStart,
  });

  final String title;
  final List<FoodEntry> entries;
  final VoidCallback onAdd;
  final void Function(String id) onRemove;
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
                Pressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onAdd();
                  },
                  haptics: true,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TrackerColors.alpha(accent, 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: TrackerColors.alpha(accent, 0.28), width: 1),
                    ),
                    child: Icon(CupertinoIcons.add, size: 15, color: accent),
                  ),
                ),
              ],
            ),
          ),
          if (entries.isNotEmpty) const AppDivider(indent: 18),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Text(
                'Tap + to search for something to eat.',
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
                      (entry) => Dismissible(
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
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: TrackerColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(CupertinoIcons.delete, color: TrackerColors.textPrimary, size: 18),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          HapticFeedback.lightImpact();
                          onRemove(entry.id);
                        },
                        child: _FoodRow(entry: entry),
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
  const _FoodRow({required this.entry});

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
            color: TrackerColors.accentStart,
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
