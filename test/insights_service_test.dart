import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/services/insights_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _body = jsonEncode({
  'narrative': 'Solid week.',
  'tips': ['Eat more fibre'],
  'weekly_trend': [
    {'date': '2026-11-03', 'calories': 1800, 'protein_g': 90.0, 'carbs_g': 200.0, 'fat_g': 60.0},
  ],
  'generated_at': '2026-11-02T22:05:00Z',
});

InsightsService _service(
  MockClient client, {
  String? token = 'token',
  DateTime? now,
  Duration timeout = const Duration(seconds: 5),
}) =>
    InsightsService(
      client: client,
      tokenProvider: () => token,
      now: () => now ?? DateTime(2026, 11, 3, 1, 15),
      timeout: timeout,
    );

Future<String> _messageFor(Future<void> Function() call) async {
  try {
    await call();
  } on InsightsException catch (e) {
    return e.message;
  }
  fail('expected an InsightsException');
}

void main() {
  test("sends the device's local date, so the week matches the food logs", () async {
    // 01:15 local on 3 Nov, e.g. Nairobi, while UTC is still 2 Nov.
    late http.Request seen;
    final client = MockClient((request) async {
      seen = request;
      return http.Response(_body, 200);
    });

    final data = await _service(client, now: DateTime(2026, 11, 3, 1, 15)).fetchInsights(refresh: true);

    expect(seen.url.path, '/insights');
    expect(seen.url.queryParameters, {'refresh': 'true', 'date': '2026-11-03'});
    expect(seen.headers['Authorization'], 'Bearer token');
    expect(data.narrative, 'Solid week.');
    expect(data.weeklyTrend.single.calories, 1800);
  });

  test('signed out', () async {
    final client = MockClient((_) async => fail('must not call the API'));
    expect(
      await _messageFor(() => _service(client, token: null).fetchInsights()),
      InsightsService.signedOutMessage,
    );
  });

  test('server error shows a readable message, not the raw body', () async {
    final client = MockClient((_) async => http.Response('{"detail":"boom"}', 500));
    try {
      await _service(client).fetchInsights();
      fail('expected an exception');
    } on InsightsException catch (e) {
      expect(e.message, InsightsService.unavailableMessage);
      expect('$e', InsightsService.unavailableMessage); // what the screen renders
      expect('$e', isNot(contains('detail')));
    }
  });

  test('timeout', () async {
    final client = MockClient((_) => Completer<http.Response>().future);
    expect(
      await _messageFor(
        () => _service(client, timeout: const Duration(milliseconds: 10)).fetchInsights(),
      ),
      InsightsService.timeoutMessage,
    );
  });

  test('network failure', () async {
    final client = MockClient((_) async => throw http.ClientException('offline'));
    expect(
      await _messageFor(() => _service(client).fetchInsights()),
      InsightsService.networkMessage,
    );
  });
}
