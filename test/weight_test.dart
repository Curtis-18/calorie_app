import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/weight.dart';
import 'package:calorie_app/providers/weight_provider.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:calorie_app/services/weight_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/weight/weight_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _history({List<(String, double, double)>? points, int daysSinceLast = 2}) {
  final p = points ?? [('2026-09-01', 82.0, 82.0), ('2026-10-01', 80.5, 81.1), ('2026-10-31', 79.0, 79.8)];
  return {
    'entries': [
      for (final (d, w, t) in p) {'date': d, 'weight_kg': w, 'trend_kg': t},
    ],
    'summary': p.isEmpty
        ? null
        : {
            'start_kg': p.first.$2,
            'start_date': p.first.$1,
            'current_kg': p.last.$2,
            'current_date': p.last.$1,
            'trend_kg': p.last.$3,
            'change_kg': double.parse((p.last.$3 - p.first.$2).toStringAsFixed(1)),
            'raw_change_kg': p.last.$2 - p.first.$2,
            'lowest_kg': p.map((e) => e.$2).reduce((a, b) => a < b ? a : b),
            'highest_kg': p.map((e) => e.$2).reduce((a, b) => a > b ? a : b),
            'count': p.length,
            'days_since_last': daysSinceLast,
          },
  };
}

void main() {
  group('units and parsing', () {
    test('kg/lb conversion and formatting', () {
      expect(WeightUnit.lb.fromKg(100), closeTo(220.46, 0.01));
      expect(WeightUnit.lb.toKg(220.462262), closeTo(100, 1e-6));
      expect(WeightUnit.kg.format(72.44), '72.4 kg');
      expect(WeightUnit.lb.format(72.44), '159.7 lb');
      expect(WeightUnit.kg.formatChange(-2.2), '–2.2 kg');
      expect(WeightUnit.kg.formatChange(0.4), '+0.4 kg');
      expect(WeightUnit.kg.formatChange(0.01), '0.0 kg');
    });

    test('parseWeightKg accepts comma decimals and pounds, rejects implausible values', () {
      expect(parseWeightKg('72,5', WeightUnit.kg), 72.5);
      expect(parseWeightKg('160', WeightUnit.lb), closeTo(72.57, 0.01));
      for (final bad in ['', 'abc', '0', '-70', '19', '401']) {
        expect(parseWeightKg(bad, WeightUnit.kg), isNull, reason: bad);
      }
    });

    test('history parses, empty history has no summary', () {
      final h = WeightHistory.fromJson(_history());
      expect(h.entries, hasLength(3));
      expect(h.summary!.changeKg, -2.2);
      expect(WeightHistory.fromJson(_history(points: [])).isEmpty, isTrue);
    });
  });

  group('service', () {
    test("logs with the device's date and reads the result", () async {
      late http.Request seen;
      final service = WeightService(
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'history': _history(), 'targets_updated': true, 'notice': null}), 200);
        }),
        tokenProvider: () => 'token',
        now: () => DateTime(2026, 11, 2, 7),
      );

      final result = await service.log(78.456, on: DateTime(2026, 11, 1));

      expect(seen.method, 'POST');
      expect(seen.url.queryParameters['today'], '2026-11-02');
      expect(jsonDecode(seen.body), {'weight_kg': 78.46, 'date': '2026-11-01'});
      expect(result.targetsUpdated, isTrue);
    });

    test('errors are readable', () async {
      final service = WeightService(
        client: MockClient((_) async => http.Response('', 500)),
        tokenProvider: () => 'token',
      );
      expect(() => service.fetch(), throwsA(isA<WeightException>()));
    });
  });

  group('provider', () {
    test('loads per user and tells others when targets changed', () async {
      UserCache.resetForTest();
      SharedPreferences.setMockInitialValues({});
      final auth = StreamController<String?>.broadcast();
      addTearDown(auth.close);
      var targetsChanged = 0;
      final service = WeightService(
        client: MockClient((request) async => request.method == 'GET'
            ? http.Response(jsonEncode(_history()), 200)
            : http.Response(
                jsonEncode({'history': _history(), 'targets_updated': true, 'notice': 'Goal updated'}), 200)),
        tokenProvider: () => 'token',
      );
      final n = WeightNotifier(
        service: service,
        currentUserId: () => 'user-a',
        userIdChanges: auth.stream,
        onTargetsChanged: () => targetsChanged++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(n.state.value?.entries, hasLength(3));

      final notice = await n.log(78);
      expect(notice, 'Goal updated');
      expect(targetsChanged, 1);

      auth.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(n.state.isLoading, isTrue, reason: "signed out: no one's weight on screen");
      n.dispose();
    });
  });

  group('card', () {
    Future<void> pump(WidgetTester tester, Map<String, dynamic> history) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final service = WeightService(
        client: MockClient((_) async => http.Response(jsonEncode(history), 200)),
        tokenProvider: () => 'token',
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          weightProvider.overrideWith((ref) => WeightNotifier(
                service: service,
                currentUserId: () => 'u',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: const CupertinoPageScaffold(child: SingleChildScrollView(child: WeightProgressCard())),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows change, stats and a nudge after a week', (tester) async {
      await pump(tester, _history(daysSinceLast: 9));
      expect(find.text('–2.2 kg'), findsOneWidget);
      expect(find.text('82.0 kg'), findsOneWidget); // start
      expect(find.text('79.0 kg'), findsNWidgets(2)); // now + lowest
      expect(find.textContaining("It's been 9 days"), findsOneWidget);
      expect(find.text('Log weight'), findsOneWidget);
    });

    testWidgets('switching to pounds converts every number', (tester) async {
      await pump(tester, _history());
      await tester.tap(find.text('lb'));
      await tester.pumpAndSettle();
      expect(find.text('–4.9 lb'), findsOneWidget);
      expect(find.text('180.8 lb'), findsOneWidget);
    });

    testWidgets('empty history invites the first weigh-in', (tester) async {
      await pump(tester, _history(points: []));
      expect(find.textContaining('first weigh-in'), findsOneWidget);
    });

    testWidgets('the log sheet rejects an implausible weight', (tester) async {
      await pump(tester, _history());
      await tester.tap(find.text('Log weight'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '7');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a weight between'), findsOneWidget);
    });
  });
}
