import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/models/pending_scan.dart';
import 'package:calorie_app/providers/scan_queue_provider.dart';
import 'package:calorie_app/services/photo_estimation.dart';
import 'package:calorie_app/widgets/pending_scan_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

DetectedFood _rice() => DetectedFood(name: 'Rice', estimatedGrams: 150, caloriesPer100g: 130, matched: true);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late StreamController<String?> auth;
  late String? userId;
  late List<Completer<List<DetectedFood>>> calls;
  late List<String?> notes;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = StreamController<String?>.broadcast();
    userId = 'user-a';
    calls = [];
    notes = [];
  });
  tearDown(() => auth.close());

  ScanQueueNotifier build({List<Duration> delays = const [Duration(milliseconds: 5), Duration(milliseconds: 5)]}) {
    final n = ScanQueueNotifier(
      analyze: (bytes, note) {
        notes.add(note);
        final c = Completer<List<DetectedFood>>();
        calls.add(c);
        return c.future;
      },
      currentUserId: () => userId,
      userIdChanges: auth.stream,
      retryDelays: delays,
    );
    addTearDown(n.dispose);
    return n;
  }

  final photo = Uint8List.fromList([1, 2, 3, 4]);

  test('a photo becomes a pending card at once, and ready when the scan answers', () async {
    final n = build();
    await _settle();
    final id = n.start(photo, MealType.lunch);
    expect(id, isNotNull);
    expect(n.state.single.status, ScanStatus.scanning);
    expect(n.state.single.meal, MealType.lunch);

    calls.single.complete([_rice()]);
    await _settle();
    expect(n.state.single.status, ScanStatus.ready);
    expect(n.state.single.foods.single.name, 'Rice');
  });

  test('a scan that finds nothing says so', () async {
    final n = build();
    await _settle();
    n.start(photo, MealType.dinner);
    calls.single.complete([]);
    await _settle();
    expect(n.state.single.status, ScanStatus.empty);
  });

  test('a failure a retry cannot fix is shown straight away, with its message', () async {
    final n = build();
    await _settle();
    n.start(photo, MealType.dinner);
    calls.single.completeError(PhotoAnalysisException(PhotoEstimationService.tooLargeMessage));
    await _settle();
    expect(n.state.single.status, ScanStatus.failed);
    expect(n.state.single.message, PhotoEstimationService.tooLargeMessage);
    expect(n.state.single.retryable, isFalse);
    expect(calls, hasLength(1));
  });

  test('a timeout is retried by itself and then succeeds', () async {
    final n = build();
    await _settle();
    n.start(photo, MealType.breakfast);
    calls[0].completeError(PhotoAnalysisException(PhotoEstimationService.timeoutMessage, retryable: true));
    await _settle();
    expect(calls, hasLength(2));
    expect(n.state.single.status, ScanStatus.scanning);
    calls[1].complete([_rice()]);
    await _settle();
    expect(n.state.single.status, ScanStatus.ready);
  });

  test('after the automatic retries the person can try again with the same photo', () async {
    final n = build(delays: const [Duration(milliseconds: 5)]);
    await _settle();
    n.start(photo, MealType.snack);
    final timeout = PhotoAnalysisException(PhotoEstimationService.timeoutMessage, retryable: true);
    calls[0].completeError(timeout);
    await _settle();
    calls[1].completeError(timeout);
    await _settle();
    expect(n.state.single.status, ScanStatus.failed);
    expect(n.state.single.retryable, isTrue);

    n.retry(n.state.single.id);
    expect(n.state.single.status, ScanStatus.scanning);
    calls[2].complete([_rice()]);
    await _settle();
    expect(n.state.single.status, ScanStatus.ready);
  });

  test('an unexpected error becomes a plain message, not a crash', () async {
    final n = build();
    await _settle();
    n.start(photo, MealType.snack);
    calls.single.completeError(StateError('boom'));
    await _settle();
    expect(n.state.single.status, ScanStatus.failed);
    expect(n.state.single.message, contains('Something went wrong'));
  });

  test('only three photos wait at once', () async {
    final n = build();
    await _settle();
    for (var i = 0; i < 3; i++) {
      expect(n.start(photo, MealType.lunch), isNotNull);
    }
    expect(n.hasRoom, isFalse);
    expect(n.start(photo, MealType.lunch), isNull);
    n.remove(n.state.first.id);
    expect(n.hasRoom, isTrue);
  });

  test('nothing starts while signed out', () async {
    userId = null;
    final n = build();
    await _settle();
    expect(n.start(photo, MealType.lunch), isNull);
  });

  test('a waiting photo survives a restart and is scanned again', () async {
    final first = build();
    await _settle();
    first.start(photo, MealType.dinner);
    await _settle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(ScanQueueNotifier.storageKey('user-a')), hasLength(1));

    calls.clear();
    final second = build();
    await _settle();
    expect(second.state, hasLength(1));
    expect(second.state.single.meal, MealType.dinner);
    expect(second.state.single.image, photo);
    expect(calls, hasLength(1));
  });

  test('removing a card forgets its photo', () async {
    final n = build();
    await _settle();
    n.start(photo, MealType.dinner);
    await _settle();
    n.remove(n.state.single.id);
    await _settle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(ScanQueueNotifier.storageKey('user-a')), isNull);
  });

  test("a damaged saved record is dropped instead of breaking start-up", () async {
    SharedPreferences.setMockInitialValues({
      ScanQueueNotifier.storageKey('user-a'): ['not json', jsonEncode({'id': 'x'})],
    });
    final n = build();
    await _settle();
    expect(n.state, isEmpty);
  });

  test("another person signing in never sees, or receives, the previous person's scan", () async {
    final n = build();
    await _settle();
    n.start(photo, MealType.lunch);
    userId = 'user-b';
    auth.add('user-b');
    await _settle();
    expect(n.state, isEmpty);

    calls.single.complete([_rice()]); // the old scan answers late
    await _settle();
    expect(n.state, isEmpty);
  });

  test('a token refresh for the same person changes nothing', () async {
    final n = build();
    await _settle();
    n.start(photo, MealType.lunch);
    auth.add('user-a');
    await _settle();
    expect(n.state, hasLength(1));
  });

  group('the analysis service', () {
    test('sends the device date and marks which failures are worth retrying', () async {
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('[]', 200);
      });
      final service = PhotoEstimationService(client: client, tokenProvider: () async => 't');
      await service.analyzePhoto([1, 2, 3]);
      expect(body['date'], DateTime.now().toIso8601String().substring(0, 10));

      for (final entry in {502: true, 503: true, 504: true, 429: false, 413: false, 401: false, 422: false}.entries) {
        final failing = PhotoEstimationService(
          client: MockClient((_) async => http.Response('x', entry.key)),
          tokenProvider: () async => 't',
        );
        try {
          await failing.analyzePhoto([1]);
          fail('expected a failure');
        } on PhotoAnalysisException catch (e) {
          expect(e.retryable, entry.value, reason: 'status ${entry.key}');
        }
      }
    });
  });

  group('the card', () {
    Widget host(PendingScan scan, {VoidCallback? onReview, VoidCallback? onRetry, VoidCallback? onDismiss}) => CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: PendingScanCard(
                scan: scan,
                onReview: onReview ?? () {},
                onRetry: onRetry ?? () {},
                onDismiss: onDismiss ?? () {},
              ),
            ),
          ),
        );

    // A real 1x1 PNG so Image.memory can decode it.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    PendingScan scan(ScanStatus status, {String? message, List<DetectedFood> foods = const []}) => PendingScan(
          id: 's1', meal: MealType.lunch, image: png, startedAt: DateTime(2026, 11, 18), status: status, message: message, foods: foods,
        );

    testWidgets('scanning: says so, cannot be dismissed or opened', (tester) async {
      await tester.pumpWidget(host(scan(ScanStatus.scanning)));
      expect(find.text('Looking at your meal…'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan_dismiss_s1')), findsNothing);
      expect(find.byKey(const ValueKey('scan_review_s1')), findsNothing);
    });

    testWidgets('ready: shows the count and opens the review on tap', (tester) async {
      var opened = 0;
      await tester.pumpWidget(host(scan(ScanStatus.ready, foods: [_rice(), _rice()]), onReview: () => opened++));
      expect(find.text('2 foods found · tap to review'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan_review_s1')));
      expect(opened, 1);
    });

    testWidgets('failed: shows why, and offers Try again and dismiss', (tester) async {
      var retried = 0, dismissed = 0;
      await tester.pumpWidget(host(scan(ScanStatus.failed, message: 'Server busy.'), onRetry: () => retried++, onDismiss: () => dismissed++));
      expect(find.text('Server busy.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan_retry_s1')));
      await tester.tap(find.byKey(const ValueKey('scan_dismiss_s1')));
      expect([retried, dismissed], [1, 1]);
    });

    testWidgets('empty: can be dismissed', (tester) async {
      await tester.pumpWidget(host(scan(ScanStatus.empty)));
      expect(find.text('No food found'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan_dismiss_s1')), findsOneWidget);
    });
  });
}
