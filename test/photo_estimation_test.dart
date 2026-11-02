import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/services/food_search_service.dart';
import 'package:calorie_app/services/photo_estimation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fallback search that fails the test if anything calls it.
FoodSearchService _noFallback() => FoodSearchService(
      client: MockClient((_) async => fail('unexpected fallback USDA lookup')),
      tokenProvider: () async => 'token',
    );

PhotoEstimationService _service(
  MockClient client, {
  String? token = 'token',
  Duration timeout = const Duration(seconds: 5),
  FoodSearchService? fallback,
}) =>
    PhotoEstimationService(
      client: client,
      tokenProvider: () async => token,
      fallbackSearch: fallback ?? _noFallback(),
      timeout: timeout,
    );

Future<String> _messageFor(Future<void> Function() call) async {
  try {
    await call();
  } on PhotoAnalysisException catch (e) {
    return e.message;
  }
  fail('expected a PhotoAnalysisException');
}

void main() {
  const bytes = [1, 2, 3];

  test('uses the macros the backend filled in, with no extra lookups', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(
        jsonEncode([
          {
            'name': 'Rice',
            'estimated_grams': 150,
            'matched': true,
            'calories_per_100g': 130,
            'protein_g_per_100g': 2.7,
            'carbs_g_per_100g': 28.0,
            'fat_g_per_100g': 0.3,
          },
          {'name': 'Mystery sauce', 'estimated_grams': 20, 'matched': false},
        ]),
        200,
      );
    });

    final foods = await _service(client).analyzePhoto(bytes);

    expect(requests, 1, reason: 'one round-trip per scan');
    expect(foods[0].matched, isTrue);
    expect(foods[0].estimatedCalories, 195); // 130 kcal/100 g x 150 g
    expect(foods[0].carbsPer100g, 28.0);
    expect(foods[1].matched, isFalse);
    expect(foods[1].caloriesPer100g, isNull);
  });

  test('an older backend (name + grams only) falls back to per-food lookups', () async {
    final photoClient = MockClient((_) async => http.Response(
          jsonEncode([
            {'name': 'rice', 'estimated_grams': 100},
          ]),
          200,
        ));
    final searches = <String>[];
    final fallback = FoodSearchService(
      client: MockClient((request) async {
        searches.add(request.url.queryParameters['query']!);
        return http.Response(
          jsonEncode({
            'results': [
              {
                'fdc_id': 1,
                'description': 'Rice',
                'data_type': 'Foundation',
                'calories_per_100g': 130,
                'protein_g_per_100g': 2.7,
                'carbs_g_per_100g': 28,
                'fat_g_per_100g': 0.3,
              },
            ],
          }),
          200,
        );
      }),
      tokenProvider: () async => 'token',
    );

    final foods = await _service(photoClient, fallback: fallback).analyzePhoto(bytes);

    expect(searches, ['rice']);
    expect(foods.single.matched, isTrue);
    expect(foods.single.estimatedCalories, 130);
  });

  test('parses detected foods on 200', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(request.body)['image'], base64Encode(bytes));
      return http.Response(
        jsonEncode([
          {'name': 'Rice', 'estimated_grams': 150, 'matched': false},
        ]),
        200,
      );
    });

    final foods = await _service(client).analyzePhoto(bytes);

    expect(foods, hasLength(1));
    expect(foods.single.name, 'Rice');
    expect(foods.single.estimatedGrams, 150.0);
  });

  test('no session is a PhotoAnalysisException, not a generic error', () async {
    final client = MockClient((_) async => fail('must not call the API'));
    final message = await _messageFor(
      () => _service(client, token: null).analyzePhoto(bytes),
    );
    expect(message, PhotoEstimationService.signedOutMessage);
  });

  final statusCases = {
    401: PhotoEstimationService.sessionExpiredMessage,
    413: PhotoEstimationService.tooLargeMessage,
    400: PhotoEstimationService.unreadableMessage,
    502: PhotoEstimationService.serviceBusyMessage,
    503: PhotoEstimationService.serviceBusyMessage,
  };
  statusCases.forEach((status, expected) {
    test('HTTP $status maps to a specific message', () async {
      final client = MockClient((_) async => http.Response('{"detail":"x"}', status));
      expect(await _messageFor(() => _service(client).analyzePhoto(bytes)), expected);
    });
  });

  test('unknown status includes the code', () async {
    final client = MockClient((_) async => http.Response('', 500));
    expect(
      await _messageFor(() => _service(client).analyzePhoto(bytes)),
      contains('500'),
    );
  });

  test('timeout says the server may be waking up', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    final message = await _messageFor(
      () => _service(client, timeout: const Duration(milliseconds: 10)).analyzePhoto(bytes),
    );
    expect(message, PhotoEstimationService.timeoutMessage);
  });

  test('network failure says the server could not be reached', () async {
    final client = MockClient((_) async => throw http.ClientException('no route'));
    expect(
      await _messageFor(() => _service(client).analyzePhoto(bytes)),
      PhotoEstimationService.networkMessage,
    );
  });

  test('malformed body is reported, not thrown as a TypeError', () async {
    final client = MockClient((_) async => http.Response('{"oops": true}', 200));
    expect(
      await _messageFor(() => _service(client).analyzePhoto(bytes)),
      PhotoEstimationService.badResponseMessage,
    );
  });
}
