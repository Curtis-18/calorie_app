import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/food_entry.dart';
import '../models/portion.dart';
import '../screens/food_search_screen.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'app_field.dart';
import 'glass.dart';
import 'onboarding/choice_card.dart';
import 'pressable.dart';

/// The grams a search entry was logged with, read from its name
/// ("Rice, white, cooked (150g)"). Null for photo entries, which have none.
final _gramsSuffix = RegExp(r'\s*\((\d+(?:[.,]\d+)?)\s*g\)$');

double? gramsInName(String name) {
  final match = _gramsSuffix.firstMatch(name);
  return match == null ? null : parseGrams(match.group(1)!);
}

/// [name] with its "(150g)" ending replaced for [grams].
String nameWithGrams(String name, double grams) =>
    '${name.replaceFirst(_gramsSuffix, '')} (${grams.round()}g)';

/// Correct a saved entry: its name, its meal, how much was eaten, or the food
/// itself. Returns the corrected entry (same id), or null if cancelled.
Future<FoodEntry?> showEditEntrySheet(BuildContext context, FoodEntry entry) {
  return showAppSheet<FoodEntry>(
    context: context,
    builder: (_) => AppSheet(child: EditEntrySheet(entry: entry)),
  );
}

class EditEntrySheet extends StatefulWidget {
  const EditEntrySheet({super.key, required this.entry, this.pickFood});

  final FoodEntry entry;

  /// Replaces the food search; for tests.
  final Future<FoodEntry?> Function(BuildContext context, MealType meal)? pickFood;

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  /// The food at its original portion: the entry as saved, or the food picked
  /// with "Change food". Every portion change is worked out from this, so
  /// stepping the amount up and back down can't drift through rounding.
  late FoodEntry _base = widget.entry;
  late double? _baseGrams = gramsInName(widget.entry.name);
  late MealType _meal = widget.entry.mealType;
  late final _name = TextEditingController(text: widget.entry.name);
  late final _grams = TextEditingController(text: _baseGrams?.round().toString() ?? '');

  double _factor = 1;
  bool _gramsValid = true;

  static final _portions = <double, String>{0.5: '½×', 1: 'Same', 1.5: '1½×', 2: '2×'};

  @override
  void dispose() {
    _name.dispose();
    _grams.dispose();
    super.dispose();
  }

  FoodEntry get _scaled => _factor == 1 ? _base : _base.scaled(_factor);

  void _onGrams(String text) {
    final grams = parseGrams(text);
    final base = _baseGrams;
    setState(() {
      _gramsValid = grams != null;
      if (grams == null || base == null) return;
      _factor = grams / base;
      // Keep the "(150g)" in the name in step, unless they rewrote the name.
      if (gramsInName(_name.text) != null) _name.text = nameWithGrams(_name.text, grams);
    });
  }

  Future<void> _changeFood() async {
    final pick = widget.pickFood ?? _searchForFood;
    final picked = await pick(context, _meal);
    if (picked == null || !mounted) return;
    setState(() {
      // The new food's numbers, on the original entry's id, source and time.
      _base = widget.entry.copyWith(
        name: picked.name,
        calories: picked.calories,
        proteinG: picked.proteinG,
        carbsG: picked.carbsG,
        fatG: picked.fatG,
        nutrients: picked.nutrients,
        clearNutrients: picked.nutrients == null,
      );
      _baseGrams = gramsInName(picked.name);
      _factor = 1;
      _gramsValid = true;
      _name.text = picked.name;
      _grams.text = _baseGrams?.round().toString() ?? '';
    });
  }

  static Future<FoodEntry?> _searchForFood(BuildContext context, MealType meal) => Navigator.of(context).push<FoodEntry>(
        CupertinoPageRoute(builder: (_) => FoodSearchScreen(mealType: meal)),
      );

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty || !_gramsValid) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(_scaled.copyWith(name: name, mealType: _meal));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _scaled;
    final canSave = _gramsValid && _name.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Edit entry', style: AppType.title(), textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        _label('Name'),
        AppField(
          key: const ValueKey('edit_name'),
          placeholder: 'What was it?',
          controller: _name,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        _label('Meal'),
        _MealPicker(value: _meal, onChanged: (meal) => setState(() => _meal = meal)),
        const SizedBox(height: AppSpacing.lg),
        _label('How much'),
        if (_baseGrams != null)
          AppField(
            key: const ValueKey('edit_grams'),
            placeholder: 'Amount',
            controller: _grams,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: Text('g', style: AppType.body(color: TrackerColors.textTertiary)),
            onChanged: _onGrams,
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: UnitPills<double>(
              options: _portions,
              value: _factor,
              onChanged: (factor) => setState(() => _factor = factor),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _gramsValid
              ? '${preview.calories} kcal · ${preview.proteinG.round()}g protein · '
                  '${preview.carbsG.round()}g carbs · ${preview.fatG.round()}g fat'
              : 'Enter an amount between 1 and ${maxPortionGrams.round()} g',
          key: const ValueKey('edit_preview'),
          style: AppType.caption(
            color: _gramsValid ? TrackerColors.accentEndText : TrackerColors.error,
            size: 12.5,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton.glass(
          key: const ValueKey('edit_change_food'),
          label: 'Wrong food? Pick another',
          icon: CupertinoIcons.search,
          height: 48,
          onPressed: _changeFood,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton.glass(label: 'Cancel', height: 48, onPressed: () => Navigator.of(context).pop()),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                key: const ValueKey('edit_save'),
                label: 'Save',
                height: 48,
                onPressed: canSave ? _save : null,
              ),
            ),
          ],
        ),
        // Room for the keyboard, so the fields stay visible while typing.
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text.toUpperCase(), style: AppType.sectionLabel()),
      );
}

/// Four equal segments, so the meal names fit a narrow phone (they shrink
/// rather than overflow).
class _MealPicker extends StatelessWidget {
  const _MealPicker({required this.value, required this.onChanged});

  final MealType value;
  final ValueChanged<MealType> onChanged;

  static const _labels = {
    MealType.breakfast: 'Breakfast',
    MealType.lunch: 'Lunch',
    MealType.dinner: 'Dinner',
    MealType.snack: 'Snack',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(TrackerColors.textPrimary, 0.05),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: TrackerColors.border),
      ),
      child: Row(
        children: [
          for (final meal in MealType.values)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(meal),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: AnimatedContainer(
                  duration: AppMotion.quick,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: meal == value ? TrackerColors.calorieGradient : null,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _labels[meal]!,
                      maxLines: 1,
                      style: AppType.caption(
                        color: meal == value ? TrackerColors.onAccent : TrackerColors.textSecondary,
                        size: 12,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
