import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/models/nutrients.dart';
import 'package:calorie_app/providers/food_log_provider.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/edit_entry_sheet.dart';
import 'package:calorie_app/widgets/glass.dart';
import 'package:calorie_app/widgets/meal_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _rice() => FoodEntry(
      id: 'entry-1',
      name: 'Rice, white, cooked (150g)',
      calories: 195,
      proteinG: 4,
      carbsG: 42,
      fatG: 0.4,
      mealType: MealType.lunch,
      source: FoodSource.manual,
      timestamp: DateTime(2026, 11, 14, 12),
      nutrients: const Nutrients({'fiber_g': 0.6, 'iron_mg': 1.8}),
    );

FoodEntry _photo() => FoodEntry(
      id: 'entry-2',
      name: 'Chicken curry',
      calories: 400,
      proteinG: 30,
      carbsG: 20,
      fatG: 22,
      mealType: MealType.dinner,
      source: FoodSource.photo,
      timestamp: DateTime(2026, 11, 14, 19),
    );

Map<String, dynamic> _api(FoodEntry e) => {
      'id': e.id, 'name': e.name, 'calories': e.calories, 'protein_g': e.proteinG, 'carbs_g': e.carbsG,
      'fat_g': e.fatG, 'meal_type': e.mealType.name, 'source': e.source.name,
      'timestamp': e.timestamp.toIso8601String(), 'log_date': '2026-11-14', 'nutrients': e.nutrients?.toJson(),
    };

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('the grams in a name', () {
    test('are read and rewritten', () {
      expect(gramsInName('Rice, white, cooked (150g)'), 150);
      expect(gramsInName('Oats (37.5 g)'), 37.5);
      expect(gramsInName('Chicken curry'), isNull);
      expect(gramsInName('Bar (2 pack)'), isNull);
      expect(nameWithGrams('Rice, white, cooked (150g)', 220), 'Rice, white, cooked (220g)');
    });
  });

  group('saving an edit', () {
    late List<http.Request> patches;
    late List<Future<http.Response> Function(http.Request)> script;
    late StreamController<String?> auth;

    setUp(() {
      UserCache.resetForTest();
      SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
      patches = [];
      script = [];
      auth = StreamController<String?>.broadcast();
    });
    tearDown(() => auth.close());

    Future<FoodLogNotifier> build() async {
      final n = FoodLogNotifier(
        client: MockClient((request) async {
          if (request.method == 'GET') return http.Response(jsonEncode([_api(_rice()), _api(_photo())]), 200);
          patches.add(request);
          return (script.isEmpty ? (_) async => http.Response('{}', 200) : script.removeAt(0))(request);
        }),
        currentUserId: () => 'user-a',
        authToken: () => 'token',
        userIdChanges: auth.stream,
        saveRetryDelays: const [Duration(milliseconds: 5)],
        saveTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(n.dispose);
      await _settle();
      return n;
    }

    test('sends the full corrected entry to PATCH /logs/{id} and shows it', () async {
      final n = await build();
      await n.updateEntry(_rice().scaled(2).copyWith(name: 'Rice (300g)', mealType: MealType.dinner));

      expect(patches.single.method, 'PATCH');
      expect(patches.single.url.path, '/logs/entry-1');
      expect(jsonDecode(patches.single.body), {
        'name': 'Rice (300g)', 'calories': 390, 'protein_g': 8.0, 'carbs_g': 84.0, 'fat_g': 0.8,
        'meal_type': 'dinner', 'nutrients': {'fiber_g': 1.2, 'iron_mg': 3.6},
      });
      final shown = n.state.firstWhere((e) => e.id == 'entry-1');
      expect((shown.calories, shown.mealType, shown.name), (390, MealType.dinner, 'Rice (300g)'));
      expect(n.state, hasLength(2)); // the other entry is untouched

      // And it survives a restart offline: the device cache has the new values.
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(prefs.getKeys().firstWhere((k) => k.startsWith('food_log:user-a:')))!;
      expect(cached.map((s) => (jsonDecode(s) as Map)['calories']), containsAll([390, 400]));
    });

    test('a food with no nutrient data clears the old numbers on the server', () async {
      final n = await build();
      await n.updateEntry(_rice().copyWith(clearNutrients: true));
      final body = jsonDecode(patches.single.body) as Map<String, dynamic>;
      expect(body.containsKey('nutrients'), isTrue);
      expect(body['nutrients'], isNull);
    });

    test('a server hiccup is retried; the same request twice is harmless', () async {
      script = [(_) async => http.Response('boom', 503), (_) async => http.Response('{}', 200)];
      final n = await build();
      await n.updateEntry(_rice().scaled(2));
      expect(patches, hasLength(2));
      expect(patches[0].body, patches[1].body);
    });

    test('a refusal puts the old entry back and reports it', () async {
      script = [(_) async => http.Response('{"detail":"Log not found"}', 404)];
      final n = await build();
      await expectLater(n.updateEntry(_rice().scaled(2)), throwsException);
      expect(patches, hasLength(1)); // a 4xx is not retried
      expect(n.state.firstWhere((e) => e.id == 'entry-1').calories, 195);
    });

    test('an entry that is not in today\'s log is refused without calling the server', () async {
      final n = await build();
      final stranger = FoodEntry(
        id: 'nope', name: 'x', calories: 1, mealType: MealType.snack, source: FoodSource.manual, timestamp: DateTime(2026),
      );
      await expectLater(n.updateEntry(stranger), throwsException);
      expect(patches, isEmpty);
    });
  });

  group('the sheet', () {
    Future<List<FoodEntry?>> open(WidgetTester tester, FoodEntry entry, {FoodEntry? picks}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final results = <FoodEntry?>[];
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('open'),
                onPressed: () async => results.add(await showAppSheet<FoodEntry>(
                  context: context,
                  builder: (_) => AppSheet(child: EditEntrySheet(entry: entry, pickFood: (_, _) async => picks)),
                )),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
      return results;
    }

    String preview(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('edit_preview'))).data!;

    testWidgets('a new amount in grams rescales everything and keeps the name in step', (tester) async {
      final results = await open(tester, _rice());
      expect(preview(tester), '195 kcal · 4g protein · 42g carbs · 0g fat');

      await tester.enterText(find.byKey(const ValueKey('edit_grams')), '300');
      await tester.pump();
      expect(preview(tester), startsWith('390 kcal · 8g protein · 84g carbs'));

      await tester.tap(find.byKey(const ValueKey('edit_save')));
      await settle(tester);
      final saved = results.single!;
      expect((saved.id, saved.name, saved.calories), ('entry-1', 'Rice, white, cooked (300g)', 390));
      expect(saved.nutrients!.amounts, {'fiber_g': 1.2, 'iron_mg': 3.6});
      expect((saved.source, saved.timestamp), (FoodSource.manual, DateTime(2026, 11, 14, 12)));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a bad amount cannot be saved', (tester) async {
      final results = await open(tester, _rice());
      await tester.enterText(find.byKey(const ValueKey('edit_grams')), '0');
      await tester.pump();
      expect(preview(tester), contains('Enter an amount'));
      await tester.tap(find.byKey(const ValueKey('edit_save')), warnIfMissed: false);
      await settle(tester);
      expect(results, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a photo entry (no grams) is resized by portion, renamed and moved to another meal', (tester) async {
      final results = await open(tester, _photo());
      expect(find.byKey(const ValueKey('edit_grams')), findsNothing);

      await tester.tap(find.text('1½×'));
      await tester.pump();
      expect(preview(tester), startsWith('600 kcal · 45g protein'));
      await tester.tap(find.text('½×'));
      await tester.pump();
      expect(preview(tester), startsWith('200 kcal'), reason: 'worked out from the original, not the last tap');

      await tester.enterText(find.byKey(const ValueKey('edit_name')), 'Chicken tikka');
      await tester.tap(find.text('Lunch'));
      await tester.tap(find.byKey(const ValueKey('edit_save')));
      await settle(tester);
      final saved = results.single!;
      expect((saved.name, saved.mealType, saved.calories, saved.source), ('Chicken tikka', MealType.lunch, 200, FoodSource.photo));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('picking another food swaps the numbers but keeps the entry', (tester) async {
      final quinoa = FoodEntry(
        id: 'new-id',
        name: 'Quinoa, cooked (185g)',
        calories: 222,
        proteinG: 8,
        carbsG: 39,
        fatG: 3.6,
        mealType: MealType.snack,
        source: FoodSource.manual,
        timestamp: DateTime(2030),
      );
      final results = await open(tester, _rice(), picks: quinoa);
      await tester.tap(find.byKey(const ValueKey('edit_change_food')));
      await settle(tester);
      expect(preview(tester), startsWith('222 kcal'));

      await tester.tap(find.byKey(const ValueKey('edit_save')));
      await settle(tester);
      final saved = results.single!;
      expect((saved.id, saved.name, saved.calories, saved.mealType), ('entry-1', 'Quinoa, cooked (185g)', 222, MealType.lunch));
      expect(saved.timestamp, DateTime(2026, 11, 14, 12));
      expect(saved.nutrients, isNull, reason: "the old food's nutrients must not stick to the new one");
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('cancel changes nothing', (tester) async {
      final results = await open(tester, _rice());
      await tester.enterText(find.byKey(const ValueKey('edit_grams')), '500');
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(results.single, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('tapping a food row asks to edit it; a past day is read-only', (tester) async {
    final tapped = <String>[];
    Widget section({required bool editable}) => CupertinoApp(
          theme: AppTheme.cupertino,
          home: CupertinoPageScaffold(
            child: Center(
              child: MealSection(
                title: 'lunch',
                entries: [_rice()],
                onPhoto: () {},
                onSearch: () {},
                onRemove: (_) {},
                onEdit: editable ? (e) => tapped.add(e.id) : null,
              ),
            ),
          ),
        );

    await tester.pumpWidget(section(editable: true));
    await tester.tap(find.text('Rice, white, cooked (150g)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tapped, ['entry-1']);

    await tester.pumpWidget(section(editable: false));
    await tester.tap(find.text('Rice, white, cooked (150g)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tapped, ['entry-1']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
