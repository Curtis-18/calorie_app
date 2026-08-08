import 'package:flutter/material.dart';
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

    return Material(
      color: TrackerColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: TrackerColors.primary,
                              letterSpacing: 1.2,
                            ),
                      ),
                      Text(
                        '$mealTotal kcal',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: TrackerColors.primary),
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
          if (entries.isNotEmpty) const Divider(height: 1, color: TrackerColors.divider),
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        onLongPress: onRemove,
        title: Text(entry.name, style: Theme.of(context).textTheme.bodyLarge),
        subtitle: Text(
          '${entry.carbsG.round()}c • ${entry.fatG.round()}f • ${entry.proteinG.round()}p',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '${entry.calories} kcal',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: TrackerColors.textPrimary,
              ),
        ),
      ),
    );
  }
}