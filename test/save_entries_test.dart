import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/services/save_entries.dart';
import 'package:flutter_test/flutter_test.dart';

FoodEntry entry(String id, String name) => FoodEntry(
      id: id,
      name: name,
      calories: 100,
      proteinG: 1,
      carbsG: 1,
      fatG: 1,
      mealType: MealType.lunch,
      source: FoodSource.photo,
      timestamp: DateTime(2026, 11, 22, 12),
    );

void main() {
  group('saving a scanned meal item by item', () {
    test('all saved: nothing failed, every item was tried once', () async {
      final tried = <String>[];
      final failed = await saveEntriesIndependently([entry('1', 'Rice'), entry('2', 'Chicken')], (e) async => tried.add(e.id));
      expect(failed, isEmpty);
      expect(tried, ['1', '2']);
    });

    test('one refused item does not stop or undo the others, and only it is reported', () async {
      final saved = <String>[];
      final failed = await saveEntriesIndependently(
        [entry('1', 'Rice'), entry('2', 'Lean beef'), entry('3', 'Salad'), entry('4', 'Bread')],
        (e) async {
          if (e.id == '2') throw Exception('422');
          saved.add(e.id);
        },
      );
      expect(saved, ['1', '3', '4']);
      expect(failed.map((e) => e.name), ['Lean beef']);
    });

    test('everything refused: all are reported, in order, and no error escapes', () async {
      final failed = await saveEntriesIndependently(
        [entry('1', 'A'), entry('2', 'B')],
        (e) async => throw StateError('offline'),
      );
      expect(failed.map((e) => e.id), ['1', '2']);
    });

    test('a failure that arrives late still keeps the original order', () async {
      final failed = await saveEntriesIndependently([entry('1', 'A'), entry('2', 'B'), entry('3', 'C')], (e) async {
        await Future<void>.delayed(Duration(milliseconds: e.id == '1' ? 30 : 1));
        if (e.id != '2') throw Exception('x');
      });
      expect(failed.map((e) => e.id), ['1', '3']);
    });

    test('an empty meal saves nothing and fails nothing', () async {
      expect(await saveEntriesIndependently([], (e) async => fail('never called')), isEmpty);
    });
  });

  group('naming the items that were not saved', () {
    test('lists the names', () {
      expect(failedItemNames([entry('1', 'Rice'), entry('2', ' Beef ')]), 'Rice, Beef');
    });

    test('long lists are cut with a count, blank names are skipped', () {
      final many = [for (var i = 1; i <= 6; i++) entry('$i', 'Item $i')];
      expect(failedItemNames(many), 'Item 1, Item 2, Item 3, Item 4 +2');
      expect(failedItemNames([entry('1', '  ')]), '');
      expect(failedItemNames([]), '');
    });
  });
}
