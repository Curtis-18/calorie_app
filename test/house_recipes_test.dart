import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/models/food_item.dart';
import 'package:calorie_app/models/house_recipe.dart';
import 'package:calorie_app/providers/food_log_provider.dart';
import 'package:calorie_app/providers/house_recipes_provider.dart';
import 'package:calorie_app/screens/library_screen.dart';
import 'package:calorie_app/screens/my_recipes_view.dart';
import 'package:calorie_app/screens/new_recipe_screen.dart';
import 'package:calorie_app/services/house_recipe_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/meal_section.dart';
import 'package:calorie_app/widgets/pressable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> recipeJson({String id = '11111111-1111-4111-8111-111111111111', String title = 'Chicken rice', int kcal = 600, bool estimated = false}) => {
      'id': id,
      'title': title,
      'servings': 2,
      'calories_per_serving': kcal,
      'protein_g': 40,
      'carbs_g': 60,
      'fat_g': 10,
      'estimated': estimated,
      'nutrients': {'fiber_g': 3.0},
      'ingredients': [
        {'name': 'rice', 'grams': 300, 'is_baseline': false},
        {'name': 'chicken', 'grams': 200},
      ],
    };

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class FakeService extends HouseRecipeService {
  FakeService({this.recipes = const [], this.createResult, this.deleteError});

  List<HouseRecipe>? recipes;
  RecipeSaveResult? createResult;
  String? deleteError;
  final created = <Map<String, Object?>>[];
  final logged = <(String, FoodEntry, double)>[];
  int listCalls = 0;

  @override
  Future<List<HouseRecipe>?> list() async {
    listCalls++;
    return recipes;
  }

  @override
  Future<RecipeSaveResult> create({
    required String id,
    required String title,
    required double servings,
    List<DraftIngredient> ingredients = const [],
    Map<String, Object?>? perServing,
  }) async {
    created.add({'id': id, 'title': title, 'servings': servings, 'ingredients': [for (final i in ingredients) i.toJson()], 'per_serving': perServing});
    return createResult ?? RecipeSaveResult.ok(HouseRecipe.fromJson(recipeJson(id: id, title: title))!);
  }

  @override
  Future<List<RecipeCollection>?> collections() async => <RecipeCollection>[];

  @override
  Future<List<RecipeBrief>?> highlights() async => <RecipeBrief>[];

  @override
  Future<String?> delete(String id) async => deleteError;

  @override
  Future<void> recordLog(String recipeId, FoodEntry entry, double servings, DateTime day) async {
    logged.add((recipeId, entry, servings));
  }
}

class FakeFoodLog extends FoodLogNotifier {
  FakeFoodLog() : super(currentUserId: () => null, userIdChanges: const Stream.empty());

  final added = <FoodEntry>[];

  @override
  Future<void> addEntry(FoodEntry entry) async {
    added.add(entry);
  }
}

