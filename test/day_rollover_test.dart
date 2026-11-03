import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/providers/food_log_provider.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = 'user-a';

Map<String, dynamic> _apiEntry(String id, String date) => {
      'id': id,
      'name': 'Toast',
      'calories': 120,
      'protein_g': 4,
      'carbs_g': 20,
      'fat_g': 2,
      'meal_type': 'breakfast',
      'source': 'manual',
      'timestamp': '${date}T08:00:00',
      'log_date': date,
    };

FoodEntry _entry(String id) => FoodEntry(
      id: id,
      name: 'Late snack',
      calories: 200,
      mealType: MealType.snack,
      source: FoodSource.manual,
      timestamp: DateTime(2026, 11, 3, 0, 30),
    );

/// Fake backend: GET returns one entry for whatever date is asked for,
/// POST records the body and answers [postStatus].
class _Backend {
  final gets = <String>[];
  final posts = <Map<String, dynamic>>[];
  int postStatus = 201;
  Completer<void>? holdPost;

  late final client = MockClient((request) async {
    if (request.method == 'GET') {
      final date = request.url.queryParameters['date']!;
      gets.add(date);
      return http.Response(jsonEncode([_apiEntry('srv-$date', date)]), 200);
    }
    posts.add(jsonDecode(request.body) as Map<String, dynamic>);
    await holdPost?.future;
    return http.Response('{}', postStatus);
  });
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late StreamController<String?> auth;
  late _Backend backend;
  late DateTime clock;

  setUp(() {
    UserCache.resetForTest();
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    auth = StreamController<String?>.broadcast();
    backend = _Backend();
    clock = DateTime(2026, 11, 2, 23, 50);
  });
  tearDown(() => auth.close());

  FoodLogNotifier build() => FoodLogNotifier(
        client: backend.client,
        currentUserId: () => _user,
        authToken: () => 'token',
        userIdChanges: auth.stream,
        now: () => clock,
        saveRetryDelays: const [], // these tests are about days, not retries
      );

  test('after midnight, adding food starts a clean day instead of reusing yesterday', () async {
    final n = build();
    addTearDown(n.dispose);
    await _settle();
    expect(n.state.single.id, 'srv-2026-11-02');

    clock = DateTime(2026, 11, 3, 0, 30); // past midnight, app still open
    await n.addEntry(_entry('late'));
    await _settle();

    // Saved under the new date...
    expect(backend.posts.single['log_date'], '2026-11-03');
    // ...and the new day was loaded fresh, without yesterday's entry.
    expect(backend.gets, ['2026-11-02', '2026-11-03']);
    expect(n.state.map((e) => e.id), isNot(contains('srv-2026-11-02')));
    expect(n.day, DateTime(2026, 11, 3));

    final prefs = await SharedPreferences.getInstance();
    final yesterday = prefs.getStringList(UserCache.logKey(_user, DateTime(2026, 11, 2)))!;
    expect(yesterday.single, contains('srv-2026-11-02'), reason: "yesterday's cache untouched");
    final today = prefs.getStringList(UserCache.logKey(_user, DateTime(2026, 11, 3))) ?? [];
    expect(today.where((e) => e.contains('srv-2026-11-02')), isEmpty,
        reason: "yesterday's entries must never be cached under the new date");
  });

  test('ensureCurrentDay is a no-op on the same day and reloads on a new one', () async {
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    expect(n.ensureCurrentDay(), isFalse);
    clock = DateTime(2026, 11, 3, 7);
    expect(n.ensureCurrentDay(), isTrue);
    expect(n.state, isEmpty, reason: 'cleared immediately, before the reload lands');
    await _settle();
    expect(n.state.single.id, 'srv-2026-11-03');
  });

  test("a failed save after midnight doesn't bring yesterday's list back", () async {
    final n = build();
    addTearDown(n.dispose);
    await _settle();

    backend.postStatus = 500;
    backend.holdPost = Completer<void>();
    final saving = n.addEntry(_entry('x'));
    await _settle();

    clock = DateTime(2026, 11, 3, 0, 1);
    n.ensureCurrentDay(); // e.g. the midnight timer fired mid-request
    backend.holdPost!.complete();
    await expectLater(saving, throwsException);
    await _settle();

    expect(n.state.map((e) => e.id), isNot(contains('srv-2026-11-02')));
  });

  testWidgets('the midnight timer rolls the log over while the app is open', (tester) async {
    // Built in the test's fake-time zone, so its midnight Timer is driven
    // by tester.pump rather than the wall clock.
    final n = build();
    await tester.pump(const Duration(milliseconds: 50));
    expect(n.state.single.id, 'srv-2026-11-02');

    clock = DateTime(2026, 11, 3, 0, 0, 2);
    await tester.pump(const Duration(minutes: 11)); // past 00:00:01
    await tester.pump(const Duration(milliseconds: 50));

    expect(backend.gets.last, '2026-11-03');
    expect(n.state.single.id, 'srv-2026-11-03');
    n.dispose();
  });
}
