import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_entry.dart';
import '../models/house_recipe.dart';
import '../providers/food_log_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/house_recipes_provider.dart';
import '../screens/new_recipe_screen.dart' show newRecipeId;
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'app_dialog.dart';
import 'glass.dart';
import 'log_food_sheet.dart' show mealForHour, mealIcon;
import 'pressable.dart';

/// One of the person's recipes: its numbers per serving, what is in it, and
/// "Log this" with a servings stepper.
Future<void> showHouseRecipeSheet(BuildContext context, HouseRecipe recipe, {DateTime Function()? now}) {
  return showAppSheet<void>(context: context, builder: (_) => HouseRecipeSheet(recipe: recipe, now: now));
}

/// Open a recipe by id: mine, or one a friend shared. If it can't be opened
/// (unshared, deleted, offline) say so instead of failing quietly.
Future<void> openRecipeById(BuildContext context, HouseRecipesNotifier notifier, String id, {DateTime Function()? now}) async {
  final recipe = await notifier.service.get(id);
  if (!context.mounted) return;
  if (recipe == null) {
    await showAppDialog(
      context: context,
      title: "Can't open this recipe",
      message: "It may have been unshared or deleted, or you're offline.",
      confirmLabel: 'OK',
    );
    return;
  }
  await showHouseRecipeSheet(context, recipe, now: now);
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

  Future<void> _tell(String title, String message) =>
      showAppDialog(context: context, title: title, message: message, confirmLabel: 'OK');

  Future<void> _pin() async {
    final error = await ref.read(houseRecipesProvider.notifier).togglePin(widget.recipe);
    if (!mounted) return;
    if (error != null) await _tell("Couldn't change Highlights", error);
  }

  Future<void> _save() async {
    final error = await ref.read(houseRecipesProvider.notifier).saveRecipe(widget.recipe.id);
    if (!mounted) return;
    await (error == null ? _tell('Saved', 'It’s in your Saved collection.') : _tell("Couldn't save it", error));
  }

  Future<void> _collections() async {
    final notifier = ref.read(houseRecipesProvider.notifier);
    final all = ref.read(houseRecipesProvider).collections;
    final picked = await showCupertinoModalPopup<Object>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Collections'),
        actions: [
          for (final c in all)
            CupertinoActionSheetAction(
              key: ValueKey('collection_${c.id}'),
              onPressed: () => Navigator.pop(context, c),
              child: Text(c.contains(widget.recipe.id) ? '✓ ${c.name}' : c.name),
            ),
          CupertinoActionSheetAction(
            key: const ValueKey('new_collection'),
            onPressed: () => Navigator.pop(context, 'new'),
            child: const Text('New collection…'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
    if (!mounted || picked == null) return;
    String? error;
    if (picked is RecipeCollection) {
      error = await notifier.setInCollection(picked, widget.recipe.id, inside: !picked.contains(widget.recipe.id));
    } else {
      final name = await _askName();
      if (name == null || !mounted) return;
      final id = newRecipeId();
      error = await notifier.createCollection(id, name);
      if (error == null) {
        final created = ref.read(houseRecipesProvider).collections.where((c) => c.id == id);
        if (created.isNotEmpty) error = await notifier.setInCollection(created.first, widget.recipe.id, inside: true);
      }
    }
    if (error != null && mounted) await _tell("Couldn't update that", error);
  }

  Future<String?> _askName() async {
    final c = TextEditingController();
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Name the collection'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(key: const ValueKey('collection_name'), controller: c, autofocus: true, placeholder: 'Meal prep'),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            key: const ValueKey('collection_name_ok'),
            onPressed: () => Navigator.pop(context, c.text.trim().isEmpty ? null : c.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  Future<void> _send() async {
    final friends = ref.read(friendsProvider).valueOrNull?.friends ?? const [];
    if (friends.isEmpty) {
      await _tell('No friends yet', 'Add a friend from the Friends tab, then you can send them recipes.');
      return;
    }
    final friend = await showCupertinoModalPopup<dynamic>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Send to a friend'),
        message: const Text('They can open it, save it and log it. You can take access back later.'),
        actions: [
          for (final f in friends)
            CupertinoActionSheetAction(key: ValueKey('send_to_${f.userId}'), onPressed: () => Navigator.pop(context, f), child: Text(f.username)),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
    if (friend == null || !mounted) return;
    setState(() => _busy = true);
    final error = await ref.read(houseRecipesProvider.notifier).service.share(widget.recipe.id, friend.userId as String, newRecipeId());
    if (!mounted) return;
    setState(() => _busy = false);
    await (error == null ? _tell('Sent', 'Your recipe is in your chat with ${friend.username}.') : _tell("Couldn't send it", error));
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
    final pinned = ref.watch(houseRecipesProvider).highlights.any((h) => h.id == r.id);
    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.title, key: const ValueKey('recipe_title'), style: AppType.title()),
          if (!r.mine) ...[
            const SizedBox(height: 2),
            Text(
              r.ownerName == null ? 'Shared with you' : 'From ${r.ownerName}',
              key: const ValueKey('recipe_from'),
              style: AppType.caption(size: 12),
            ),
          ],
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
          const SizedBox(height: 10),
          if (r.mine)
            Row(
              children: [
                Expanded(
                  child: _Chip(
                    key: const ValueKey('pin_recipe'),
                    icon: pinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
                    label: pinned ? 'Unpin' : 'Pin',
                    onTap: _busy ? null : _pin,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _Chip(key: const ValueKey('collections_button'), icon: CupertinoIcons.folder, label: 'Collections', onTap: _busy ? null : _collections)),
                const SizedBox(width: 8),
                Expanded(child: _Chip(key: const ValueKey('send_recipe'), icon: CupertinoIcons.paperplane, label: 'Send', onTap: _busy ? null : _send)),
              ],
            )
          else
            AppButton.glass(key: const ValueKey('save_shared'), label: 'Save to my recipes', icon: CupertinoIcons.bookmark, onPressed: _busy ? null : _save),
          if (r.mine)
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

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(color: TrackerColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: TrackerColors.textSecondary),
              const SizedBox(height: 4),
              Text(label, style: AppType.caption(size: 11)),
            ],
          ),
        ),
      );
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
