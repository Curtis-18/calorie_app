import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/providers/food_log_provider.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodEntry _entry() => FoodEntry(
  id: 'entry-1',
  name: 'Toast',
  calories: 120,
  mealType: MealType.breakfast,
  source: FoodSource.manual,
  timestamp: DateTime(2026, 11, 3, 8),
);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late StreamController<String?> auth;
  late String? userId;
  late List<http.BaseRequest> posts;
  late List<Future<http.Response> Function(http.Request)> script;

  setUp(() {
    UserCache.resetForTest();
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    auth = StreamController<String?>.broadcast();
    userId = 'user-a';
    posts = [];
    script = [];
  });
  tearDown(() => auth.close());

  FoodLogNotifier build({List<Duration> delays = const [Duration(milliseconds: 5), Duration(milliseconds: 5)]}) {
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('[]', 200);
      posts.add(request);
      final next = script.isEmpty ? (_) async => http.Response('{}', 201) : script.removeAt(0);
      return next(request);
    });
    return FoodLogNotifier(
      client: client,
      currentUserId: () => userId,
      authToken: () => 'token-$userId',
      userIdChanges: auth.stream,
      saveRetryDelays: delays,
      saveTimeout: const Duration(milliseconds: 100),
    );
  }

  test('a 5xx is retried and the entry is saved without a second log', () async {
    script = [(_) async => http.Response('boom', 503), (_) async => http.Response('{}', 201)];
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    await n.addEntry(_entry());
    expect(posts, hasLength(2));
    expect(n.state.map((e) => e.id), ['entry-1']);
    // Same id and body each time, which is what makes retrying safe.
    expect(posts[0].url, posts[1].url);
    expect((posts[0] as http.Request).body, (posts[1] as http.Request).body);
    expect((jsonDecode((posts[0] as http.Request).body) as Map)['id'], 'entry-1');
  });

  test('a timeout and a dropped connection are retried', () async {
    script = [
      (_) => Completer<http.Response>().future, // never answers: times out
      (_) async => throw http.ClientException('offline'),
      (_) async => http.Response('{}', 201),
    ];
    final n = build(delays: const [Duration(milliseconds: 5), Duration(milliseconds: 5)]);
    addTearDown(n.dispose);
    await _settle();

    await n.addEntry(_entry());
    expect(posts, hasLength(3));
    expect(n.state, hasLength(1));
  });

  test('the entry stays on screen while retrying, and is rolled back if every attempt fails', () async {
    script = [for (var i = 0; i < 3; i++) (_) async => http.Response('boom', 500)];
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    final saving = n.addEntry(_entry());
    await Future<void>.delayed(const Duration(milliseconds: 2));
    expect(n.state, hasLength(1), reason: 'optimistic while retrying');

    await expectLater(saving, throwsException);
    expect(posts, hasLength(3), reason: 'first try plus two retries');
    expect(n.state, isEmpty);
  });

  test('a 4xx is not retried', () async {
    script = [(_) async => http.Response('{"detail":"bad"}', 422)];
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    await expectLater(n.addEntry(_entry()), throwsException);
    expect(posts, hasLength(1));
    expect(n.state, isEmpty);
  });

  test("retries stop if another user signs in, so food isn't sent with the wrong token", () async {
    script = [(_) async => http.Response('boom', 500)];
    final n = build(delays: const [Duration(milliseconds: 40), Duration(milliseconds: 40)]);
    addTearDown(n.dispose);
    await _settle();

    final saving = n.addEntry(_entry());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    userId = 'user-b';
    auth.add('user-b');

    await expectLater(saving, throwsException);
    expect(posts, hasLength(1));
    expect(posts.single.headers['Authorization'], 'Bearer token-user-a');
  });
}
