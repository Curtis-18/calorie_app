import 'dart:convert';

import 'package:calorie_app/models/adjustment.dart';
import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/screens/photo_review_screen.dart';
import 'package:calorie_app/services/adjustments_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Adjustment _oil() => const Adjustment(
      id: 'oil', isScale: false, label: '+ Cooking oil', entryName: 'Cooking oil, 1 tbsp (added)', grams: 14,
      caloriesPer100g: 860, fatPer100g: 100, preparations: ['fried', 'sauteed'],
    );
Adjustment _dressing() => const Adjustment(
      id: 'dressing', isScale: false, label: '+ Creamy dressing', entryName: 'Creamy dressing (added)', grams: 30,
      caloriesPer100g: 430, kinds: ['salad'],
    );
Adjustment _restaurant() => const Adjustment(id: 'restaurant', isScale: true, label: 'Restaurant portion', factor: 1.25, always: true);

DetectedFood _fish({String? prep = 'fried', String? kind = 'main'}) => DetectedFood(
      name: 'Fish', estimatedGrams: 100, caloriesPer100g: 200, matched: true, preparation: prep, kind: kind,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('which extras apply', () {
    test('oil for a fried food, not for fruit; the restaurant scale always', () {
      final fruit = [DetectedFood(name: 'Apple', estimatedGrams: 100, preparation: 'raw', kind: 'fruit')];
      expect(_oil().appliesTo([_fish()]), isTrue);
      expect(_oil().appliesTo(fruit), isFalse);
      expect(_restaurant().appliesTo(fruit), isTrue);
    });
    test('dressing follows the kind, and an old server with no hints offers only the scale', () {
      expect(_dressing().appliesTo([_fish(prep: null, kind: 'salad')]), isTrue);
      final old = [DetectedFood(name: 'Fish', estimatedGrams: 100)];
      expect(_oil().appliesTo(old), isFalse);
      expect(_dressing().appliesTo(old), isFalse);
      expect(_restaurant().appliesTo(old), isTrue);
    });
    test('a food added by an extra does not make more extras appear', () {
      expect(_oil().appliesTo([_oil().toFood()]), isFalse);
    });
    test('an add extra with no numbers is ignored', () {
      expect(Adjustment.fromJson({'id': 'x', 'kind': 'add', 'label': 'x'}), isNull);
      expect(Adjustment.fromJson('junk'), isNull);
    });
  });

  group('the service', () {
    setUp(AdjustmentsService.forgetForTest);

    Map<String, dynamic> add(String id) => {'id': id, 'kind': 'add', 'label': id, 'entry_name': id, 'grams': 10, 'calories_per_100g': 500};

    test('parses the server list and remembers a complete one', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode([add('a'), add('b'), add('c'), {'id': 'restaurant', 'kind': 'scale', 'label': 'R', 'factor': 1.25, 'always': true}]), 200);
      });
      final service = AdjustmentsService(client: client, tokenProvider: () async => 't');
      expect((await service.fetch()), hasLength(4));
      await service.fetch();
      expect(calls, 1);
    });

    test('an incomplete answer is used but asked again next time', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode([add('a')]), 200);
      });
      final service = AdjustmentsService(client: client, tokenProvider: () async => 't');
      expect(await service.fetch(), hasLength(1));
      await service.fetch();
      expect(calls, 2);
    });

    test('failures give no extras instead of an error', () async {
      expect(await AdjustmentsService(client: MockClient((_) async => http.Response('x', 500)), tokenProvider: () async => 't').fetch(), isEmpty);
      expect(await AdjustmentsService(client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () async => 't').fetch(), isEmpty);
      expect(await AdjustmentsService(client: MockClient((_) async => http.Response('[]', 200)), tokenProvider: () async => null).fetch(), isEmpty);
    });
  });

  group('the review screen', () {
    Future<List<FoodEntry>?> open(WidgetTester tester, List<DetectedFood> items, List<Adjustment> extras) async {
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
              CupertinoPageRoute(builder: (_) => PhotoReviewScreen(items: items, mealType: MealType.dinner, adjustments: extras)),
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

    testWidgets('only the extras that fit are shown', (tester) async {
      await open(tester, [_fish()], [_oil(), _dressing(), _restaurant()]);
      expect(find.byKey(const ValueKey('extra_oil')), findsOneWidget);
      expect(find.byKey(const ValueKey('extra_dressing')), findsNothing);
      expect(find.byKey(const ValueKey('extra_restaurant')), findsOneWidget);
    });

    testWidgets('no extras section when there is nothing to offer', (tester) async {
      await open(tester, [_fish()], []);
      expect(find.text('Anything the camera can’t see?'), findsNothing);
    });

    testWidgets('tapping oil adds it to the total, tapping again takes it away', (tester) async {
      await open(tester, [_fish()], [_oil()]);
      expect(find.text('About 200 kcal in total'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('extra_oil')));
      await _settle(tester);
      expect(find.text('About 320 kcal in total'), findsOneWidget); // 200 + 14 g x 8.6
      expect(find.text('✓ Cooking oil'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('extra_oil')));
      await _settle(tester);
      expect(find.text('About 200 kcal in total'), findsOneWidget);
    });

    testWidgets('deleting the added oil row switches its chip back off', (tester) async {
      await open(tester, [_fish()], [_oil()]);
      await tester.tap(find.byKey(const ValueKey('extra_oil')));
      await _settle(tester);
      // The added food is the second row; delete it with its trash button.
      await tester.tap(find.byIcon(CupertinoIcons.delete).last);
      await _settle(tester);
      expect(find.text('+ Cooking oil'), findsOneWidget);
      expect(find.text('About 200 kcal in total'), findsOneWidget);
    });

    testWidgets('restaurant portion scales the photographed foods and undoes cleanly', (tester) async {
      await open(tester, [_fish()], [_restaurant()]);
      await tester.tap(find.byKey(const ValueKey('extra_restaurant')));
      await _settle(tester);
      expect(find.text('About 250 kcal in total'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('extra_restaurant')));
      await _settle(tester);
      expect(find.text('About 200 kcal in total'), findsOneWidget);
    });

    testWidgets('the added oil is saved as its own entry', (tester) async {
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
              CupertinoPageRoute(builder: (_) => PhotoReviewScreen(items: [_fish()], mealType: MealType.dinner, adjustments: [_oil()])),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('extra_oil')));
      await _settle(tester);
      await tester.tap(find.text('Add 2 items'));
      await _settle(tester);
      expect(saved!.map((e) => e.name), ['Fish', 'Cooking oil, 1 tbsp (added)']);
      expect(saved![1].calories, 120);
      expect(saved![1].source, FoodSource.photo);
    });
  });
}
