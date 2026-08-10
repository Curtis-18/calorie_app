import 'dart:async';
import 'package:flutter/material.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../services/food_search_service.dart';

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
    final grams = await showDialog<double>(
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search foods...',
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      title: Text(item.description),
                      subtitle: Text('${item.caloriesPer100g?.round()} kcal / 100g'),
                      onTap: () => _selectFood(item),
                    );
                  },
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.food.description),
      content: TextField(
        controller: _gramsController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Quantity (grams)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final grams = double.tryParse(_gramsController.text) ?? 100;
            Navigator.pop(context, grams);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}