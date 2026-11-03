import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/services/day_log_service.dart';
import 'package:calorie_app/services/log_cache_reader.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _row(String id, String date) => {
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

void main() {
  final day = DateTime(2026, 10, 30);
  String? signedIn;

  setUp(() {
    UserCache.resetForTest();
    SharedPreferences.setMockInitialValues({'user_cache_migrated_v1': true});
    signedIn = 'user-a';
    UserCache.currentUserId = () => signedIn;
  });

  test("a new device gets a past day from the server and caches it for offline", () async {
    late Uri seen;
    late String auth;
    final service = DayLogService(
      client: MockClient((request) async {
        seen = request.url;
        auth = request.headers['Authorization']!;
        return http.Response(jsonEncode([_row('a', '2026-10-30'), _row('b', '2026-10-30')]), 200);
      }),
      tokenProvider: () => 'tok',
    );

    expect(await LogCacheReader.entriesFor(day), isEmpty, reason: 'nothing on this device yet');

    final entries = await service.fetch(day);
    expect(entries!.map((e) => e.id), ['a', 'b']);
    expect(seen.path, endsWith('/logs/today'));
    expect(seen.queryParameters['date'], '2026-10-30');
    expect(auth, 'Bearer tok');

    expect((await LogCacheReader.entriesFor(day)).map((e) => e.id).toSet(), {'a', 'b'});
  });

  test('an empty server day replaces a stale cache', () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_migrated_v1': true,
      UserCache.logKey('user-a', day): [jsonEncode(_fromApi('stale'))],
    });
    final service = DayLogService(
      client: MockClient((_) async => http.Response('[]', 200)),
      tokenProvider: () => 'tok',
    );
    expect(await service.fetch(day), isEmpty);
    expect(await LogCacheReader.entriesFor(day), isEmpty);
  });

  test('failures return null and leave the cache alone', () async {
    SharedPreferences.setMockInitialValues({
      'user_cache_migrated_v1': true,
      UserCache.logKey('user-a', day): [jsonEncode(_fromApi('kept'))],
    });
    for (final handler in <Future<http.Response> Function(http.Request)>[
      (_) async => http.Response('boom', 500),
      (_) async => http.Response('nope', 401),
      (_) async => throw http.ClientException('offline'),
      (_) async => http.Response('not json', 200),
    ]) {
      final service = DayLogService(client: MockClient(handler), tokenProvider: () => 'tok');
      expect(await service.fetch(day), isNull);
    }
    final timeout = DayLogService(
      client: MockClient((_) => Completer<http.Response>().future),
      tokenProvider: () => 'tok',
      timeout: const Duration(milliseconds: 20),
    );
    expect(await timeout.fetch(day), isNull);
    expect((await LogCacheReader.entriesFor(day)).single.id, 'kept');
  });

  test('signed out: no request at all', () async {
    signedIn = null;
    var calls = 0;
    final service = DayLogService(
      client: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
      tokenProvider: () => 'tok',
    );
    expect(await service.fetch(day), isNull);
    expect(calls, 0);
  });

  test("a user switch mid-request doesn't write into the new user's cache", () async {
    final gate = Completer<void>();
    final service = DayLogService(
      client: MockClient((_) async {
        await gate.future;
        return http.Response(jsonEncode([_row('a', '2026-10-30')]), 200);
      }),
      tokenProvider: () => 'tok',
    );
    final pending = service.fetch(day);
    signedIn = 'user-b';
    gate.complete();
    await pending;
    expect(await LogCacheReader.entriesFor(day), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(UserCache.logKey('user-a', day)), isNull);
  });
}

Map<String, dynamic> _fromApi(String id) => {
  'id': id,
  'name': 'Toast',
  'calories': 120,
  'proteinG': 4.0,
  'carbsG': 20.0,
  'fatG': 2.0,
  'mealType': 'breakfast',
  'source': 'manual',
  'timestamp': '2026-10-30T08:00:00.000',
};
