import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../models/house_recipe.dart';
import '../providers/house_recipes_provider.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_field.dart';
import 'food_search_screen.dart';

/// A random version-4 UUID. The app chooses the id so that a retry after a lost
/// response saves the recipe once, not twice.
String newRecipeId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${[for (var i = 0; i < 4; i++) h(i)].join()}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${[for (var i = 10; i < 16; i++) h(i)].join()}';
}

/// Make a recipe: a title, how many servings it makes, and its ingredients.
/// The numbers are worked out on the server from the ingredients.
///
/// With [fromMeal] it saves foods already logged as one recipe instead, using
/// their calories as a one-serving estimate (no ingredient list).
class NewRecipeScreen extends ConsumerStatefulWidget {
  const NewRecipeScreen({super.key, this.fromMeal, this.initialTitle, this.pickFood, this.makeId});

  final List<FoodEntry>? fromMeal;
  final String? initialTitle;

  /// Replace the food search (for tests).
  final Future<FoodItem?> Function(BuildContext context)? pickFood;
  final String Function()? makeId;

  @override
  ConsumerState<NewRecipeScreen> createState() => _NewRecipeScreenState();
}

class _NewRecipeScreenState extends ConsumerState<NewRecipeScreen> {
  late final _title = TextEditingController(text: widget.initialTitle ?? '');
  final _servings = TextEditingController(text: '1');
  final _items = <DraftIngredient>[];
  bool _saving = false;
  String? _error;

  bool get _fromMeal => widget.fromMeal != null;

  double? get _servingCount {
    final v = double.tryParse(_servings.text.trim().replaceAll(',', '.'));
    return v != null && v >= 0.25 && v <= 100 ? v : null;
  }

  bool get _canSave =>
      !_saving && _title.text.trim().isNotEmpty && _servingCount != null && (_fromMeal || _items.isNotEmpty);

  @override
  void dispose() {
    _title.dispose();
    _servings.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            key: const ValueKey('add_search'),
            onPressed: () => Navigator.pop(context, 'search'),
            child: const Text('Search for a food'),
          ),
          CupertinoActionSheetAction(
            key: const ValueKey('add_typed'),
            onPressed: () => Navigator.pop(context, 'typed'),
            child: const Text('Type my own (like a spice paste)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'search') {
      final food = await (widget.pickFood ??
          (c) => Navigator.push<FoodItem>(
                c,
                CupertinoPageRoute(builder: (_) => const FoodSearchScreen(mealType: MealType.snack, pickOnly: true)),
              ))(context);
      if (food == null || !mounted) return;
      final grams = await _askGrams(food.description);
      if (grams == null) return;
      setState(() => _items.add(DraftIngredient(
            name: food.description,
            grams: grams,
            fdcId: food.fdcId,
            caloriesPer100g: food.caloriesPer100g,
            proteinPer100g: food.proteinPer100g ?? 0,
            carbsPer100g: food.carbsPer100g ?? 0,
            fatPer100g: food.fatPer100g ?? 0,
          )));
    } else {
      final typed = await _askTyped();
      if (typed != null) setState(() => _items.add(typed));
    }
  }

