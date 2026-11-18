import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_entry.dart';
import '../models/house_recipe.dart';
import '../providers/food_log_provider.dart';
import '../providers/house_recipes_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';
import 'log_food_sheet.dart' show mealForHour, mealIcon;
import 'pressable.dart';

/// One of the person's recipes: its numbers per serving, what is in it, and
/// "Log this" with a servings stepper.
Future<void> showHouseRecipeSheet(BuildContext context, HouseRecipe recipe, {DateTime Function()? now}) {
  return showAppSheet<void>(context: context, builder: (_) => HouseRecipeSheet(recipe: recipe, now: now));
}

class HouseRecipeSheet extends ConsumerStatefulWidget {
  const HouseRecipeSheet({super.key, required this.recipe, this.now});

  final HouseRecipe recipe;
  final DateTime Function()? now;

  @override
  ConsumerState<HouseRecipeSheet> createState() => _HouseRecipeSheetState();
}

class _HouseRecipeSheetState extends ConsumerState<HouseRecipeSheet> {
  late MealType _meal = mealForHour((widget.now ?? DateTime.now)().hour);
  double _portions = 1;
  bool _busy = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  String _portionLabel(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toString();

  void _step(double by) {
    final next = (_portions + by).clamp(0.5, 20.0);
    if (next == _portions) return;
    HapticFeedback.selectionClick();
    setState(() => _portions = next);
  }

  /// One tap: the entry is saved through the normal offline-safe path, then the
  /// server is quietly told which recipe it came from. Nothing waits on that.
  void _log() {
    final r = widget.recipe;
    final p = _portions;
    double tidy(double v) => (v * 10).roundToDouble() / 10;
    final entry = FoodEntry(
      id: '${_now.microsecondsSinceEpoch}_recipe',
      name: r.title,
      calories: r.caloriesFor(p),
      proteinG: tidy(r.proteinG * p),
      carbsG: tidy(r.carbsG * p),
      fatG: tidy(r.fatG * p),
      mealType: _meal,
      source: FoodSource.manual,
      timestamp: _now,
      nutrients: r.nutrients?.scaled(p),
    );
    final food = ref.read(foodLogProvider.notifier);
    final service = ref.read(houseRecipesProvider.notifier).service;
    final day = _now;
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    unawaited(() async {
      try {
        await food.addEntry(entry);
      } catch (_) {
        return; // the food log already explains a failed save
      }
      await service.recordLog(r.id, entry, p, day);
    }());
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final error = await ref.read(houseRecipesProvider.notifier).remove(widget.recipe.id);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = false);
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Couldn't delete it"),
        content: Text(error),
        actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.title, key: const ValueKey('recipe_title'), style: AppType.title()),
          const SizedBox(height: 4),
          Text(
            '${r.caloriesFor(_portions)} kcal'
            ' · ${(r.proteinG * _portions).round()} g protein'
            ' · ${(r.carbsG * _portions).round()} g carbs'
            ' · ${(r.fatG * _portions).round()} g fat',
            key: const ValueKey('recipe_numbers'),
            style: AppType.body(size: 14, color: TrackerColors.textSecondary),
          ),
          if (r.estimated) ...[
            const SizedBox(height: 4),
            Text(
              'Estimated: some numbers were typed in rather than looked up.',
              key: const ValueKey('recipe_estimated'),
              style: AppType.caption(size: 12),
            ),
          ],
          if (r.ingredients.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              r.ingredients.map((i) => '${i.name} ${i.grams.round()} g').join(' · '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption(size: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Servings', style: AppType.body(size: 14)),
              const Spacer(),
              _StepButton(key: const ValueKey('servings_minus'), icon: CupertinoIcons.minus, onTap: () => _step(-0.5)),
              SizedBox(
                width: 56,
                child: Text(_portionLabel(_portions), key: const ValueKey('servings_value'), textAlign: TextAlign.center, style: AppType.title()),
              ),
              _StepButton(key: const ValueKey('servings_plus'), icon: CupertinoIcons.plus, onTap: () => _step(0.5)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final m in MealType.values)
                Expanded(
                  child: Pressable(
                    key: ValueKey('meal_${m.name}'),
                    onTap: () => setState(() => _meal = m),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _meal == m ? TrackerColors.alpha(TrackerColors.accentEnd, 0.18) : TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
                        borderRadius: BorderRadius.circular(AppRadii.button),
                        border: Border.all(color: _meal == m ? TrackerColors.accentEnd : TrackerColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(mealIcon(m), size: 16, color: _meal == m ? TrackerColors.accentEnd : TrackerColors.textSecondary),
                          const SizedBox(height: 4),
                          Text(m.name, style: AppType.caption(size: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(key: const ValueKey('log_recipe'), label: 'Log this', onPressed: _busy ? null : _log),
          const SizedBox(height: 6),
          Center(
            child: CupertinoButton(
              key: const ValueKey('delete_recipe'),
              onPressed: _busy ? null : _delete,
              child: Text('Delete recipe', style: AppType.caption(size: 13, color: TrackerColors.error)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TrackerColors.alpha(TrackerColors.textPrimary, 0.07),
            border: Border.all(color: TrackerColors.border),
          ),
          child: Icon(icon, size: 16, color: TrackerColors.textPrimary),
        ),
      );
}
