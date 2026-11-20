import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/models/house_recipe.dart';
import 'package:calorie_app/providers/house_recipes_provider.dart';
import 'package:calorie_app/providers/recipe_photo_picker.dart';
import 'package:calorie_app/screens/my_recipes_view.dart';
import 'package:calorie_app/screens/new_recipe_screen.dart';
import 'package:calorie_app/services/house_recipe_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/recipe_access.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const rid = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> recipeJson({
  String id = rid,
  String title = 'Chicken rice',
  bool mine = true,
  String visibility = 'private',
  String? cover,
  List<Map<String, dynamic>> media = const [],
  bool estimated = false,
}) =>
    {
      'id': id,
      'title': title,
      'servings': 2,
      'calories_per_serving': 600,
      'protein_g': 40,
      'carbs_g': 60,
      'fat_g': 10,
      'estimated': estimated,
      'mine': mine,
      'owner_name': mine ? null : 'sam',
      'visibility': visibility,
      'cover_url': cover,
      'media': media,
      'ingredients': [
        {'name': 'rice', 'grams': 300, 'fdc_id': 5, 'calories_per_100g': 130, 'protein_g_per_100g': 2.7, 'carbs_g_per_100g': 28, 'fat_g_per_100g': 0.3},
        {'name': 'my paste', 'grams': 20, 'fdc_id': null, 'calories_per_100g': 200, 'protein_g_per_100g': 1, 'carbs_g_per_100g': 10, 'fat_g_per_100g': 15},
      ],
    };

HouseRecipe recipe([Map<String, dynamic>? json]) => HouseRecipe.fromJson(json ?? recipeJson())!;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class FakeService extends HouseRecipeService {
  FakeService({List<HouseRecipe>? recipes}) : recipes = recipes ?? [recipe()];

  List<HouseRecipe> recipes;
  final byId = <String, HouseRecipe>{};
  final calls = <String>[];
  final updates = <Map<String, Object?>>[];
  final created = <Map<String, Object?>>[];
  String? error; // returned by every write while set
  List<RecipeSharee>? sharees = const [];
  List<RecipeBrief>? friendList = const [];

  @override
  Future<List<HouseRecipe>?> list() async => recipes;

  @override
  Future<List<RecipeCollection>?> collections() async => <RecipeCollection>[];

  @override
  Future<List<RecipeBrief>?> highlights() async => <RecipeBrief>[];

  @override
  Future<HouseRecipe?> get(String id) async => byId[id] ?? recipes.where((r) => r.id == id).firstOrNull;

  @override
  Future<String?> setVisibility(String recipeId, String visibility) async {
    calls.add('visibility:$visibility');
    if (error != null) return error;
    byId[recipeId] = recipe(recipeJson(visibility: visibility));
    return null;
  }

  @override
  Future<String?> putPhoto(String recipeId, int position, List<int> jpeg, {String? caption}) async {
    calls.add('put:$position:${jpeg.length}');
    if (error != null) return error;
    byId[recipeId] = recipe(recipeJson(cover: position == 0 ? 'https://x/c.jpg' : null));
    return null;
  }

  @override
  Future<String?> deletePhoto(String recipeId, int position) async {
    calls.add('delete:$position');
    if (error != null) return error;
    byId[recipeId] = recipe(recipeJson());
    return null;
  }

  @override
  Future<String?> report(String recipeId, {String? reason}) async {
    calls.add('report');
    return error;
  }

  @override
  Future<List<RecipeSharee>?> sharedWith(String recipeId) async => sharees;

  @override
  Future<String?> unshare(String recipeId, String friendId) async {
    calls.add('unshare:$friendId');
    return error;
  }

  @override
  Future<List<RecipeBrief>?> friendHighlights(String friendId) async => friendList;

  @override
  Future<RecipeSaveResult> update(String id, {String? title, double? servings, List<DraftIngredient>? ingredients}) async {
    updates.add({'title': title, 'servings': servings, 'ingredients': ingredients == null ? null : [for (final i in ingredients) i.toJson()]});
    return RecipeSaveResult.ok(recipe(recipeJson(title: title ?? 'Chicken rice')));
  }

  @override
  Future<RecipeSaveResult> create({
    required String id,
    required String title,
    required double servings,
    List<DraftIngredient> ingredients = const [],
    Map<String, Object?>? perServing,
  }) async {
    created.add({'id': id, 'title': title, 'ingredients': [for (final i in ingredients) i.toJson()]});
    return RecipeSaveResult.ok(recipe(recipeJson(id: id, title: title)));
  }
}

