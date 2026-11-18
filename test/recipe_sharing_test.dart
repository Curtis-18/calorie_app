import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/friends.dart';
import 'package:calorie_app/models/house_recipe.dart';
import 'package:calorie_app/models/messages.dart';
import 'package:calorie_app/providers/food_log_provider.dart';
import 'package:calorie_app/providers/friends_provider.dart';
import 'package:calorie_app/providers/house_recipes_provider.dart';
import 'package:calorie_app/providers/messages_provider.dart';
import 'package:calorie_app/screens/chat_screen.dart';
import 'package:calorie_app/screens/my_recipes_view.dart';
import 'package:calorie_app/services/house_recipe_service.dart';
import 'package:calorie_app/services/messages_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/house_recipe_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const rid = '11111111-1111-4111-8111-111111111111';
const rid2 = '22222222-2222-4222-8222-222222222222';

Map<String, dynamic> recipeJson({String id = rid, String title = 'Chicken rice', bool mine = true, String? owner}) => {
      'id': id,
      'mine': mine,
      'owner_name': owner,
      'title': title,
      'servings': 2,
      'calories_per_serving': 600,
      'protein_g': 40,
      'carbs_g': 60,
      'fat_g': 10,
      'estimated': false,
      'ingredients': [],
    };

Map<String, dynamic> briefJson({String id = rid, String title = 'Chicken rice', bool mine = true}) =>
    {'id': id, 'title': title, 'calories_per_serving': 600, 'estimated': false, 'mine': mine};

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class FakeService extends HouseRecipeService {
  FakeService({this.recipes = const [], this.collectionList = const [], this.pins = const [], this.byId = const {}});

  List<HouseRecipe> recipes;
  List<RecipeCollection> collectionList;
  List<RecipeBrief> pins;
  Map<String, HouseRecipe> byId;
  String? writeError;
  final writes = <String>[];

  @override
  Future<List<HouseRecipe>?> list() async => recipes;
  @override
  Future<List<RecipeCollection>?> collections() async => collectionList;
  @override
  Future<List<RecipeBrief>?> highlights() async => pins;
  @override
  Future<HouseRecipe?> get(String id) async => byId[id];

  Future<String?> _w(String what) async {
    writes.add(what);
    return writeError;
  }

  @override
  Future<String?> delete(String id) => _w('delete-recipe:$id');
  @override
  Future<String?> setHighlights(List<String> ids) => _w('pins:${ids.join(',')}');
  @override
  Future<String?> createCollection(String id, String name) => _w('new:$name');
  @override
  Future<String?> deleteCollection(String id) => _w('delete:$id');
  @override
  Future<String?> addToCollection(String c, String r) => _w('add:$c:$r');
  @override
  Future<String?> removeFromCollection(String c, String r) => _w('remove:$c:$r');
  @override
  Future<String?> save(String id) => _w('save:$id');
  @override
  Future<String?> share(String recipeId, String friendId, String messageId) => _w('share:$recipeId:$friendId');
}

class FakeFriends extends FriendsNotifier {
  FakeFriends(List<Person> people) : super(currentUserId: () => null, userIdChanges: const Stream.empty()) {
    state = AsyncValue.data(FriendsData(friends: people, incoming: const [], outgoing: const [], limit: 50));
  }
}

class FakeFoodLog extends FoodLogNotifier {
  FakeFoodLog() : super(currentUserId: () => null, userIdChanges: const Stream.empty());
}

