import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detected_food.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../models/house_recipe.dart';
import '../providers/food_region_provider.dart';
import '../providers/house_recipes_provider.dart';
import '../providers/recipe_photo_picker.dart';
import '../services/photo_estimation.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_field.dart';
import 'food_search_screen.dart';
import '../l10n/app_strings.dart';

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
  const NewRecipeScreen({super.key, this.fromMeal, this.initialTitle, this.pickFood, this.makeId, this.edit, this.analyzeDish});

  final List<FoodEntry>? fromMeal;
  final String? initialTitle;

  /// Change one of my recipes instead of making a new one: the title, the
  /// servings and the ingredients. Its photos stay.
  final HouseRecipe? edit;

  /// Replace the photo analysis (for tests).
  final Future<List<DetectedFood>> Function(Uint8List photo, String? region)? analyzeDish;

  /// Replace the food search (for tests).
  final Future<FoodItem?> Function(BuildContext context)? pickFood;
  final String Function()? makeId;

  @override
  ConsumerState<NewRecipeScreen> createState() => _NewRecipeScreenState();
}

class _NewRecipeScreenState extends ConsumerState<NewRecipeScreen> {
  late final _title = TextEditingController(text: widget.edit?.title ?? widget.initialTitle ?? '');
  late final _servings = TextEditingController(text: _servingsText(widget.edit?.servings ?? 1));
  late final _items = <DraftIngredient>[...?widget.edit?.ingredients.map((i) => i.toDraft())];
  bool _saving = false;
  bool _looking = false;
  String? _error;

  /// The photo the ingredients were read from; it becomes the cover once saved.
  Uint8List? _dishPhoto;

  bool get _fromMeal => widget.fromMeal != null;
  bool get _editing => widget.edit != null;