void main() {
  group('models', () {
    test('a recipe carries its visibility, cover and slides; the cover comes first', () {
      final r = recipe(recipeJson(visibility: 'friends', cover: 'https://x/c.jpg', media: [
        {'position': 1, 'url': 'https://x/1.jpg', 'caption': 'Ingredients'},
        {'position': 2, 'url': 'https://x/2.jpg', 'caption': null},
        {'position': 'bad'},
      ]));
      expect(r.sharedWithFriends, isTrue);
      expect(r.gallery.map((p) => p.position), [0, 1, 2]);
      expect(r.gallery[1].caption, 'Ingredients');
      expect(recipe().sharedWithFriends, isFalse);
      expect(recipe().gallery, isEmpty);
      expect(recipe(recipeJson(visibility: 'public')).visibility, 'private'); // anything unknown is private
    });

    test('an ingredient keeps what is needed to edit it: a USDA id, or the typed values', () {
      final ing = recipe().ingredients;
      expect(ing[0].toDraft().toJson(), {'name': 'rice', 'grams': 300.0, 'fdc_id': 5});
      final typed = ing[1].toDraft().toJson();
      expect(typed.containsKey('fdc_id'), isFalse);
      expect(typed['per_100g'], {'calories': 200.0, 'protein_g': 1.0, 'carbs_g': 10.0, 'fat_g': 15.0});
    });

    test('lists and shares are read, and junk is skipped', () {
      expect(RecipeBrief.fromJson({'id': 'a', 'title': 'T', 'calories_per_serving': 1, 'cover_url': 'u'})!.coverUrl, 'u');
      expect(RecipeSharee.fromJson({'friend_id': 'f', 'username': 'sam', 'avatar_url': null})!.username, 'sam');
      expect(RecipeSharee.fromJson('x'), isNull);
      expect(RecipePhoto.fromJson({'position': 1}), isNull);
    });
  });

  group('service', () {
    HouseRecipeService svc(http.Response Function(http.Request) reply, List<http.Request> seen) => HouseRecipeService(
          client: MockClient((r) async {
            seen.add(r);
            return reply(r);
          }),
          tokenProvider: () => 't',
        );

    test('visibility is a PATCH with just that field', () async {
      final seen = <http.Request>[];
      expect(await svc((_) => http.Response('{}', 200), seen).setVisibility('r1', 'friends'), isNull);
      expect(seen.single.method, 'PATCH');
      expect(seen.single.url.path, endsWith('/recipes/r1'));
      expect(jsonDecode(seen.single.body), {'visibility': 'friends'});
    });

    test('a photo goes to its position as base64, with an optional caption', () async {
      final seen = <http.Request>[];
      expect(await svc((_) => http.Response('{}', 200), seen).putPhoto('r1', 2, [1, 2, 3], caption: ' Step '), isNull);
      expect(seen.single.method, 'PUT');
      expect(seen.single.url.path, endsWith('/recipes/r1/media/2'));
      expect(jsonDecode(seen.single.body), {'image': base64Encode([1, 2, 3]), 'caption': 'Step'});
      seen.clear();
      await svc((_) => http.Response('{}', 200), seen).putPhoto('r1', 0, [9]);
      expect((jsonDecode(seen.single.body) as Map).containsKey('caption'), isFalse);
    });

    test('photo failures are explained', () async {
      final seen = <http.Request>[];
      expect(await svc((_) => http.Response('x', 415), seen).putPhoto('r', 0, [1]), contains("can't be used"));
      expect(await svc((_) => http.Response('x', 413), seen).putPhoto('r', 0, [1]), contains('too large'));
      expect(await svc((_) => http.Response('x', 503), seen).putPhoto('r', 0, [1]), contains("aren't available"));
    });

    test('shares, a friend\'s recipes and a removed photo', () async {
      final seen = <http.Request>[];
      final shares = await svc((_) => http.Response(jsonEncode([{'friend_id': 'f1', 'username': 'sam'}, 'junk']), 200), seen).sharedWith('r1');
      expect(shares!.single.friendId, 'f1');
      expect(seen.single.url.path, endsWith('/recipes/r1/shares'));
      seen.clear();
      final friends = await svc((_) => http.Response(jsonEncode([{'id': 'a', 'title': 'T', 'calories_per_serving': 5}]), 200), seen).friendHighlights('f1');
      expect(friends!.single.title, 'T');
      expect(seen.single.url.path, endsWith('/users/f1/highlights'));
      expect(await svc((_) => http.Response('x', 404), []).friendHighlights('f1'), isNull);
      seen.clear();
      await svc((_) => http.Response('', 204), seen).deletePhoto('r1', 3);
      expect([seen.single.method, seen.single.url.path.endsWith('/recipes/r1/media/3')], ['DELETE', true]);
    });

    test('an edit sends only what changed', () async {
      final seen = <http.Request>[];
      final s = svc((_) => http.Response(jsonEncode(recipeJson()), 200), seen);
      await s.update('r1', title: 'New', servings: 3);
      expect(jsonDecode(seen.single.body), {'title': 'New', 'servings': 3.0});
      seen.clear();
      await s.update('r1', ingredients: [const DraftIngredient(name: 'rice', grams: 100, fdcId: 5)]);
      expect((jsonDecode(seen.single.body) as Map)['ingredients'], hasLength(1));
      expect(await svc((_) => http.Response(jsonEncode({'detail': 'We could not find nutrition for x.'}), 422), []).update('r1', title: 'T').then((r) => r.error), contains('find nutrition'));
    });
  });

  group('screens', () {
    late FakeService service;
    late ProviderContainer container;
    Uint8List? picked;

    Future<void> pump(WidgetTester tester, Widget home, {FakeService? svc}) async {
      tester.view.physicalSize = const Size(750, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      service = svc ?? FakeService();
      picked = Uint8List.fromList([1, 2, 3, 4]);
      container = ProviderContainer(overrides: [
        houseRecipesProvider.overrideWith((ref) => HouseRecipesNotifier(service: service, currentUserId: () => 'u', userIdChanges: const Stream.empty())),
        recipePhotoPickerProvider.overrideWithValue((source) async => picked),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: CupertinoApp(theme: AppTheme.cupertino, home: home)));
      await settle(tester);
    }

    void screenTest(String name, Future<void> Function(WidgetTester tester) body) {
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      });
    }

    Future<void> openRecipe(WidgetTester tester) async {
      await tester.tap(find.text('Chicken rice'));
      await settle(tester);
    }

    const mine = CupertinoPageScaffold(child: MyRecipesView());

    screenTest('a recipe with photos swipes through them, cover first; one without shows none', (tester) async {
      await pump(tester, mine, svc: FakeService(recipes: [
        recipe(recipeJson(cover: 'https://x/c.jpg', media: [{'position': 1, 'url': 'https://x/1.jpg', 'caption': 'Steps'}])),
      ]));
      expect(find.byKey(const ValueKey('cover_$rid')), findsOneWidget); // thumbnail on the list
      await openRecipe(tester);
      expect(find.byKey(const ValueKey('recipe_gallery')), findsOneWidget);
      expect(find.byKey(const ValueKey('gallery_photo_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('gallery_dots')), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('recipe_gallery')), const Offset(-600, 0));
      await settle(tester);
      expect(find.byKey(const ValueKey('gallery_photo_1')), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
    });

    screenTest('no photos, no gallery and no thumbnail', (tester) async {
      await pump(tester, mine);
      expect(find.byKey(const ValueKey('cover_$rid')), findsNothing);
      await openRecipe(tester);
      expect(find.byKey(const ValueKey('recipe_gallery')), findsNothing);
    });

    screenTest('the owner can let friends open a recipe, in plain words, and switch it back', (tester) async {
      await pump(tester, mine);
      await openRecipe(tester);
      String note() => tester.widget<Text>(find.byKey(const ValueKey('visibility_note'))).data!;
      expect(note(), 'Only you, and friends you send it to.');
      await tester.tap(find.byKey(const ValueKey('visibility_switch')));
      await settle(tester);
      expect(service.calls, ['visibility:friends']);
      expect(note(), 'Friends can open and log this. Nobody else can.');
      await tester.tap(find.byKey(const ValueKey('visibility_switch')));
      await settle(tester);
      expect(service.calls.last, 'visibility:private');
      expect(note(), 'Only you, and friends you send it to.');
    });

    screenTest('if changing visibility fails, it says so and the switch stays put', (tester) async {
      await pump(tester, mine);
      service.error = 'Recipes aren\'t available right now. Please try again later.';
      await openRecipe(tester);
      await tester.tap(find.byKey(const ValueKey('visibility_switch')));
      await settle(tester);
      expect(find.text('Couldn\'t change that'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey('visibility_switch'))).value, isFalse);
    });

    screenTest('someone else\'s recipe has no owner controls, and can be reported', (tester) async {
      await pump(tester, mine, svc: FakeService(recipes: [recipe(recipeJson(mine: false, visibility: 'friends'))]));
      await openRecipe(tester);
      expect(find.byKey(const ValueKey('visibility_switch')), findsNothing);
      expect(find.byKey(const ValueKey('recipe_photos')), findsNothing);
      expect(find.byKey(const ValueKey('edit_recipe')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('report_recipe')));
      await settle(tester);
      await tester.tap(find.text('Report').last);
      await settle(tester);
      expect(service.calls, ['report']);
      expect(find.text('Thanks for telling us'), findsOneWidget);
    });

    screenTest('adding a cover sends the chosen photo to position 0 and shows it', (tester) async {
      await pump(tester, mine);
      await openRecipe(tester);
      await tester.tap(find.byKey(const ValueKey('recipe_photos')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('photo_slot_0')));
      await settle(tester);
      expect(find.byKey(const ValueKey('photo_remove')), findsNothing); // nothing to remove yet
      await tester.tap(find.byKey(const ValueKey('photo_library')));
      await settle(tester);
      expect(service.calls, ['put:0:4']);
      expect(find.byKey(const ValueKey('gallery_photo_0')), findsOneWidget); // the recipe behind refreshed
    });

    screenTest('backing out of the picker sends nothing; a failed upload says why', (tester) async {
      await pump(tester, mine);
      await openRecipe(tester);
      await tester.tap(find.byKey(const ValueKey('recipe_photos')));
      await settle(tester);
      picked = null;
      await tester.tap(find.byKey(const ValueKey('photo_slot_1')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('photo_camera')));
      await settle(tester);
      expect(service.calls, isEmpty);
      picked = Uint8List.fromList([1]);
      service.error = "That photo can't be used. Try a different one.";
      await tester.tap(find.byKey(const ValueKey('photo_slot_1')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('photo_library')));
      await settle(tester);
      expect(find.text("Couldn't save that photo"), findsOneWidget);
    });

    screenTest('a photo can be removed', (tester) async {
      await pump(tester, mine, svc: FakeService(recipes: [recipe(recipeJson(cover: 'https://x/c.jpg'))]));
      await openRecipe(tester);
      await tester.tap(find.byKey(const ValueKey('recipe_photos')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('photo_slot_0')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('photo_remove')));
      await settle(tester);
      expect(service.calls, ['delete:0']);
    });

    screenTest('Shared with lists who has the recipe, and taking it back asks first', (tester) async {
      await pump(tester, mine, svc: FakeService()..sharees = const [RecipeSharee(friendId: 'f1', username: 'sam'), RecipeSharee(friendId: 'f2', username: 'bea')]);
      await openRecipe(tester);
      await tester.tap(find.byKey(const ValueKey('shared_with')));
      await settle(tester);
      expect(find.text('@sam'), findsOneWidget);
      expect(find.text('@bea'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('take_back_f1')));
      await settle(tester);
      expect(find.text("They'll no longer be able to open it. The message stays in chat."), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(service.calls, isEmpty); // cancelling does nothing
      await tester.tap(find.byKey(const ValueKey('take_back_f1')));
      await settle(tester);
      await tester.tap(find.text('Take back').last);
      await settle(tester);
      expect(service.calls, ['unshare:f1']);
      expect(find.text('@sam'), findsNothing);
      expect(find.text('@bea'), findsOneWidget);
    });

    screenTest('Shared with: nobody yet, and a failed load', (tester) async {
      await pump(tester, mine);
      await openRecipe(tester);
      await tester.tap(find.byKey(const ValueKey('shared_with')));
      await settle(tester);
      expect(find.byKey(const ValueKey('shared_empty')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await pump(tester, mine, svc: FakeService()..sharees = null);
      await openRecipe(tester);
      await tester.tap(find.byKey(const ValueKey('shared_with')));
      await settle(tester);
      expect(find.byKey(const ValueKey('shared_failed')), findsOneWidget);
    });

    screenTest('a friend\'s recipes list opens the recipe, and says when there are none', (tester) async {
      final svc = FakeService()
        ..friendList = [const RecipeBrief(id: rid, title: 'Chicken rice', calories: 600, estimated: false, mine: false, coverUrl: 'https://x/c.jpg')];
      await pump(tester, CupertinoPageScaffold(child: Builder(builder: (c) => CupertinoButton(child: const Text('go'), onPressed: () => showFriendRecipes(c, friendId: 'f1', username: 'sam')))), svc: svc);
      await tester.tap(find.text('go'));
      await settle(tester);
      expect(find.text('@sam’s recipes'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('friend_recipe_$rid')));
      await settle(tester);
      expect(find.byKey(const ValueKey('recipe_title')), findsOneWidget); // the recipe sheet opened
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await pump(tester, CupertinoPageScaffold(child: Builder(builder: (c) => CupertinoButton(child: const Text('go'), onPressed: () => showFriendRecipes(c, friendId: 'f1', username: 'sam')))));
      await tester.tap(find.text('go'));
      await settle(tester);
      expect(find.byKey(const ValueKey('friend_recipes_empty')), findsOneWidget);
    });

    String titleField() => 'recipe_title_field';
    Future<void> enterTitle(WidgetTester tester, String text) =>
        tester.enterText(find.descendant(of: find.byKey(ValueKey(titleField())), matching: find.byType(CupertinoTextField)), text);

    screenTest('editing starts from the saved recipe; a title change alone does not re-price the ingredients', (tester) async {
      await pump(tester, NewRecipeScreen(edit: recipe()));
      expect(find.text('Edit recipe'), findsOneWidget);
      expect(find.byKey(const ValueKey('ingredient_0')), findsOneWidget);
      expect(find.text('20 g · typed by you'), findsOneWidget);
      await enterTitle(tester, 'Chicken rice v2');
      await tester.tap(find.byKey(const ValueKey('save_recipe')));
      await settle(tester);
      expect(service.updates.single['title'], 'Chicken rice v2');
      expect(service.updates.single['servings'], 2.0);
      expect(service.updates.single['ingredients'], isNull);
      expect(service.created, isEmpty);
    });

    screenTest('removing an ingredient sends the whole new list', (tester) async {
      await pump(tester, NewRecipeScreen(edit: recipe()));
      await tester.tap(find.byKey(const ValueKey('remove_ingredient_1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save_recipe')));
      await settle(tester);
      final sent = service.updates.single['ingredients'] as List;
      expect(sent, hasLength(1));
      expect((sent.single as Map)['fdc_id'], 5);
    });

    screenTest('a photo of the dish fills in the ingredients, marks estimates, and becomes the cover', (tester) async {
      String? regionSeen;
      await pump(
        tester,
        NewRecipeScreen(
          makeId: () => 'new-id',
          analyzeDish: (photo, region) async {
            regionSeen = region;
            return [
              DetectedFood(name: 'Rice', estimatedGrams: 180, caloriesPer100g: 130, matched: true, matchedFdcId: 5),
              DetectedFood(name: 'Jollof stew', estimatedGrams: 120, caloriesPer100g: 150, matched: true, estimated: true, estimateBasis: 'typical'),
            ];
          },
        ),
      );
      await enterTitle(tester, 'Jollof plate');
      await tester.tap(find.byKey(const ValueKey('add_ingredient')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('add_photo_library')));
      await settle(tester);
      expect(regionSeen, isNull);
      expect(find.text('180 g'), findsOneWidget);
      expect(find.text('120 g · estimated'), findsOneWidget);
      expect(find.byKey(const ValueKey('dish_photo_note')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save_recipe')));
      await settle(tester);
      final sent = service.created.single['ingredients'] as List;
      expect((sent[0] as Map)['fdc_id'], 5); // priced from USDA on the server
      expect((sent[1] as Map).containsKey('fdc_id'), isFalse); // an estimate goes as typed values
      expect((sent[1] as Map)['per_100g'], containsPair('calories', 150.0));
      expect(service.calls, ['put:0:4']); // the photo became the cover
    });

    screenTest('a photo that shows nothing recognisable adds nothing and says so', (tester) async {
      await pump(tester, NewRecipeScreen(analyzeDish: (_, _) async => <DetectedFood>[]));
      await tester.tap(find.byKey(const ValueKey('add_ingredient')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('add_photo_camera')));
      await settle(tester);
      expect(find.byKey(const ValueKey('ingredient_0')), findsNothing);
      expect(find.byKey(const ValueKey('recipe_error')), findsOneWidget);
      expect(find.byKey(const ValueKey('dish_photo_note')), findsNothing);
    });

    screenTest('editing offers no photo option (it would replace the ingredients)', (tester) async {
      await pump(tester, NewRecipeScreen(edit: recipe()));
      await tester.tap(find.byKey(const ValueKey('add_ingredient')));
      await settle(tester);
      expect(find.byKey(const ValueKey('add_photo_library')), findsNothing);
      expect(find.byKey(const ValueKey('add_search')), findsOneWidget);
    });
  });
}
