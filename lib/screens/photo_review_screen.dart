import 'package:flutter/material.dart';
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

  void _removeItem(int index) => setState(() => _items.removeAt(index));

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

    Navigator.pop(context, entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review detected foods')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'These are estimates. Adjust quantity or remove anything that looks wrong before saving.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          initialValue: item.estimatedGrams.round().toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(suffixText: 'g'),
                          onChanged: (v) => _updateGrams(index, v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('~${item.estimatedCalories} kcal'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeItem(index),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _items.isEmpty ? null : _confirm,
              child: Text('Add ${_items.length} item${_items.length == 1 ? '' : 's'}'),
            ),
          ),
        ],
      ),
    );
  }
}