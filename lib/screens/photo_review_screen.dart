import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/detected_food.dart';
import '../models/food_entry.dart';

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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Review detected foods')),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'These are estimates. Adjust quantity or remove anything that looks wrong before saving.',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: ListView.builder(
                key: ValueKey(_items.map((item) => item.name).join('|')),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return CupertinoListTile(
                    title: Text(item.name),
                    subtitle: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: CupertinoTextField(
                            controller: TextEditingController(text: item.estimatedGrams.round().toString()),
                            keyboardType: TextInputType.number,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.tertiarySystemFill,
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            suffix: const Text('g'),
                            onChanged: (v) => _updateGrams(index, v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('~${item.estimatedCalories} kcal'),
                      ],
                    ),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(CupertinoIcons.delete),
                      onPressed: () => _removeItem(index),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              onPressed: _items.isEmpty ? null : _confirm,
              child: Text('Add ${_items.length} item${_items.length == 1 ? '' : 's'}'),
            ),
          ),
        ],
      ),
    );
  }
}