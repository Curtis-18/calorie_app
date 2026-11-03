import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/user_profile.dart';
import 'package:calorie_app/providers/user_provider.dart';
import 'package:calorie_app/services/targets_handoff.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = 'user-a';
const _b = 'user-b';

Map<String, dynamic> _targets({int calories = 2065, String? activity = 'very_active'}) => {
  'date_of_birth': '1995-03-14',
  'sex': 'female',
  'activity_level': activity,
  'goal': 'lose',
  'height_cm': 165.1,
  'weight_kg': 60.0,
  'bmr': 1350.0,
  'tdee': 2565.0,
  'calorie_target': calories,
  'bmi': 22.0,
  'protein_g': 120,
  'fat_g': 57,
  'carbs_g': 266,
};

String _cachedProfile(int calories) => jsonEncode({
  'weightKg': 70.0,
  'heightCm': 175.0,
  'dateOfBirth': '1990-01-01T00:00:00.000',
  'gender': 'male',
  'activityLevel': 'light',
  'goal': 'maintain',
  'calorieTarget': calories,
});

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late StreamController<String?> auth;

  setUp(() {
    UserCache.resetForTest();
    TargetsHandoff.clear();
    auth = StreamController<String?>.broadcast();
  });
  tearDown(() => auth.close());

  UserProfileNotifier build(MockClient client, {String user = _a}) => UserProfileNotifier(
    client: client,
    currentUserId: () => user,
    authToken: () => 'token',
    userIdChanges: auth.stream,
  );

  test('fromTargetsJson maps every field, including very_active', () {
    final p = UserProfile.fromTargetsJson(_targets())!;
    expect(p.dateOfBirth, DateTime(1995, 3, 14));
    expect(p.gender, Gender.female);
    expect(p.activityLevel, ActivityLevel.veryActive);
    expect(p.goal, Goal.lose);
    expect(p.heightCm, 165.1);
    expect(p.weightKg, 60.0);
    expect(p.calorieTarget, 2065);
    expect(p.carbsTargetG, 266);
  });

  test('fromTargetsJson returns null when the onboarding answers are missing', () {
    final old = _targets()..remove('date_of_birth');
    expect(UserProfile.fromTargetsJson(old), isNull);
    expect(UserProfile.fromTargetsJson(_targets(activity: 'couch')), isNull);
  });

  test('fresh device with no cache restores the profile from the server and caches it', () async {
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    late http.Request seen;
    final n = build(
      MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode(_targets()), 200);
      }),
    );
    await _settle();

    expect(seen.url.path, '/targets');
    expect(seen.headers['Authorization'], 'Bearer token');
    expect(n.state?.calorieTarget, 2065);
    expect(n.state?.activityLevel, ActivityLevel.veryActive);

    final prefs = await SharedPreferences.getInstance();
    final cached = jsonDecode(prefs.getString(UserCache.profileKey(_a))!) as Map<String, dynamic>;
    expect(cached['calorieTarget'], 2065);
  });

  test("login: reuses the handshake's response instead of asking the server again", () async {
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    var requests = 0;
    TargetsHandoff.offer(_a, jsonEncode(_targets(calories: 2222)));
    final n = build(
      MockClient((_) async {
        requests++;
        return http.Response(jsonEncode(_targets()), 200);
      }),
    );
    await _settle();

    expect(requests, 0);
    expect(n.state?.calorieTarget, 2222);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(UserCache.profileKey(_a))!)['calorieTarget'], 2222);
  });

  test('a handoff for another user, a stale one, or an unreadable one is ignored', () async {
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    for (final setup in <void Function()>[
      () => TargetsHandoff.offer('someone-else', jsonEncode(_targets(calories: 1111))),
      () => TargetsHandoff.offer(
        _a,
        jsonEncode(_targets(calories: 1111)),
        now: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      () => TargetsHandoff.offer(_a, 'not json'),
    ]) {
      setup();
      var requests = 0;
      final n = build(
        MockClient((_) async {
          requests++;
          return http.Response(jsonEncode(_targets()), 200);
        }),
      );
      await _settle();
      expect(requests, 1, reason: 'fell back to the server');
      expect(n.state?.calorieTarget, 2065);
      n.dispose();
    }
  });

  test('a handoff is used once: a later refresh goes to the server', () async {
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    var requests = 0;
    TargetsHandoff.offer(_a, jsonEncode(_targets(calories: 2222)));
    final n = build(
      MockClient((_) async {
        requests++;
        return http.Response(jsonEncode(_targets(calories: 2300)), 200);
      }),
    );
    await _settle();
    expect(requests, 0);

    await n.refreshFromServer(); // e.g. a weigh-in changed the targets
    expect(requests, 1);
    expect(n.state?.calorieTarget, 2300);
  });

  test('server copy replaces a stale cache (edited on another device)', () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_migrated_v1': true,
      UserCache.profileKey(_a): _cachedProfile(1800),
    });
    final n = build(MockClient((_) async => http.Response(jsonEncode(_targets(calories: 2400)), 200)));
    await _settle();
    expect(n.state?.calorieTarget, 2400);
  });

  test('offline keeps the cached profile', () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_migrated_v1': true,
      UserCache.profileKey(_a): _cachedProfile(1800),
    });
    final n = build(MockClient((_) async => throw http.ClientException('offline')));
    await _settle();
    expect(n.state?.calorieTarget, 1800);
  });

  test('not onboarded (404) leaves no profile', () async {
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    final n = build(MockClient((_) async => http.Response('{"detail":"No target set yet"}', 404)));
    await _settle();
    expect(n.state, isNull);
  });

  test('an older backend without the onboarding fields keeps the cache', () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_migrated_v1': true,
      UserCache.profileKey(_a): _cachedProfile(1800),
    });
    final old = _targets()
      ..remove('date_of_birth')
      ..remove('sex');
    final n = build(MockClient((_) async => http.Response(jsonEncode(old), 200)));
    await _settle();
    expect(n.state?.calorieTarget, 1800);
  });

  test("a slow server response for user A is dropped once B has signed in", () async {
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    final pending = Completer<http.Response>();
    var calls = 0;
    final n = build(
      MockClient((_) {
        calls++;
        if (calls == 1) return pending.future; // A's request hangs
        return Future.value(http.Response('', 404)); // B is not onboarded
      }),
    );
    await _settle();

    auth.add(_b);
    await _settle();
    pending.complete(http.Response(jsonEncode(_targets()), 200));
    await _settle();

    expect(n.state, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(UserCache.profileKey(_b)), isFalse);
  });
}
