import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:calorie_app/config/api_config.dart';
import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/services/food_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _result(int id, String name, String type, double? kcal) => {
      'fdc_id': id,
      'description': name,
      'data_type': type,
      'calories_per_100g': kcal,
      'protein_g_per_100g': 1.0,
      'carbs_g_per_100g': 2.0,
      'fat_g_per_100g': 3.0,
    };

FoodSearchService _service(
  MockClient client, {
  String? token = 'token',
  Duration timeout = const Duration(seconds: 5),
}) =>
    FoodSearchService(client: client, tokenProvider: () async => token, timeout: timeout);

Future<String> _messageFor(Future<void> Function() call) async {
  try {
    await call();
  } on FoodSearchException catch (e) {
    return e.message;
  }
  fail('expected a FoodSearchException');
}

void main() {
  test('searches through the backend with the session token, not USDA', () async {
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'query': 'apple',
          'results': [
            _result(1, 'Apples, raw', 'Foundation', 52),
            _result(2, 'Mystery', 'Branded', null), // no calories: dropped
          ],
        }),
        200,
      );
    });

    final items = await _service(client).search('  apple ');

    expect(seen.url.toString(), startsWith('${ApiConfig.baseUrl}/foods/search'));
    expect(seen.url.queryParameters, {'query': 'apple', 'page_size': '20'});
    expect(seen.headers['Authorization'], 'Bearer token');
    expect(seen.url.host, isNot(contains('nal.usda.gov')));

    expect(items, hasLength(1));
    expect(items.single.fdcId, 1);
    expect(items.single.dataType, 'Foundation');
    expect(items.single.caloriesPer100g, 52);
    expect(items.single.fatPer100g, 3);
  });

  test('empty query makes no request', () async {
    final client = MockClient((_) async => fail('must not call the API'));
    expect(await _service(client).search('   '), isEmpty);
  });

  test('signed out', () async {
    final client = MockClient((_) async => fail('must not call the API'));
    expect(
      await _messageFor(() => _service(client, token: null).search('apple')),
      FoodSearchService.signedOutMessage,
    );
  });

  test('backend error gives a readable message, and toString is the message', () async {
    final client = MockClient((_) async => http.Response('{"detail":"x"}', 502));
    try {
      await _service(client).search('apple');
      fail('expected an exception');
    } on FoodSearchException catch (e) {
      expect(e.message, FoodSearchService.unavailableMessage);
      // The search screen shows e.toString() directly.
      expect(e.toString(), FoodSearchService.unavailableMessage);
    }
  });

  test('timeout', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    expect(
      await _messageFor(
        () => _service(client, timeout: const Duration(milliseconds: 10)).search('apple'),
      ),
      FoodSearchService.timeoutMessage,
    );
  });

  test('network failure', () async {
    final client = MockClient((_) async => throw http.ClientException('offline'));
    expect(
      await _messageFor(() => _service(client).search('apple')),
      FoodSearchService.networkMessage,
    );
  });

  test('photo enrichment prefers generic foods and survives a failing lookup', () async {
    final client = MockClient((request) async {
      final q = request.url.queryParameters['query'];
      if (q == 'rice') {
        return http.Response(
          jsonEncode({
            'results': [
              _result(1, 'Rice, flavored, branded mix', 'Branded', 380),
              _result(2, 'Rice', 'Foundation', 130),
            ],
          }),
          200,
        );
      }
      return http.Response('', 502);
    });

    final rice = DetectedFood(name: 'rice', estimatedGrams: 150);
    final mystery = DetectedFood(name: 'mystery', estimatedGrams: 50);
    await _service(client).enrichDetectedFoods([rice, mystery]);

    expect(rice.matched, isTrue);
    expect(rice.caloriesPer100g, 130);
    expect(mystery.matched, isFalse);
  });

  test('no USDA API key is compiled into the app', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
      final source = f.readAsStringSync();
      return source.contains('api.nal.usda.gov') || source.contains('api_key');
    }).map((f) => f.path);
    expect(offenders, isEmpty);
  });
}
