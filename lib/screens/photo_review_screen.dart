import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/detected_food.dart';
import '../models/food_entry.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/empty_state.dart';

class PhotoReviewScreen extends StatefulWidget {
  final List<DetectedFood> items;
  final MealType mealType;

  const PhotoReviewScreen({super.key, required this.items, required this.mealType});

  @override
  State<PhotoReviewScreen> createState() => _PhotoReviewScreenState();
}

class _PhotoReviewScreenState extends State<PhotoReviewScreen> {
  late List<DetectedFood> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _updateGrams(int index, String value) {
    final grams = double.tryParse(value);
    if (grams == null) return;
    setState(() => _items[index].estimatedGrams = grams);
  }

  void _removeItem(int index) {
    HapticFeedback.lightImpact();
    setState(() => _items.removeAt(index));
  }

  void _confirm() {
    final entries = _items
        .map((item) => FoodEntry(
              id: '${DateTime.now().microsecondsSinceEpoch}_${item.name}',
              name: item.name,
              calories: item.estimatedCalories,
              proteinG: item.estimatedProtein,
              carbsG: item.estimatedCarbs,
              fatG: item.estimatedFat,
              mealType: widget.mealType,
              source: FoodSource.photo,
              timestamp: DateTime.now(),
            ))
        .toList();

    HapticFeedback.mediumImpact();
    Navigator.pop(context, entries);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: TrackerColors.navFill,
        border: AppDecor.hairlineTop,
        middle: const Text('Review detected foods'),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: TrackerColors.background),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.info_circle,
                    size: 15,
                    color: TrackerColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These are estimates. Adjust quantity or remove anything that looks wrong before saving.',
                      style: AppType.callout(size: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? const AppEmptyState(
                      icon: CupertinoIcons.trash,
                      title: 'No items left to add',
                      message: 'Go back and scan the photo again.',
                      accent: TrackerColors.textSecondary,
                    )
                  : AnimatedSwitcher(
                      duration: AppMotion.quick,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        key: ValueKey(_items.map((item) => item.name).join('|')),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                              decoration: AppDecor.card(
                                borderRadius: AppRadii.buttonAll,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.body(size: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _GramField(
                                              grams: item.estimatedGrams,
                                              onChanged: (value) => _updateGrams(index, value),
                                            ),
                                            const SizedBox(width: AppSpacing.md),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 9,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: TrackerColors.alpha(
                                                  TrackerColors.accentStart,
                                                  0.14,
                                                ),
                                                borderRadius: BorderRadius.circular(AppRadii.pill),
                                                border: Border.all(
                                                  color: TrackerColors.alpha(
                                                    TrackerColors.accentStart,
                                                    0.28,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                '~${item.estimatedCalories} kcal',
                                                style: AppType.caption(
                                                  color: TrackerColors.accentStart,
                                                  size: 11,
                                                ).copyWith(fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppIconButton(
                                    icon: CupertinoIcons.delete,
                                    size: 34,
                                    iconSize: 15,
                                    color: TrackerColors.error,
                                    background: TrackerColors.alpha(TrackerColors.error, 0.1),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottomInset),
              child: AppButton(
                label: 'Add ${_items.length} item${_items.length == 1 ? '' : 's'}',
                onPressed: _items.isEmpty ? null : _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns its own controller so the gram field does not rebuild on every keystroke.
class _GramField extends StatefulWidget {
  const _GramField({required this.grams, required this.onChanged});

  final double grams;
  final ValueChanged<String> onChanged;

  @override
  State<_GramField> createState() => _GramFieldState();
}

class _GramFieldState extends State<_GramField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.grams.round().toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: CupertinoTextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        placeholderStyle: AppType.body(size: 14, color: TrackerColors.textTertiary),
        style: AppType.body(size: 14),
        cursorColor: TrackerColors.accentStart,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffix: const Padding(
          padding: EdgeInsets.only(right: 10),
          child: Text('g', style: TextStyle(color: TrackerColors.textTertiary, fontSize: 13)),
        ),
        decoration: BoxDecoration(
          color: TrackerColors.surfaceElevated,
          borderRadius: AppRadii.smallAll,
          border: Border.all(color: TrackerColors.border, width: 1),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