  static String _servingsText(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// The ingredients differ from what the recipe had, so they need pricing again.
  bool get _ingredientsChanged {
    final before = widget.edit?.ingredients ?? const <HouseIngredient>[];
    if (before.length != _items.length) return true;
    for (var i = 0; i < before.length; i++) {
      final a = before[i];
      final b = _items[i];
      if (a.name != b.name || a.grams != b.grams || a.fdcId != b.fdcId || a.caloriesPer100g != b.caloriesPer100g) return true;
    }
    return false;
  }

  double? get _servingCount {
    final v = double.tryParse(_servings.text.trim().replaceAll(',', '.'));
    return v != null && v >= 0.25 && v <= 100 ? v : null;
  }

  bool get _canSave =>
      !_saving &&
      !_looking &&
      _title.text.trim().isNotEmpty &&
      _servingCount != null &&
      (_fromMeal || _editing || _items.isNotEmpty);

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
            child: Text(tr('Search for a food')),
          ),
          CupertinoActionSheetAction(
            key: const ValueKey('add_typed'),
            onPressed: () => Navigator.pop(context, 'typed'),
            child: Text(tr('Type my own (like a spice paste)')),
          ),
          if (!_editing) ...[
            CupertinoActionSheetAction(
              key: const ValueKey('add_photo_camera'),
              onPressed: () => Navigator.pop(context, 'photo_camera'),
              child: Text(tr('Photograph the finished dish')),
            ),
            CupertinoActionSheetAction(
              key: const ValueKey('add_photo_library'),
              onPressed: () => Navigator.pop(context, 'photo_library'),
              child: Text(tr('Use a photo of the dish')),
            ),
          ],
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice.startsWith('photo_')) return _fromPhoto(choice == 'photo_camera' ? ImageSource.camera : ImageSource.gallery);
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
            // An Open Food Facts product has no USDA id (0): it is sent with
            // its own per-100 g values, like an ingredient typed by hand.
            fdcId: food.fdcId > 0 ? food.fdcId : null,
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

  /// A photo of the finished dish becomes an editable ingredient list. The
  /// numbers are still worked out on the server when the recipe is saved, and
  /// anything the server could only estimate is marked as estimated.
  Future<void> _fromPhoto(ImageSource source) async {
    Uint8List? photo;
    try {
      photo = await ref.read(recipePhotoPickerProvider)(source);
    } catch (_) {
      if (mounted) setState(() => _error = source == ImageSource.camera ? tr("Couldn't open the camera. Allow access in Settings, then try again.") : tr("Couldn't open the photos. Allow access in Settings, then try again."));
      return;
    }
    if (photo == null || !mounted) return;
    setState(() {
      _looking = true;
      _error = null;
    });
    try {
      final region = ref.read(foodRegionProvider);
      final found = await (widget.analyzeDish ?? (p, r) => PhotoEstimationService().analyzePhoto(p, region: r))(photo, region);
      if (!mounted) return;
      setState(() {
        _looking = false;
        if (found.isEmpty) {
          _error = tr("We couldn't tell what's in that photo. Try a clearer one, or add the ingredients yourself.");
          return;
        }
        _dishPhoto = photo;
        for (final f in found) {
          final id = f.matchedFdcId;
          _items.add(DraftIngredient(
            name: f.name,
            grams: f.estimatedGrams.clamp(1, 20000).toDouble(),
            fdcId: f.matched && !f.estimated && id != null && id > 0 ? id : null,
            caloriesPer100g: f.caloriesPer100g,
            proteinPer100g: f.proteinPer100g ?? 0,
            carbsPer100g: f.carbsPer100g ?? 0,
            fatPer100g: f.fatPer100g ?? 0,
            fromEstimate: f.estimated,
          ));
        }
      });
    } on PhotoAnalysisException catch (e) {
      if (mounted) {
        setState(() {
          _looking = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _looking = false;
          _error = tr("Couldn't look at that photo. Check your connection and try again.");
        });
      }
    }
  }

  Future<double?> _askGrams(String name) async {
    final c = TextEditingController();
    final result = await showCupertinoDialog<double>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(tr('How much?')),
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
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
          CupertinoDialogAction(
            key: const ValueKey('grams_ok'),
            onPressed: () {
              final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
              Navigator.pop(context, v != null && v > 0 && v <= 20000 ? v : null);
            },
            child: Text(tr('Add')),
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
        title: Text(tr('Your own ingredient')),
        content: Column(
          children: [
            const SizedBox(height: 8),
            CupertinoTextField(key: const ValueKey('typed_name'), controller: name, placeholder: 'Name'),
            const SizedBox(height: 6),
            CupertinoTextField(
              key: const ValueKey('typed_grams'),
              controller: grams,
              placeholder: tr('Grams used'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 6),
            CupertinoTextField(
              key: const ValueKey('typed_kcal'),
              controller: kcal,
              placeholder: tr('Calories per 100 g'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
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
            child: Text(tr('Add')),
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
    final service = ref.read(houseRecipesProvider.notifier).service;
    final editing = widget.edit;
    final result = editing != null
        ? await service.update(
            editing.id,
            title: _title.text.trim(),
            servings: servings,
            // Only when they changed: pricing them again asks USDA again.
            ingredients: _ingredientsChanged ? List.of(_items) : null,
          )
        : await service.create(
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
    // The photo the ingredients came from is the cover. Best effort: the
    // recipe is saved either way.
    final dish = _dishPhoto;
    if (editing == null && dish != null) await service.putPhoto(recipe.id, 0, dish);
    if (!mounted) return;
    ref.read(houseRecipesProvider.notifier).add(recipe);
    if (dish != null) unawaited(ref.read(houseRecipesProvider.notifier).load());
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
        middle: Text(_editing ? tr('Edit recipe') : (_fromMeal ? tr('Save as recipe') : tr('New recipe'))),
        backgroundColor: TrackerColors.background,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            AppField(key: const ValueKey('recipe_title_field'), placeholder: tr('Recipe name'), controller: _title, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr('Servings it makes'), style: AppType.body(size: 14))),
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
                  meal.length == 1
                ? tr('1 logged food, {kcal} kcal in total. Saved as an estimate, since the ingredients aren’t listed.', {'kcal': meal.fold<int>(0, (a, e) => a + e.calories)})
                : tr('{n} logged foods, {kcal} kcal in total. Saved as an estimate, since the ingredients aren’t listed.', {'n': meal.length, 'kcal': meal.fold<int>(0, (a, e) => a + e.calories)}),
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
                                _items[i].fromEstimate
                      ? tr('{g} g · estimated', {'g': _items[i].grams.round()})
                      : (_items[i].typedByHand ? tr('{g} g · typed by you', {'g': _items[i].grams.round()}) : '${_items[i].grams.round()} g'),
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
              if (_looking)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    key: const ValueKey('looking_at_photo'),
                    children: [
                      const CupertinoActivityIndicator(),
                      const SizedBox(width: 10),
                      Text(tr('Looking at your photo…'), style: AppType.caption(size: 13)),
                    ],
                  ),
                ),
              AppButton.glass(
                key: const ValueKey('add_ingredient'),
                label: tr('Add an ingredient'),
                icon: CupertinoIcons.add,
                onPressed: _looking ? null : _addIngredient,
              ),
              if (_dishPhoto != null) ...[
                const SizedBox(height: 10),
                Text(
                  tr('Read from your photo. It becomes the recipe’s cover. Check the amounts: they are estimates.'),
                  key: const ValueKey('dish_photo_note'),
                  style: AppType.caption(size: 12),
                ),
              ],
              if (preview != null) ...[
                const SizedBox(height: 12),
                Text(
                  tr('About {preview} kcal per serving. The exact numbers are worked out when you save.', {'preview': preview}),
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
            AppButton(key: const ValueKey('save_recipe'), label: _editing ? tr('Save changes') : tr('Save recipe'), loading: _saving, onPressed: _canSave ? _save : null),
          ],
        ),
      ),
    );
  }
}
