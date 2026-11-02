import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/services/photo_estimation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

PhotoEstimationService _service(
  MockClient client, {
  String? token = 'token',
  Duration timeout = const Duration(seconds: 5),
}) =>
    PhotoEstimationService(
      client: client,
      tokenProvider: () async => token,
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

  test('parses detected foods on 200', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(request.body)['image'], base64Encode(bytes));
      return http.Response(
        jsonEncode([
          {'name': 'Rice', 'estimated_grams': 150},
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
