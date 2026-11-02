import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/providers/food_log_provider.dart';
import 'package:calorie_app/providers/user_provider.dart';
import 'package:calorie_app/services/log_cache_reader.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = 'user-a';
const _b = 'user-b';

Map<String, dynamic> _profileJson(int calorieTarget) => {
      'weightKg': 70.0,
      'heightCm': 175.0,
      'dateOfBirth': '1995-01-01T00:00:00.000',
      'gender': 'female',
      'activityLevel': 'light',
      'goal': 'maintain',
      'calorieTarget': calorieTarget,
    };

String _entryJson(String id, {DateTime? at}) => jsonEncode(FoodEntry(
      id: id,
      name: 'Toast',
      calories: 120,
      mealType: MealType.breakfast,
      source: FoodSource.manual,
      timestamp: at ?? DateTime(2026, 11, 2, 8),
    ).toJson());

String _day(DateTime d) => d.toIso8601String().substring(0, 10);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  String? signedIn;

  setUp(() {
    UserCache.resetForTest();
    signedIn = null;
    UserCache.currentUserId = () => signedIn;
  });

  group('legacy migration', () {
    test("hands the old device-wide cache to the first user, then deletes it", () async {
      final today = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'user_profile': jsonEncode(_profileJson(1800)),
        'food_log_${_day(today)}': [_entryJson('1')],
        'tour_seen_dashboard': true,
      });

      await UserCache.migrateLegacy(_a);
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString(UserCache.profileKey(_a)), isNotNull);
      expect(prefs.getStringList(UserCache.logKey(_a, today)), hasLength(1));
      expect(prefs.containsKey('user_profile'), isFalse);
      expect(prefs.containsKey('food_log_${_day(today)}'), isFalse);
      expect(prefs.getBool('tour_seen_dashboard'), isTrue, reason: 'unrelated keys untouched');

      // A second user signing in later gets nothing of A's.
      await UserCache.migrateLegacy(_b);
      expect(prefs.containsKey(UserCache.profileKey(_b)), isFalse);
      expect(prefs.getKeys().where((k) => k.contains(_b)), isEmpty);
    });

    test('never overwrites data already scoped to the user', () async {
      final today = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'user_profile': jsonEncode(_profileJson(1800)),
        UserCache.profileKey(_a): jsonEncode(_profileJson(2400)),
        'food_log_${_day(today)}': [_entryJson('old')],
        UserCache.logKey(_a, today): [_entryJson('new')],
      });

      await UserCache.migrateLegacy(_a);
      final prefs = await SharedPreferences.getInstance();

      expect(jsonDecode(prefs.getString(UserCache.profileKey(_a))!)['calorieTarget'], 2400);
      expect(prefs.getStringList(UserCache.logKey(_a, today))!.single, contains('"new"'));
    });
  });

  group('history and streak', () {
    test("one user's cached days are invisible to another", () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'user_cache_migrated_v1': true,
        UserCache.logKey(_a, today): [_entryJson('1')],
        UserCache.logKey(_a, yesterday): [_entryJson('2')],
      });

      signedIn = _a;
      expect(await LogCacheReader.currentStreak(), 2);
      expect(await LogCacheReader.entriesFor(today), hasLength(1));
      expect(await LogCacheReader.cachedDays(), hasLength(2));

      signedIn = _b;
      expect(await LogCacheReader.currentStreak(), 0);
      expect(await LogCacheReader.entriesFor(today), isEmpty);
      expect(await LogCacheReader.cachedDays(), isEmpty);

      signedIn = null;
      expect(await LogCacheReader.currentStreak(), 0);
      expect(await LogCacheReader.entriesFor(today), isEmpty);
    });
  });

  group('profile provider', () {
    test('follows the signed-in user and clears on sign-out', () async {
      SharedPreferences.setMockInitialValues({
        'user_cache_migrated_v1': true,
        UserCache.profileKey(_a): jsonEncode(_profileJson(1800)),
        UserCache.profileKey(_b): jsonEncode(_profileJson(2500)),
      });
      final auth = StreamController<String?>.broadcast();
      addTearDown(auth.close);

      final n = UserProfileNotifier(currentUserId: () => _a, userIdChanges: auth.stream);
      await _settle();
      expect(n.state?.calorieTarget, 1800);

      auth.add(null);
      await _settle();
      expect(n.state, isNull);

      auth.add(_b);
      await _settle();
      expect(n.state?.calorieTarget, 2500);
    });

    test("a user with no cache does not inherit the previous user's targets", () async {
      SharedPreferences.setMockInitialValues({
        'user_cache_migrated_v1': true,
        UserCache.profileKey(_a): jsonEncode(_profileJson(1800)),
      });
      final auth = StreamController<String?>.broadcast();
      addTearDown(auth.close);

      final n = UserProfileNotifier(currentUserId: () => _a, userIdChanges: auth.stream);
      await _settle();
      expect(n.state?.calorieTarget, 1800);

      auth.add(_b);
      await _settle();
      expect(n.state, isNull);
    });
  });

  group('food log provider', () {
    Map<String, dynamic> apiEntry(String id) => {
          'id': id,
          'name': 'Toast',
          'calories': 120,
          'protein_g': 4,
          'carbs_g': 20,
          'fat_g': 2,
          'meal_type': 'breakfast',
          'source': 'manual',
          'timestamp': '2026-11-02T08:00:00',
          'log_date': '2026-11-02',
        };

    test('loads per user, caches under that user, clears on sign-out', () async {
      SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
      final auth = StreamController<String?>.broadcast();
      addTearDown(auth.close);
      var who = _a;
      final client = MockClient((_) async => http.Response(jsonEncode([apiEntry('$who-1')]), 200));

      final n = FoodLogNotifier(
        client: client,
        currentUserId: () => _a,
        authToken: () => 'token',
        userIdChanges: auth.stream,
      );
      await _settle();
      expect(n.state.single.id, 'user-a-1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(UserCache.logKey(_a, DateTime.now())), hasLength(1));

      auth.add(null);
      await _settle();
      expect(n.state, isEmpty);

      who = _b;
      auth.add(_b);
      await _settle();
      expect(n.state.single.id, 'user-b-1');
      expect(prefs.getStringList(UserCache.logKey(_a, DateTime.now()))!.single, contains('user-a-1'),
          reason: "B's load must not overwrite A's cache");
    });

    test("a load still in flight at sign-out does not bring the old user's entries back", () async {
      SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
      final auth = StreamController<String?>.broadcast();
      addTearDown(auth.close);
      final pending = Completer<http.Response>();
      final client = MockClient((_) => pending.future);

      final n = FoodLogNotifier(
        client: client,
        currentUserId: () => _a,
        authToken: () => 'token',
        userIdChanges: auth.stream,
      );
      await _settle();

      auth.add(null); // sign out while A's request is in flight
      await _settle();
      pending.complete(http.Response(jsonEncode([apiEntry('a-1')]), 200));
      await _settle();

      expect(n.state, isEmpty);
    });

    test("offline fallback reads only the signed-in user's cache", () async {
      final today = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'user_cache_migrated_v1': true,
        UserCache.logKey(_a, today): [_entryJson('a-cached')],
      });
      final auth = StreamController<String?>.broadcast();
      addTearDown(auth.close);
      final client = MockClient((_) async => throw http.ClientException('offline'));

      final n = FoodLogNotifier(
        client: client,
        currentUserId: () => _b,
        authToken: () => 'token',
        userIdChanges: auth.stream,
      );
      await _settle();
      expect(n.state, isEmpty);
    });
  });
}
