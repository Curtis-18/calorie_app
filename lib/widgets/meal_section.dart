import 'package:flutter/cupertino.dart';
import '../theme/tracker_colors.dart';
import '../models/food_entry.dart';

class MealSection extends StatelessWidget {
  final String title;
  final List<FoodEntry> entries;
  final VoidCallback onAdd;
  final void Function(String id) onRemove;

  const MealSection({
    super.key,
    required this.title,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final mealTotal = entries.totalCalories;

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: TrackerColors.primary,
                              letterSpacing: 1.2,
                            ),
                      ),
                      Text(
                        '$mealTotal kcal',
                        style: CupertinoTheme.of(context).textTheme.textStyle,
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.add_circled, color: TrackerColors.primary),
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
          if (entries.isNotEmpty) const SizedBox(height: 1, child: ColoredBox(color: TrackerColors.divider)),
          ...entries.map((entry) => _FoodRow(
                entry: entry,
                onRemove: () => onRemove(entry.id),
              )),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback onRemove;

  const _FoodRow({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onRemove,
      child: CupertinoListTile(
        title: Text(entry.name, style: CupertinoTheme.of(context).textTheme.textStyle),
        subtitle: Text(
          '${entry.carbsG.round()}c • ${entry.fatG.round()}f • ${entry.proteinG.round()}p',
          style: CupertinoTheme.of(context).textTheme.textStyle,
        ),
        trailing: Text(
          '${entry.calories} kcal',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: TrackerColors.textPrimary,
              ),
        ),
      ),
    );
  }
}