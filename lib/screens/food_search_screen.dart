import 'dart:async';

import 'package:flutter/cupertino.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../services/food_search_service.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';

class FoodSearchScreen extends StatefulWidget {
  final MealType mealType;

  const FoodSearchScreen({super.key, required this.mealType});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _service = FoodSearchService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<FoodItem> _results = [];
  bool _loading = false;
  String? _error;

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final results = await _service.search(query);
        if (!mounted) return;
        setState(() {
          _results = results;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    });
  }

  void _selectFood(FoodItem item) async {
    final grams = await showCupertinoDialog<double>(
      context: context,
      builder: (context) => _QuantityDialog(food: item),
    );
    if (grams == null || !mounted) return;

    final calories = ((item.caloriesPer100g ?? 0) / 100 * grams).round();
    final protein = (item.proteinPer100g ?? 0) / 100 * grams;
    final carbs = (item.carbsPer100g ?? 0) / 100 * grams;
    final fat = (item.fatPer100g ?? 0) / 100 * grams;

    Navigator.pop(
      context,
      FoodEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: '${item.description} (${grams.round()}g)',
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        mealType: widget.mealType,
        source: FoodSource.manual,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: TrackerColors.navFill,
        border: AppDecor.hairlineTop,
        middle: CupertinoSearchTextField(
          controller: _controller,
          autofocus: true,
          placeholder: 'Search foods…',
          onChanged: _onQueryChanged,
          backgroundColor: TrackerColors.alpha(TrackerColors.textPrimary, 0.07),
          borderRadius: AppRadii.buttonAll,
          itemColor: TrackerColors.textSecondary,
          style: AppType.body(size: 15),
          placeholderStyle: AppType.body(size: 15, color: TrackerColors.textTertiary),
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: TrackerColors.background),
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: const [
                  SkeletonRows(count: 7, thumbnail: false),
                ],
              )
            : _error != null
                ? AppEmptyState(
                    icon: CupertinoIcons.wifi_exclamationmark,
                    title: 'Search failed',
                    message: _error,
                    accent: TrackerColors.error,
                  )
                : _results.isEmpty
                    ? const AppEmptyState(
                        icon: CupertinoIcons.search,
                        title: 'Find a food',
                        message: 'Search thousands of foods to add them to this meal.',
                        accent: TrackerColors.textSecondary,
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Pressable(
                              onTap: () => _selectFood(item),
                              haptics: true,
                              borderRadius: AppRadii.buttonAll,
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                borderRadius: AppRadii.buttonAll,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppType.body(size: 14),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${item.caloriesPer100g?.round() ?? 0} kcal / 100g',
                                            style: AppType.caption(size: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    const Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 15,
                                      color: TrackerColors.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  final FoodItem food;
  const _QuantityDialog({required this.food});

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _gramsController = TextEditingController(text: '100');

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: FrostedGlass(
          blur: 24,
          opacity: 0.97,
          tint: TrackerColors.surface,
          borderRadius: AppRadii.containerAll,
          border: Border.all(color: TrackerColors.borderStrong, width: 1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.food.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline(),
                ),
                const SizedBox(height: AppSpacing.lg),
                CupertinoTextField(
                  controller: _gramsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: 'Quantity (grams)',
                  placeholderStyle: AppType.body(size: 15, color: TrackerColors.textTertiary),
                  style: AppType.body(size: 15),
                  cursorColor: TrackerColors.accentStart,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: TrackerColors.surfaceElevated,
                    borderRadius: AppRadii.buttonAll,
                    border: Border.all(color: TrackerColors.border, width: 1),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.glass(
                        label: 'Cancel',
                        height: 46,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Add',
                        height: 46,
                        onPressed: () {
                          final grams = double.tryParse(_gramsController.text) ?? 100;
                          Navigator.pop(context, grams);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