void main() {
  group('models', () {
    test('a recipe is read, and junk is null', () {
      final r = HouseRecipe.fromJson(recipeJson())!;
      expect([r.title, r.calories, r.estimated], ['Chicken rice', 600, false]);
      expect(r.ingredients.map((i) => i.name), ['rice', 'chicken']);
      expect(r.nutrients, isNotNull);
      expect(r.caloriesFor(1.5), 900);
      expect(HouseRecipe.fromJson('x'), isNull);
      expect(HouseRecipe.fromJson({'id': 'a'}), isNull);
    });

    test('a draft sends the USDA id, or the typed values, never both', () {
      expect(const DraftIngredient(name: 'rice', grams: 100, fdcId: 5, caloriesPer100g: 130).toJson(), {'name': 'rice', 'grams': 100.0, 'fdc_id': 5});
      final typed = const DraftIngredient(name: 'paste', grams: 20, caloriesPer100g: 200, fatPer100g: 10, isBaseline: true).toJson();
      expect(typed['per_100g'], {'calories': 200.0, 'protein_g': 0.0, 'carbs_g': 0.0, 'fat_g': 10.0});
      expect(typed['is_baseline'], true);
      expect(typed.containsKey('fdc_id'), false);
    });

    test('the preview adds up, and says nothing when a value is missing', () {
      expect(previewCaloriesPerServing([const DraftIngredient(name: 'a', grams: 200, caloriesPer100g: 100), const DraftIngredient(name: 'b', grams: 100, caloriesPer100g: 50)], 2), 125);
      expect(previewCaloriesPerServing([const DraftIngredient(name: 'a', grams: 200)], 1), isNull);
      expect(previewCaloriesPerServing([], 1), isNull);
    });

    test('a new id is a version 4 UUID', () {
      final id = newRecipeId();
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue, reason: id);
      expect(newRecipeId() == id, isFalse);
    });
  });

  group('service', () {
    HouseRecipeService svc(http.Response Function(http.Request) reply, [List<http.Request>? seen]) => HouseRecipeService(
          client: MockClient((r) async {
            seen?.add(r);
            return reply(r);
          }),
          tokenProvider: () => 't',
        );

    test('create sends ingredients, and the server decides the numbers', () async {
      final seen = <http.Request>[];
      final s = svc((_) => http.Response(jsonEncode(recipeJson()), 201), seen);
      final res = await s.create(id: 'i', title: 'T', servings: 2, ingredients: [const DraftIngredient(name: 'rice', grams: 100, fdcId: 5)]);
      expect(res.recipe!.title, 'Chicken rice');
      final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
      expect(body['ingredients'], isNotEmpty);
      expect(body.containsKey('per_serving'), isFalse);
    });

    test('create from a meal sends one per-serving estimate and no ingredients', () async {
      final seen = <http.Request>[];
      final s = svc((_) => http.Response(jsonEncode(recipeJson()), 200), seen);
      await s.create(id: 'i', title: 'T', servings: 1, perServing: {'calories': 500});
      final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
      expect(body['per_serving'], {'calories': 500});
      expect(body.containsKey('ingredients'), isFalse);
    });

    test('a refusal says why in plain words', () async {
      expect((await svc((_) => http.Response(jsonEncode({'detail': 'We could not find nutrition for x.'}), 422)).create(id: 'i', title: 'T', servings: 1, perServing: {})).error, contains('could not find'));
      final list = jsonEncode({'detail': [{'msg': 'Value error, Add the ingredients, or enter the calories for one serving.'}]});
      expect((await svc((_) => http.Response(list, 422)).create(id: 'i', title: 'T', servings: 1, perServing: {})).error, startsWith('Add the ingredients'));
      expect((await svc((_) => http.Response('x', 503)).create(id: 'i', title: 'T', servings: 1, perServing: {})).error, contains("aren't available"));
      expect((await svc((_) => http.Response('x', 500)).create(id: 'i', title: 'T', servings: 1, perServing: {})).error, contains("Couldn't save"));
      final offline = HouseRecipeService(client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () => 't');
      expect((await offline.create(id: 'i', title: 'T', servings: 1, perServing: {})).error, contains("Couldn't reach"));
    });

    test('reads never throw; a missing recipe is already deleted', () async {
      expect(await svc((_) => http.Response('x', 500)).list(), isNull);
      expect((await svc((_) => http.Response(jsonEncode([recipeJson(), 'junk']), 200)).list())!.length, 1);
      expect(await svc((_) => http.Response('', 404)).delete('i'), isNull);
      expect(await svc((_) => http.Response('', 204)).delete('i'), isNull);
      expect(await svc((_) => http.Response('', 500)).delete('i'), isNotNull);
      expect(await HouseRecipeService(tokenProvider: () => null).list(), isNull);
    });

    test('recordLog tells the server which recipe the entry came from', () async {
      final seen = <http.Request>[];
      final entry = FoodEntry(id: 'e1', name: 'x', calories: 1, mealType: MealType.lunch, source: FoodSource.manual, timestamp: DateTime(2026, 11, 18, 12));
      await svc((_) => http.Response('{}', 201), seen).recordLog('rid', entry, 1.5, DateTime(2026, 11, 18));
      expect(seen.single.url.path, endsWith('/recipes/rid/log'));
      final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
      expect([body['id'], body['servings'], body['meal_type'], body['log_date']], ['e1', 1.5, 'lunch', '2026-11-18']);
    });
  });

  group('provider', () {
    late StreamController<String?> auth;
    setUp(() => auth = StreamController<String?>.broadcast());
    tearDown(() => auth.close());

    Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 30));

    test('loads, keeps the list when a refresh fails, and clears for the next person', () async {
      final service = FakeService(recipes: [HouseRecipe.fromJson(recipeJson())!]);
      final n = HouseRecipesNotifier(service: service, currentUserId: () => 'u', userIdChanges: auth.stream);
      addTearDown(n.dispose);
      await wait();
      expect(n.state.recipes.length, 1);
      service.recipes = null;
      await n.load();
      expect(n.state.recipes.length, 1);
      expect(n.state.failed, isTrue);
      auth.add(null);
      await wait();
      expect(n.state.recipes, isEmpty);
    });

    test('add and remove', () async {
      final service = FakeService(recipes: []);
      final n = HouseRecipesNotifier(service: service, currentUserId: () => 'u', userIdChanges: auth.stream);
      addTearDown(n.dispose);
      await wait();
      n.add(HouseRecipe.fromJson(recipeJson())!);
      n.add(HouseRecipe.fromJson(recipeJson())!); // the same id replaces, not duplicates
      expect(n.state.recipes.length, 1);
      service.deleteError = 'nope';
      expect(await n.remove(n.state.recipes.first.id), 'nope');
      expect(n.state.recipes.length, 1);
      service.deleteError = null;
      expect(await n.remove(n.state.recipes.first.id), isNull);
      expect(n.state.recipes, isEmpty);
    });
  });

  group('screens', () {
    late FakeService service;
    late FakeFoodLog food;
    late ProviderContainer container;

    Future<void> pump(WidgetTester tester, Widget home, {List<HouseRecipe> recipes = const []}) async {
      tester.view.physicalSize = const Size(750, 2200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      service = FakeService(recipes: recipes);
      food = FakeFoodLog();
      container = ProviderContainer(overrides: [
        houseRecipesProvider.overrideWith((ref) => HouseRecipesNotifier(service: service, currentUserId: () => 'u', userIdChanges: const Stream.empty())),
        foodLogProvider.overrideWith((ref) => food),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: CupertinoApp(theme: AppTheme.cupertino, home: home)));
      await settle(tester);
    }

    // The food log keeps a midnight timer: the notifier must be disposed
    // inside the test, before the framework checks for pending timers.
    void screenTest(String name, Future<void> Function(WidgetTester tester) body) {
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        if (food.mounted) food.dispose();
      });
    }

    screenTest('an empty Mine tab explains itself and offers a new recipe', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()));
      expect(find.text('Your recipes live here'), findsOneWidget);
      expect(find.byKey(const ValueKey('new_recipe')), findsOneWidget);
    });

    screenTest('a failed load can be retried', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()));
      service.recipes = null;
      // The retry button is only shown once a load has failed.
      final container = ProviderScope.containerOf(tester.element(find.byType(MyRecipesView)));
      await container.read(houseRecipesProvider.notifier).load();
      await settle(tester);
      expect(find.text("Couldn't load your recipes"), findsOneWidget);
      service.recipes = [HouseRecipe.fromJson(recipeJson())!];
      await tester.tap(find.byKey(const ValueKey('retry_recipes')));
      await settle(tester);
      expect(find.text('Chicken rice'), findsOneWidget);
    });

    screenTest('the library has a Mine tab that shows my recipes', (tester) async {
      await pump(tester, const LibraryScreen(), recipes: [HouseRecipe.fromJson(recipeJson(estimated: true))!]);
      expect(find.byKey(const ValueKey('my_recipes')), findsNothing);
      await tester.tap(find.text('Mine'));
      await settle(tester);
      expect(find.text('Chicken rice'), findsOneWidget);
      expect(find.text('600 kcal per serving · estimated'), findsOneWidget);
    });

    screenTest('log this: servings and meal are chosen, and the entry is saved then reported', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()), recipes: [HouseRecipe.fromJson(recipeJson())!]);
      await tester.tap(find.text('Chicken rice'));
      await settle(tester);
      expect(find.byKey(const ValueKey('recipe_numbers')), findsOneWidget);
      String numbers() => tester.widget<Text>(find.byKey(const ValueKey('recipe_numbers'))).data!;
      expect(numbers(), startsWith('600 kcal'));
      await tester.tap(find.byKey(const ValueKey('servings_plus')));
      await tester.pump();
      expect(find.text('1.5'), findsOneWidget);
      expect(numbers(), startsWith('900 kcal'));
      await tester.tap(find.byKey(const ValueKey('meal_dinner')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('log_recipe')));
      await settle(tester);
      expect(food.added.single.name, 'Chicken rice');
      expect(food.added.single.calories, 900);
      expect(food.added.single.mealType, MealType.dinner);
      expect(food.added.single.source, FoodSource.manual);
      expect(service.logged.single.$1, '11111111-1111-4111-8111-111111111111');
      expect(service.logged.single.$3, 1.5);
      expect(find.byKey(const ValueKey('log_recipe')), findsNothing); // the sheet closed
    });

    screenTest('servings never go below a half', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()), recipes: [HouseRecipe.fromJson(recipeJson())!]);
      await tester.tap(find.text('Chicken rice'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('servings_minus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('servings_minus')));
      await tester.pump();
      expect(find.text('0.5'), findsOneWidget);
    });

    screenTest('an estimated recipe says so, and delete removes it', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()), recipes: [HouseRecipe.fromJson(recipeJson(estimated: true))!]);
      await tester.tap(find.text('Chicken rice'));
      await settle(tester);
      expect(find.byKey(const ValueKey('recipe_estimated')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('delete_recipe')));
      await settle(tester);
      expect(find.byKey(const ValueKey('log_recipe')), findsNothing);
      expect(find.text('Your recipes live here'), findsOneWidget);
    });

    screenTest('a new recipe can be saved once it has a name and an ingredient', (tester) async {
      await pump(tester, NewRecipeScreen(
        makeId: () => 'new-id',
        pickFood: (_) async => FoodItem(fdcId: 7, description: 'Brown rice', caloriesPer100g: 120, proteinPer100g: 3),
      ));
      Pressable save() => tester.widget<Pressable>(find.descendant(of: find.byKey(const ValueKey('save_recipe')), matching: find.byType(Pressable)));
      expect(save().onTap, isNull);
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('recipe_title_field')), matching: find.byType(CupertinoTextField)), 'Rice bowl');
      await tester.tap(find.byKey(const ValueKey('add_ingredient')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('add_search')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('grams_field')), '200');
      await tester.tap(find.byKey(const ValueKey('grams_ok')));
      await settle(tester);
      expect(find.text('Brown rice'), findsOneWidget);
      expect(find.text('About 240 kcal per serving. The exact numbers are worked out when you save.'), findsOneWidget);
      expect(save().onTap, isNotNull);
      await tester.tap(find.byKey(const ValueKey('save_recipe')));
      await settle(tester);
      final sent = service.created.single;
      expect(sent['id'], 'new-id');
      expect(sent['title'], 'Rice bowl');
      expect((sent['ingredients'] as List).single, {'name': 'Brown rice', 'grams': 200.0, 'fdc_id': 7});
      expect(sent['per_serving'], isNull);
      expect(find.byKey(const ValueKey('save_recipe')), findsNothing); // went back
    });

    screenTest('an Open Food Facts product (no USDA id) is sent with its own numbers, not as id 0', (tester) async {
      await pump(tester, NewRecipeScreen(
        makeId: () => 'off-id',
        pickFood: (_) async => FoodItem(fdcId: 0, description: 'Hazelnut spread', dataType: 'Open Food Facts', caloriesPer100g: 539, proteinPer100g: 6.3, carbsPer100g: 57.5, fatPer100g: 30.9),
      ));
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('recipe_title_field')), matching: find.byType(CupertinoTextField)), 'Toast');
      await tester.tap(find.byKey(const ValueKey('add_ingredient')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('add_search')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('grams_field')), '20');
      await tester.tap(find.byKey(const ValueKey('grams_ok')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('save_recipe')));
      await settle(tester);
      final ing = (service.created.single['ingredients'] as List).single as Map;
      expect(ing.containsKey('fdc_id'), isFalse);
      expect(ing['per_100g'], containsPair('calories', 539.0));
    });

    screenTest('an ingredient the person types is marked, and sent with its numbers', (tester) async {
      await pump(tester, NewRecipeScreen(makeId: () => 'id'));
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('recipe_title_field')), matching: find.byType(CupertinoTextField)), 'Curry');
      await tester.tap(find.byKey(const ValueKey('add_ingredient')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('add_typed')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('typed_name')), 'My spice paste');
      await tester.enterText(find.byKey(const ValueKey('typed_grams')), '30');
      await tester.enterText(find.byKey(const ValueKey('typed_kcal')), '250');
      await tester.tap(find.byKey(const ValueKey('typed_ok')));
      await settle(tester);
      expect(find.text('30 g · typed by you'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save_recipe')));
      await settle(tester);
      final ing = (service.created.single['ingredients'] as List).single as Map;
      expect(ing['per_100g'], containsPair('calories', 250.0));
      expect(ing.containsKey('fdc_id'), isFalse);
    });

    screenTest('an ingredient can be removed, and a refusal is shown in place', (tester) async {
      await pump(tester, NewRecipeScreen(makeId: () => 'id', pickFood: (_) async => FoodItem(fdcId: 7, description: 'Brown rice', caloriesPer100g: 120)));
      service.createResult = const RecipeSaveResult.failed('We couldn’t find nutrition for “Brown rice”.');
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('recipe_title_field')), matching: find.byType(CupertinoTextField)), 'Bowl');
      await tester.tap(find.byKey(const ValueKey('add_ingredient')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('add_search')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('grams_field')), '100');
      await tester.tap(find.byKey(const ValueKey('grams_ok')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('save_recipe')));
      await settle(tester);
      expect(find.byKey(const ValueKey('recipe_error')), findsOneWidget);
      expect(find.textContaining('couldn’t find nutrition'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('remove_ingredient_0')));
      await tester.pump();
      expect(find.byKey(const ValueKey('ingredient_0')), findsNothing);
    });

    screenTest('saving a logged meal as a recipe sends its total as one estimate', (tester) async {
      final meal = [
        FoodEntry(id: 'a', name: 'Eggs', calories: 300, proteinG: 20, carbsG: 2, fatG: 20, mealType: MealType.breakfast, source: FoodSource.manual, timestamp: DateTime(2026, 11, 18, 8)),
        FoodEntry(id: 'b', name: 'Toast', calories: 200, proteinG: 6, carbsG: 30, fatG: 4, mealType: MealType.breakfast, source: FoodSource.photo, timestamp: DateTime(2026, 11, 18, 8)),
      ];
      await pump(tester, NewRecipeScreen(fromMeal: meal, initialTitle: 'Breakfast', makeId: () => 'id'));
      expect(find.byKey(const ValueKey('add_ingredient')), findsNothing);
      expect(find.textContaining('500 kcal in total'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save_recipe')));
      await settle(tester);
      final sent = service.created.single;
      expect(sent['title'], 'Breakfast');
      expect(sent['per_serving'], {'calories': 500, 'protein_g': 26.0, 'carbs_g': 32.0, 'fat_g': 24.0});
      expect(sent['ingredients'], isEmpty);
    });

    screenTest('the meal section offers Save as recipe only for a meal with foods', (tester) async {
      Future<void> show(List<FoodEntry> entries, {VoidCallback? onSave}) => tester.pumpWidget(CupertinoApp(
            theme: AppTheme.cupertino,
            home: CupertinoPageScaffold(
              child: SafeArea(child: MealSection(title: 'lunch', entries: entries, onPhoto: () {}, onSearch: () {}, onRemove: (_) {}, onSaveRecipe: onSave)),
            ),
          ));
      var saved = 0;
      final entry = FoodEntry(id: 'a', name: 'Eggs', calories: 300, mealType: MealType.lunch, source: FoodSource.manual, timestamp: DateTime(2026, 11, 18, 12));
      await show([], onSave: () => saved++);
      expect(find.byKey(const ValueKey('meal_save_recipe_lunch')), findsNothing);
      await show([entry]);
      expect(find.byKey(const ValueKey('meal_save_recipe_lunch')), findsNothing); // a past day
      await show([entry], onSave: () => saved++);
      await tester.tap(find.byKey(const ValueKey('meal_save_recipe_lunch')));
      expect(saved, 1);
    });
  });
}