void main() {
  group('models', () {
    test('a card is read, and anything else is ignored', () {
      final card = MessageAttachment.fromJson({'kind': 'recipe', 'id': rid, 'title': 'Stew', 'calories': 450})!;
      expect([card.recipeId, card.title, card.calories], [rid, 'Stew', 450]);
      expect(MessageAttachment.fromJson({'kind': 'sticker', 'id': 'x'}), isNull);
      expect(MessageAttachment.fromJson({'kind': 'recipe'}), isNull);
      expect(MessageAttachment.fromJson('x'), isNull);
      expect(MessageAttachment.fromJson(null), isNull);
    });

    test('a message carries its card, and still works without one', () {
      final base = {'id': 'm', 'mine': false, 'body': 'Sent you a recipe: Stew', 'created_at': '2026-11-19T10:00:00Z'};
      expect(ChatMessage.fromJson({...base, 'attachment': {'kind': 'recipe', 'id': rid, 'title': 'Stew', 'calories': 1}}).attachment, isNotNull);
      expect(ChatMessage.fromJson(base).attachment, isNull);
      final withCard = ChatMessage.fromJson({...base, 'attachment': {'kind': 'recipe', 'id': rid, 'title': 'Stew', 'calories': 1}});
      expect(withCard.copyWith(state: SendState.failed).attachment, isNotNull);
    });

    test('shared recipes know who they are from; collections count their recipes', () {
      final r = HouseRecipe.fromJson(recipeJson(mine: false, owner: 'sam'))!;
      expect([r.mine, r.ownerName], [false, 'sam']);
      expect(HouseRecipe.fromJson(recipeJson())!.mine, isTrue);
      final c = RecipeCollection.fromJson({'id': 'c', 'name': 'Saved', 'is_default': true, 'items': [briefJson(), 'junk']})!;
      expect(c.items.length, 1);
      expect(c.contains(rid), isTrue);
      expect(c.contains(rid2), isFalse);
      expect(RecipeCollection.fromJson('x'), isNull);
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

    test('reads collections and Highlights; failures are null, never thrown', () async {
      final ok = svc((r) => http.Response(jsonEncode(r.url.path == '/collections' ? [{'id': 'c', 'name': 'Saved', 'is_default': true, 'items': []}] : [briefJson()]), 200));
      expect((await ok.collections())!.single.name, 'Saved');
      expect((await ok.highlights())!.single.title, 'Chicken rice');
      expect(await svc((_) => http.Response('x', 500)).collections(), isNull);
      expect(await svc((_) => http.Response('x', 500)).highlights(), isNull);
    });

    test('each write goes to its own route with the right body', () async {
      final seen = <http.Request>[];
      final s = svc((_) => http.Response('', 204), seen);
      expect(await s.setHighlights([rid, rid2]), isNull);
      expect(await s.createCollection('c1', 'Meal prep'), isNull);
      expect(await s.addToCollection('c1', rid), isNull);
      expect(await s.removeFromCollection('c1', rid), isNull);
      expect(await s.deleteCollection('c1'), isNull);
      expect(await s.save(rid), isNull);
      expect(await s.share(rid, 'u-sam', 'msg-1'), isNull);
      expect(await s.unshare(rid, 'u-sam'), isNull);
      expect([for (final r in seen) '${r.method} ${r.url.path}'], [
        'PUT /highlights',
        'POST /collections',
        'POST /collections/c1/items',
        'DELETE /collections/c1/items/$rid',
        'DELETE /collections/c1',
        'POST /recipes/$rid/save',
        'POST /recipes/$rid/share/u-sam',
        'DELETE /recipes/$rid/share/u-sam',
      ]);
      expect(jsonDecode(seen[0].body), {'recipe_ids': [rid, rid2]});
      expect(jsonDecode(seen[6].body), {'id': 'msg-1'});
    });

    test('a refused write says why', () async {
      expect(await svc((_) => http.Response('', 403)).share(rid, 'u', 'm'), contains('only send recipes to your friends'));
      expect(await svc((_) => http.Response('', 404)).save(rid), contains("isn't available"));
      expect(await svc((_) => http.Response(jsonEncode({'detail': 'You can only pin your own recipes.'}), 422)).setHighlights([rid]), contains('own recipes'));
      expect(await svc((_) => http.Response('', 503)).createCollection('c', 'n'), contains("aren't available"));
      expect(await HouseRecipeService(client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () => 't').save(rid), contains("Couldn't reach"));
    });
  });

  group('provider', () {
    Future<(HouseRecipesNotifier, FakeService)> make({List<RecipeBrief> pins = const [], List<RecipeCollection> collections = const []}) async {
      final service = FakeService(recipes: [HouseRecipe.fromJson(recipeJson())!], pins: pins, collectionList: collections);
      final n = HouseRecipesNotifier(service: service, currentUserId: () => 'u', userIdChanges: const Stream.empty());
      addTearDown(n.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return (n, service);
    }

    test('pinning adds in order, unpinning removes, and the server is told the whole list', () async {
      final (n, service) = await make();
      final r = HouseRecipe.fromJson(recipeJson())!;
      expect(await n.togglePin(r), isNull);
      expect(n.state.highlights.map((h) => h.id), [rid]);
      expect(n.isPinned(rid), isTrue);
      expect(await n.togglePin(r), isNull);
      expect(n.state.highlights, isEmpty);
      expect(service.writes, ['pins:$rid', 'pins:']);
    });

    test('a seventh pin is refused without asking the server', () async {
      final (n, service) = await make(pins: [for (var i = 0; i < 6; i++) RecipeBrief(id: 'r$i', title: 'T$i', calories: 1, estimated: false, mine: true)]);
      final msg = await n.togglePin(HouseRecipe.fromJson(recipeJson())!);
      expect(msg, contains('up to 6'));
      expect(service.writes, isEmpty);
    });

    test('a failed pin changes nothing', () async {
      final (n, service) = await make();
      service.writeError = 'nope';
      expect(await n.togglePin(HouseRecipe.fromJson(recipeJson())!), 'nope');
      expect(n.state.highlights, isEmpty);
    });

    test('make and delete a collection', () async {
      final (n, _) = await make();
      expect(await n.createCollection('c1', '  Meal prep '), isNull);
      expect(n.state.collections.single.name, 'Meal prep');
      expect(await n.deleteCollection('c1'), isNull);
      expect(n.state.collections, isEmpty);
    });

    test('deleting a recipe also clears it from Highlights and collections', () async {
      final (n, _) = await make(
        pins: [RecipeBrief(id: rid, title: 'T', calories: 1, estimated: false, mine: true)],
        collections: [RecipeCollection(id: 'c', name: 'Meal prep', isDefault: false, items: [RecipeBrief(id: rid, title: 'T', calories: 1, estimated: false, mine: true)])],
      );
      expect(await n.remove(rid), isNull);
      expect(n.state.highlights, isEmpty);
      expect(n.state.collections.single.items, isEmpty);
    });

    test('collections failing to load does not make the page look broken', () async {
      final service = FakeService(recipes: [HouseRecipe.fromJson(recipeJson())!]);
      final n = HouseRecipesNotifier(service: service, currentUserId: () => 'u', userIdChanges: const Stream.empty());
      addTearDown(n.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(n.state.failed, isFalse);
    });
  });

  group('screens', () {
    late FakeService service;
    late FakeFoodLog food;
    late ProviderContainer container;

    void screenTest(String name, Future<void> Function(WidgetTester tester) body) {
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        if (food.mounted) food.dispose();
      });
    }

    Future<void> pump(WidgetTester tester, Widget home, {FakeService? svc, List<Person> friends = const []}) async {
      tester.view.physicalSize = const Size(750, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      service = svc ?? FakeService();
      food = FakeFoodLog();
      container = ProviderContainer(overrides: [
        houseRecipesProvider.overrideWith((ref) => HouseRecipesNotifier(service: service, currentUserId: () => 'u', userIdChanges: const Stream.empty())),
        foodLogProvider.overrideWith((ref) => food),
        friendsProvider.overrideWith((ref) => FakeFriends(friends)),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: CupertinoApp(theme: AppTheme.cupertino, home: home)));
      await settle(tester);
    }

    HouseRecipe mine() => HouseRecipe.fromJson(recipeJson())!;

    screenTest('the Mine tab shows Highlights, then Collections, then all recipes', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()),
          svc: FakeService(
            recipes: [mine()],
            pins: [RecipeBrief.fromJson(briefJson(title: 'Pinned stew'))!],
            collectionList: [RecipeCollection(id: 'c1', name: 'Meal prep', isDefault: false, items: [RecipeBrief.fromJson(briefJson())!])],
          ));
      expect(find.byKey(const ValueKey('highlights')), findsOneWidget);
      expect(find.text('Pinned stew'), findsOneWidget);
      expect(find.text('Meal prep'), findsOneWidget);
      expect(find.text('ALL RECIPES'), findsOneWidget);
      expect(find.text('HIGHLIGHTS'), findsOneWidget);
      expect(find.text('COLLECTIONS'), findsOneWidget);
    });

    screenTest('a collection lists its recipes and opens one', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()),
          svc: FakeService(
            recipes: [mine()],
            collectionList: [RecipeCollection(id: 'c1', name: 'Meal prep', isDefault: false, items: [RecipeBrief.fromJson(briefJson())!])],
            byId: {rid: mine()},
          ));
      await tester.tap(find.byKey(const ValueKey('collection_row_c1')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('collection_item_$rid')));
      await settle(tester);
      expect(find.byKey(const ValueKey('recipe_numbers')), findsOneWidget);
    });

    screenTest('deleting a collection asks the server', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()),
          svc: FakeService(recipes: [mine()], collectionList: [RecipeCollection(id: 'c1', name: 'Meal prep', isDefault: false)]));
      await tester.tap(find.byKey(const ValueKey('collection_row_c1')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('delete_collection')));
      await settle(tester);
      expect(service.writes, ['delete:c1']);
      expect(find.text('Meal prep'), findsNothing);
    });

    screenTest('the Saved collection cannot be deleted', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()),
          svc: FakeService(recipes: [mine()], collectionList: [RecipeCollection(id: 'c1', name: 'Saved', isDefault: true)]));
      await tester.tap(find.byKey(const ValueKey('collection_row_c1')));
      await settle(tester);
      expect(find.byKey(const ValueKey('delete_collection')), findsNothing);
    });

    screenTest('my recipe: pin it, then it says Unpin', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()), svc: FakeService(recipes: [mine()]));
      await tester.tap(find.text('Chicken rice'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('pin_recipe')));
      await settle(tester);
      expect(service.writes, ['pins:$rid']);
      expect(find.text('Unpin'), findsOneWidget);
    });

    screenTest('my recipe: add it to a collection, or make a new one', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()),
          svc: FakeService(recipes: [mine()], collectionList: [RecipeCollection(id: 'c1', name: 'Meal prep', isDefault: false)]));
      await tester.tap(find.text('Chicken rice'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('collections_button')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('collection_c1')));
      await settle(tester);
      expect(service.writes, ['add:c1:$rid']);

      await tester.tap(find.byKey(const ValueKey('collections_button')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('new_collection')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('collection_name')), 'Weeknights');
      await tester.tap(find.byKey(const ValueKey('collection_name_ok')));
      await settle(tester);
      expect(service.writes.skip(1).first, 'new:Weeknights');
    });

    screenTest('my recipe: send it to a friend', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()),
          svc: FakeService(recipes: [mine()]), friends: [Person(userId: 'u-sam', username: 'sam', since: DateTime(2026))]);
      await tester.tap(find.text('Chicken rice'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('send_recipe')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('send_to_u-sam')));
      await settle(tester);
      expect(service.writes, ['share:$rid:u-sam']);
      expect(find.textContaining('in your chat with sam'), findsOneWidget);
    });

    screenTest('with no friends, sending says how to add one', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()), svc: FakeService(recipes: [mine()]));
      await tester.tap(find.text('Chicken rice'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('send_recipe')));
      await settle(tester);
      expect(find.text('No friends yet'), findsOneWidget);
      expect(service.writes, isEmpty);
    });

    screenTest('a friend’s recipe says who it is from, can be saved and logged, but not deleted or re-shared', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: SizedBox()), svc: FakeService());
      final shared = HouseRecipe.fromJson(recipeJson(mine: false, owner: 'sam'))!;
      unawaited(showHouseRecipeSheet(tester.element(find.byType(CupertinoPageScaffold)), shared));
      await settle(tester);
      expect(find.text('From sam'), findsOneWidget);
      expect(find.byKey(const ValueKey('delete_recipe')), findsNothing);
      expect(find.byKey(const ValueKey('send_recipe')), findsNothing);
      expect(find.byKey(const ValueKey('log_recipe')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save_shared')));
      await settle(tester);
      expect(service.writes, ['save:$rid']);
      expect(find.text('Saved'), findsOneWidget);
    });

    screenTest('a recipe that cannot be opened says so', (tester) async {
      await pump(tester, const CupertinoPageScaffold(child: MyRecipesView()),
          svc: FakeService(recipes: [mine()], pins: [RecipeBrief.fromJson(briefJson())!], byId: {}));
      await tester.tap(find.byKey(const ValueKey('highlight_$rid')));
      await settle(tester);
      expect(find.text("Can't open this recipe"), findsOneWidget);
    });
  });

  group('chat card', () {
    ProviderContainer? chatContainer;
    FakeFoodLog? chatFood;

    // The food log keeps a midnight timer, so everything is disposed inside the test.
    void screenTestChat(String name, Future<void> Function(WidgetTester tester) body) => testWidgets(name, (tester) async {
          await body(tester);
          await tester.pumpWidget(const SizedBox());
          chatContainer?.dispose();
          if (chatFood?.mounted ?? false) chatFood!.dispose();
        }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    Map<String, dynamic> message({Map<String, dynamic>? attachment, String id = 'm1'}) => {
          'id': id,
          'mine': false,
          'body': 'Sent you a recipe: Sam stew (450 kcal per serving)',
          'created_at': DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String(),
          'read_at': null,
          'attachment': attachment,
        };

    Future<(FakeService, ProviderContainer)> open(WidgetTester tester, List<Map<String, dynamic>> thread, {Map<String, HouseRecipe> recipes = const {}}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final service = FakeService(byId: recipes);
      final client = MockClient((r) async {
        final body = r.url.path.startsWith('/messages/with/') && r.method == 'GET'
            ? {'messages': thread, 'has_more': false}
            : {'conversations': [], 'unread_total': 0};
        if (r.url.path.endsWith('/read')) return http.Response('', 204);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final food = FakeFoodLog();
      final container = ProviderContainer(overrides: [
        conversationsProvider.overrideWith((ref) => ConversationsNotifier(
              service: MessagesService(client: client, tokenProvider: () => 't'),
              currentUserId: () => 'me',
              userIdChanges: const Stream.empty(),
            )),
        houseRecipesProvider.overrideWith((ref) => HouseRecipesNotifier(service: service, currentUserId: () => 'u', userIdChanges: const Stream.empty())),
        foodLogProvider.overrideWith((ref) => food),
      ]);
      chatContainer = container;
      chatFood = food;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(theme: AppTheme.cupertino, home: const ChatScreen(userId: 'u-sam', username: 'sam', pollEvery: Duration(hours: 1))),
      ));
      await settle(tester);
      return (service, container);
    }

    screenTestChat('a recipe shows as a card, and tapping it opens the recipe', (tester) async {
      await open(
        tester,
        [message(attachment: {'kind': 'recipe', 'id': rid, 'title': 'Sam stew', 'calories': 450})],
        recipes: {rid: HouseRecipe.fromJson(recipeJson(mine: false, owner: 'sam', title: 'Sam stew'))!},
      );
      expect(find.byKey(const ValueKey('recipe_card_m1')), findsOneWidget);
      expect(find.text('Sam stew'), findsOneWidget);
      expect(find.textContaining('450 kcal per serving'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recipe_card_m1')));
      await settle(tester);
      expect(find.text('From sam'), findsOneWidget);
    });

    screenTestChat('a card for a recipe that is no longer shared says so', (tester) async {
      await open(tester, [message(attachment: {'kind': 'recipe', 'id': rid, 'title': 'Sam stew', 'calories': 450})]);
      await tester.tap(find.byKey(const ValueKey('recipe_card_m1')));
      await settle(tester);
      expect(find.text("Can't open this recipe"), findsOneWidget);
    });

    screenTestChat('a message without a card is plain text, and an unknown card falls back to the text', (tester) async {
      await open(tester, [
        message(id: 'a'),
        message(id: 'b', attachment: {'kind': 'sticker', 'id': 'x'}),
      ]);
      expect(find.byKey(const ValueKey('recipe_card_a')), findsNothing);
      expect(find.byKey(const ValueKey('recipe_card_b')), findsNothing);
      expect(find.textContaining('Sent you a recipe: Sam stew'), findsNWidgets(2));
    });
  });
}
