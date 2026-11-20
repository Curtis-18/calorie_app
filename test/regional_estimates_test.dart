import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/models/food_item.dart';
import 'package:calorie_app/models/food_region.dart';
import 'package:calorie_app/providers/food_log_provider.dart';
import 'package:calorie_app/providers/food_region_provider.dart';
import 'package:calorie_app/screens/photo_review_screen.dart';
import 'package:calorie_app/screens/settings_screen.dart';
import 'package:calorie_app/services/food_region_service.dart';
import 'package:calorie_app/services/photo_estimation.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/meal_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _estimateJson({String? basis = 'typical jollof rice cooked with oil'}) => {
      'name': 'Jollof rice',
      'estimated_grams': 250,
      'matched': false,
      'source': 'ai_estimate',
      'confidence': 'medium',
      'estimate_basis': basis,
      'calories_per_100g': 150,
      'protein_g_per_100g': 3,
      'carbs_g_per_100g': 27,
      'fat_g_per_100g': 3.5,
    };

DetectedFood _jollof() => DetectedFood.fromApiJson(_estimateJson());

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('an estimated dish from the scan', () {
    test('is treated as matched so it can be edited and saved, and says so', () {
      final f = _jollof();
      expect(f.matched, isTrue);
      expect(f.estimated, isTrue);
      expect(f.estimateBasis, 'typical jollof rice cooked with oil');
      expect(f.estimatedCalories, 375); // 150 per 100 g x 250 g
    });

    test('a missing basis gets a plain default', () {
      expect(DetectedFood.fromApiJson(_estimateJson(basis: null)).estimateBasis, 'A typical value for this dish.');
      expect(DetectedFood.fromApiJson(_estimateJson(basis: '  ')).estimateBasis, 'A typical value for this dish.');
    });

    test('a database match is not an estimate, and an estimate with no numbers is still unmatched', () {
      final usda = DetectedFood.fromApiJson({
        'name': 'Rice', 'estimated_grams': 150, 'matched': true, 'source': 'usda', 'calories_per_100g': 130,
      });
      expect(usda.matched, isTrue);
      expect(usda.estimated, isFalse);
      final empty = DetectedFood.fromApiJson({'name': 'Stew', 'estimated_grams': 200, 'matched': false, 'source': 'ai_estimate'});
      expect(empty.matched, isFalse);
      expect(empty.estimated, isFalse);
      // An older backend sends neither field.
      expect(DetectedFood.fromApiJson({'name': 'Stew', 'estimated_grams': 200, 'matched': false}).estimated, isFalse);
    });

    test('picking a real food clears the estimate', () {
      final f = _jollof();
      f.applyMatch(_riceItem());
      expect(f.estimated, isFalse);
      expect(f.estimateBasis, isNull);
      expect(f.matchedDescription, 'Rice, white, cooked');
    });
  });

  group('an entry that is an estimate', () {
    FoodEntry entry({String? basis = 'typical'}) => FoodEntry(
          id: 'e1', name: 'Jollof rice', calories: 375, mealType: MealType.lunch, source: FoodSource.photo,
          timestamp: DateTime(2026, 11, 20, 12), estimateBasis: basis,
        );

    test('survives the device cache and the server JSON', () {
      expect(FoodEntry.fromJson(entry().toJson()).estimateBasis, 'typical');
      expect(FoodEntry.fromJson(entry(basis: null).toJson()).isEstimate, isFalse);
      final api = {
        'id': 'e1', 'name': 'x', 'calories': 1, 'meal_type': 'lunch', 'source': 'photo',
        'timestamp': '2026-11-20T12:00:00', 'estimate_basis': 'typical',
      };
      expect(FoodEntry.fromApiJson(api).isEstimate, isTrue);
      expect(FoodEntry.fromApiJson({...api}..remove('estimate_basis')).isEstimate, isFalse);
    });

    test('keeps the mark when the portion changes and drops it for a real food', () {
      expect(entry().scaled(2).estimateBasis, 'typical');
      expect(entry().copyWith(calories: 400).estimateBasis, 'typical');
      expect(entry().copyWith(clearEstimate: true).estimateBasis, isNull);
    });
  });

  group('saving', () {
    late List<http.Request> requests;
    setUp(() {
      UserCache.resetForTest();
      SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
      requests = [];
    });

    Future<FoodLogNotifier> build() async {
      final n = FoodLogNotifier(
        client: MockClient((request) async {
          if (request.method == 'GET') return http.Response('[]', 200);
          requests.add(request);
          return http.Response('{}', 200);
        }),
        currentUserId: () => 'user-a',
        authToken: () => 'token',
        userIdChanges: const Stream<String?>.empty(),
        saveRetryDelays: const [Duration(milliseconds: 5)],
        saveTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(n.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return n;
    }

    FoodEntry entry({String? basis}) => FoodEntry(
          id: 'e1', name: 'Jollof rice (250g)', calories: 375, mealType: MealType.lunch, source: FoodSource.photo,
          timestamp: DateTime(2026, 11, 20, 12), estimateBasis: basis,
        );

    test('an estimate is posted with its basis; an ordinary entry sends none', () async {
      final n = await build();
      await n.addEntry(entry(basis: 'typical jollof rice cooked with oil'));
      expect(jsonDecode(requests.single.body)['estimate_basis'], 'typical jollof rice cooked with oil');
      requests.clear();
      await n.addEntry(FoodEntry(
        id: 'e2', name: 'Apple', calories: 80, mealType: MealType.snack, source: FoodSource.manual, timestamp: DateTime(2026, 11, 20, 13),
      ));
      expect(jsonDecode(requests.single.body).containsKey('estimate_basis'), isFalse);
    });

    test('editing always sends the mark (null clears it), so a swapped food stops being an estimate', () async {
      final n = await build();
      await n.addEntry(entry(basis: 'typical'));
      requests.clear();
      await n.updateEntry(entry(basis: 'typical').scaled(2));
      expect(jsonDecode(requests.single.body)['estimate_basis'], 'typical');
      requests.clear();
      await n.updateEntry(entry(basis: 'typical').copyWith(clearEstimate: true));
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body.containsKey('estimate_basis'), isTrue);
      expect(body['estimate_basis'], isNull);
    });
  });

  group('the scan request', () {
    Future<Map<String, dynamic>> sent({String? region}) async {
      late Map<String, dynamic> body;
      final service = PhotoEstimationService(
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('[]', 200);
        }),
        tokenProvider: () async => 't',
      );
      await service.analyzePhoto(const [1, 2, 3], region: region);
      return body;
    }

    test('carries the region as context when there is one, and nothing otherwise', () async {
      expect((await sent(region: 'west_africa'))['region'], 'west_africa');
      expect((await sent()).containsKey('region'), isFalse);
      expect((await sent(region: '')).containsKey('region'), isFalse);
    });
  });

  group('the review row', () {
    Future<List<FoodEntry>?> open(WidgetTester tester, List<DetectedFood> items) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      List<FoodEntry>? result;
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => result = await Navigator.push<List<FoodEntry>>(
              context,
              CupertinoPageRoute(builder: (_) => PhotoReviewScreen(items: items, mealType: MealType.lunch, adjustments: const [])),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);
      addTearDown(() => result);
      return result;
    }

    testWidgets('says Estimated with the basis, counts toward the total, and explains itself when tapped', (tester) async {
      final item = _jollof();
      await open(tester, [item]);
      expect(find.textContaining('Estimated · typical jollof rice cooked with oil'), findsOneWidget);
      expect(find.text('About 375 kcal in total'), findsOneWidget);
      expect(find.textContaining('without nutrition data'), findsNothing);
      await tester.tap(find.byKey(ValueKey('estimated_${identityHashCode(item)}')), warnIfMissed: false);
      await _settle(tester);
    });

    testWidgets('a database match shows no estimate line', (tester) async {
      await open(tester, [DetectedFood(name: 'Rice', estimatedGrams: 150, caloriesPer100g: 130, matched: true, matchedDescription: 'Rice, white, cooked')]);
      expect(find.textContaining('Estimated'), findsNothing);
      expect(find.textContaining('Matched: Rice, white, cooked'), findsOneWidget);
    });

    testWidgets('saving keeps the estimate and its basis; a matched food saves none', (tester) async {
      List<FoodEntry>? saved;
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => saved = await Navigator.push<List<FoodEntry>>(
              context,
              CupertinoPageRoute(
                builder: (_) => PhotoReviewScreen(
                  items: [_jollof(), DetectedFood(name: 'Rice', estimatedGrams: 150, caloriesPer100g: 130, matched: true)],
                  mealType: MealType.lunch,
                  adjustments: const [],
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.tap(find.text('Add 2 items'));
      await _settle(tester);
      expect(saved!.map((e) => e.estimateBasis), ['typical jollof rice cooked with oil', null]);
      expect(saved!.first.calories, 375);
      expect(saved!.first.source, FoodSource.photo);
    });
  });

  testWidgets('a logged estimate is marked in the meal list', (tester) async {
    FoodEntry e(String id, String? basis) => FoodEntry(
          id: id, name: 'Dish $id', calories: 300, mealType: MealType.lunch, source: FoodSource.photo,
          timestamp: DateTime(2026, 11, 20, 12), estimateBasis: basis,
        );
    await tester.pumpWidget(CupertinoApp(
      theme: AppTheme.cupertino,
      home: CupertinoPageScaffold(
        child: Center(child: MealSection(title: 'lunch', entries: [e('a', 'typical'), e('b', null)], onPhoto: () {}, onSearch: () {}, onRemove: (_) {})),
      ),
    ));
    expect(find.byKey(const ValueKey('estimated_entry_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('estimated_entry_b')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('where you mostly eat', () {
    test('the regions match the backend keys', () {
      expect(foodRegions.map((r) => r.key), [
        'north_america', 'latin_america', 'europe', 'west_africa', 'east_africa', 'southern_africa',
        'north_africa_middle_east', 'south_asia', 'east_asia', 'southeast_asia', 'oceania', 'other',
      ]);
      expect(foodRegionLabel('west_africa'), 'West Africa');
      expect(foodRegionLabel(null), isNull);
      expect(foodRegionLabel('narnia'), isNull);
    });

    late StreamController<String?> auth;
    late List<http.Request> calls;
    late String? serverRegion;
    late bool serverUp;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      auth = StreamController<String?>.broadcast();
      calls = [];
      serverRegion = null;
      serverUp = true;
    });
    tearDown(() => auth.close());

    FoodRegionNotifier build({String? user = 'user-a'}) {
      final n = FoodRegionNotifier(
        service: FoodRegionService(
          client: MockClient((request) async {
            calls.add(request);
            if (!serverUp) return http.Response('no', 503);
            if (request.method == 'POST') {
              serverRegion = (jsonDecode(request.body) as Map)['region'] as String?;
            }
            return http.Response(jsonEncode({'region': serverRegion, 'regions': []}), 200);
          }),
          tokenProvider: () => 'token',
        ),
        currentUserId: () => user,
        userIdChanges: auth.stream,
      );
      addTearDown(() {
        if (n.mounted) n.dispose();
      });
      return n;
    }

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

    test('is loaded from the server, remembered per person, and cleared on sign-out', () async {
      serverRegion = 'east_africa';
      final n = build();
      await settle();
      expect(n.state, 'east_africa');
      expect((await SharedPreferences.getInstance()).getString('food_region:user-a'), 'east_africa');
      auth.add(null);
      await settle();
      expect(n.state, isNull);
    });

    test('a remembered choice is used straight away, even before the server answers', () async {
      SharedPreferences.setMockInitialValues({'food_region:user-a': 'south_asia'});
      serverUp = false;
      final n = build();
      await settle();
      expect(n.state, 'south_asia'); // the server failed: the remembered value stays
    });

    test('choosing saves to the server first; a failure changes nothing', () async {
      final n = build();
      await settle();
      expect(await n.set('west_africa'), isNull);
      expect(n.state, 'west_africa');
      expect(serverRegion, 'west_africa');
      serverUp = false;
      expect(await n.set('europe'), isNotNull);
      expect(n.state, 'west_africa');
      serverUp = true;
      expect(await n.set(null), isNull);
      expect(n.state, isNull);
      expect((await SharedPreferences.getInstance()).getString('food_region:user-a'), isNull);
    });

    testWidgets('Settings shows it and lets the person change it', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final n = build();
      await tester.runAsync(settle);
      final container = ProviderContainer(overrides: [foodRegionProvider.overrideWith((ref) => n)]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(theme: AppTheme.cupertino, home: const SettingsView(profile: null)),
      ));
      await _settle(tester);
      final row = find.byKey(const ValueKey('food_region'));
      await tester.ensureVisible(row);
      await _settle(tester);
      expect(find.descendant(of: row, matching: find.text('Not set')), findsOneWidget);
      await tester.tap(row);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('region_west_africa')));
      await tester.pump();
      await tester.runAsync(settle);
      await _settle(tester);
      expect(n.state, 'west_africa');
      expect(find.descendant(of: find.byKey(const ValueKey('food_region')), matching: find.text('West Africa')), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}

FoodItem _riceItem() => FoodItem(fdcId: 7, description: 'Rice, white, cooked', caloriesPer100g: 130);