  Future<double?> _askGrams(String name) async {
    final c = TextEditingController();
    final result = await showCupertinoDialog<double>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('How much?'),
        content: Column(
          children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            CupertinoTextField(
              key: const ValueKey('grams_field'),
              controller: c,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              placeholder: 'grams',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            key: const ValueKey('grams_ok'),
            onPressed: () {
              final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
              Navigator.pop(context, v != null && v > 0 && v <= 20000 ? v : null);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  Future<DraftIngredient?> _askTyped() async {
    final name = TextEditingController();
    final grams = TextEditingController();
    final kcal = TextEditingController();
    double? num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
    final result = await showCupertinoDialog<DraftIngredient>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Your own ingredient'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            CupertinoTextField(key: const ValueKey('typed_name'), controller: name, placeholder: 'Name'),
            const SizedBox(height: 6),
            CupertinoTextField(
              key: const ValueKey('typed_grams'),
              controller: grams,
              placeholder: 'Grams used',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              key: const ValueKey('typed_kcal'),
              controller: kcal,
              placeholder: 'Calories per 100 g',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          CupertinoDialogAction(
            key: const ValueKey('typed_ok'),
            onPressed: () {
              final g = num(grams);
              final k = num(kcal);
              final n = name.text.trim();
              if (n.isEmpty || g == null || g <= 0 || g > 20000 || k == null || k < 0 || k > 1000) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context, DraftIngredient(name: n, grams: g, caloriesPer100g: k));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    name.dispose();
    grams.dispose();
    kcal.dispose();
    return result;
  }

  Future<void> _save() async {
    final servings = _servingCount;
    if (servings == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final meal = widget.fromMeal;
    final result = await ref.read(houseRecipesProvider.notifier).service.create(
          id: (widget.makeId ?? newRecipeId)(),
          title: _title.text.trim(),
          servings: servings,
          ingredients: meal == null ? List.of(_items) : const [],
          perServing: meal == null
              ? null
              : {
                  // What was eaten, split across the servings the recipe makes.
                  'calories': (meal.fold<int>(0, (a, e) => a + e.calories) / servings).round(),
                  'protein_g': _per(meal.fold<double>(0, (a, e) => a + e.proteinG), servings),
                  'carbs_g': _per(meal.fold<double>(0, (a, e) => a + e.carbsG), servings),
                  'fat_g': _per(meal.fold<double>(0, (a, e) => a + e.fatG), servings),
                },
        );
    if (!mounted) return;
    final recipe = result.recipe;
    if (recipe == null) {
      setState(() {
        _saving = false;
        _error = result.error;
      });
      return;
    }
    ref.read(houseRecipesProvider.notifier).add(recipe);
    Navigator.pop(context, recipe);
  }

  double _per(double total, double servings) => (total / servings * 10).roundToDouble() / 10;

  @override
  Widget build(BuildContext context) {
    final preview = _fromMeal ? null : previewCaloriesPerServing(_items, _servingCount ?? 0);
    final meal = widget.fromMeal;
    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_fromMeal ? 'Save as recipe' : 'New recipe'),
        backgroundColor: TrackerColors.background,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            AppField(key: const ValueKey('recipe_title_field'), placeholder: 'Recipe name', controller: _title, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Servings it makes', style: AppType.body(size: 14))),
                SizedBox(
                  width: 90,
                  child: AppField(
                    key: const ValueKey('servings_field'),
                    placeholder: '1',
                    controller: _servings,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (meal != null)
              AppCard(
                child: Text(
                  '${meal.length} logged food${meal.length == 1 ? '' : 's'}, '
                  '${meal.fold<int>(0, (a, e) => a + e.calories)} kcal in total. '
                  'Saved as an estimate, since the ingredients aren’t listed.',
                  key: const ValueKey('from_meal_note'),
                  style: AppType.body(size: 14, color: TrackerColors.textSecondary),
                ),
              )
            else ...[
              Text('INGREDIENTS', style: AppType.sectionLabel()),
              const SizedBox(height: 8),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    key: ValueKey('ingredient_$i'),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 14)),
                              Text(
                                '${_items[i].grams.round()} g${_items[i].typedByHand ? ' · typed by you' : ''}',
                                style: AppType.caption(size: 12),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          key: ValueKey('remove_ingredient_$i'),
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(32, 32),
                          onPressed: () => setState(() => _items.removeAt(i)),
                          child: Icon(CupertinoIcons.xmark_circle_fill, size: 20, color: TrackerColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              AppButton.glass(key: const ValueKey('add_ingredient'), label: 'Add an ingredient', icon: CupertinoIcons.add, onPressed: _addIngredient),
              if (preview != null) ...[
                const SizedBox(height: 12),
                Text(
                  'About $preview kcal per serving. The exact numbers are worked out when you save.',
                  key: const ValueKey('recipe_preview'),
                  style: AppType.caption(size: 12),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const ValueKey('recipe_error'), style: AppType.body(size: 13, color: TrackerColors.error)),
            ],
            const SizedBox(height: 20),
            AppButton(key: const ValueKey('save_recipe'), label: 'Save recipe', loading: _saving, onPressed: _canSave ? _save : null),
          ],
        ),
      ),
    );
  }
}
