import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/providers/food_log_provider.dart';
import 'package:calorie_app/services/photo_estimation.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:calorie_app/widgets/meal_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _entry(String id, {String name = 'Toast'}) => FoodEntry(
      id: id,
      name: name,
      calories: 120,
      mealType: MealType.breakfast,
      source: FoodSource.manual,
      timestamp: DateTime(2026, 11, 3, 8),
    );

Map<String, dynamic> _api(String id, {String name = 'Toast'}) => {
      'id': id,
      'name': name,
      'calories': 120,
      'protein_g': 0,
      'carbs_g': 0,
      'fat_g': 0,
      'meal_type': 'breakfast',
      'source': 'manual',
      'timestamp': '2026-11-03T08:00:00',
    };

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late StreamController<String?> auth;
  late List<Map<String, dynamic>> onServer;
  late List<http.Request> writes;
  Future<http.Response> Function(http.Request)? onWrite;

  setUp(() {
    UserCache.resetForTest();
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    auth = StreamController<String?>.broadcast();
    onServer = [];
    writes = [];
    onWrite = null;
  });
  tearDown(() => auth.close());

  FoodLogNotifier build() {
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response(jsonEncode(onServer), 200);
      writes.add(request);
      return (onWrite ?? (_) async => http.Response('{}', request.method == 'DELETE' ? 204 : 201))(request);
    });
    return FoodLogNotifier(
      client: client,
      currentUserId: () => 'user-a',
      authToken: () => 'token',
      userIdChanges: auth.stream,
      saveRetryDelays: const [],
      saveTimeout: const Duration(seconds: 2),
    );
  }

  test('a reload while a save is in flight keeps the new entry on screen', () async {
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    final answer = Completer<http.Response>();
    onWrite = (_) => answer.future;
    final saving = n.addEntry(_entry('new'));
    await _settle();

    // The session token refreshes: the same user is announced again, which
    // reloads the day from a server that doesn't have the entry yet.
    auth.add('user-a');
    await _settle();
    expect(n.state.map((e) => e.id), ['new']);

    answer.complete(http.Response('{}', 201));
    await saving;
    expect(n.state.map((e) => e.id), ['new']);
  });

  test('a reload while a delete is in flight does not bring the entry back', () async {
    onServer = [_api('a'), _api('b')];
    final n = build();
    addTearDown(n.dispose);
    await _settle();
    expect(n.state.map((e) => e.id), ['a', 'b']);

    final answer = Completer<http.Response>();
    onWrite = (_) => answer.future;
    final deleting = n.removeEntry('a');
    await _settle();
    auth.add('user-a');
    await _settle();
    expect(n.state.map((e) => e.id), ['b']);

    answer.complete(http.Response('', 204));
    await deleting;
    expect(n.state.map((e) => e.id), ['b']);
  });

  test('one failed save does not undo another that succeeded meanwhile', () async {
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    onWrite = (r) async =>
        (jsonDecode(r.body) as Map)['id'] == 'bad' ? http.Response('no', 422) : http.Response('{}', 201);
    final results = await Future.wait([
      n.addEntry(_entry('good')).then((_) => true),
      n.addEntry(_entry('bad')).then((_) => true, onError: (_) => false),
    ]);
    expect(results, [true, false]);
    expect(n.state.map((e) => e.id), ['good']);
  });

  test('deleting encodes the id, and an entry already gone on the server counts as deleted', () async {
    onServer = [_api('1_0_Mac/cheese?#')];
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    onWrite = (_) async => http.Response('{"detail":"Log not found"}', 404);
    await n.removeEntry('1_0_Mac/cheese?#');
    expect(n.state, isEmpty);
    expect(writes.single.url.toString(), endsWith('/logs/1_0_Mac%2Fcheese%3F%23'));
  });

  test('a delete the server refuses puts the entry back where it was', () async {
    onServer = [_api('a'), _api('b'), _api('c')];
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    onWrite = (_) async => http.Response('boom', 500);
    await expectLater(n.removeEntry('b'), throwsException);
    expect(n.state.map((e) => e.id), ['a', 'b', 'c']);
  });

  test('a rate-limited photo scan gets a plain message', () {
    expect(PhotoEstimationService.messageForStatus(429), contains('Try again in a little while'));
  });

  testWidgets('a past day is read-only: no add button and no swipe to delete', (tester) async {
    await tester.pumpWidget(CupertinoApp(
      home: CupertinoPageScaffold(
        child: MealSection(title: 'lunch', entries: [_entry('a')], onPhoto: null, onSearch: null, onRemove: null),
      ),
    ));
    expect(find.byIcon(CupertinoIcons.add), findsNothing);
    expect(find.byType(Dismissible), findsNothing);
    expect(find.text('Toast'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
