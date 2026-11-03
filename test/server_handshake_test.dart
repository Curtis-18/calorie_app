import 'dart:async';

import 'package:calorie_app/services/server_handshake.dart';
import 'package:calorie_app/services/targets_handoff.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/waking_up_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Short real-time settings so a full cold-start scenario runs in well under
/// a second.
ServerHandshake _handshake(
  MockClient client, {
  TokenProvider? tokens,
  Duration deadline = const Duration(milliseconds: 400),
}) =>
    ServerHandshake(
      client: client,
      tokenProvider: tokens ?? ({bool forceRefresh = false}) async => 'token',
      deadline: deadline,
      attemptTimeout: const Duration(milliseconds: 80),
      retryDelay: const Duration(milliseconds: 10),
      wakingAfter: const Duration(milliseconds: 40),
      currentUserId: () => 'user-a',
    );

/// Every phase the handshake passes through, in order.
List<HandshakePhase> _record(ServerHandshake h) {
  final seen = <HandshakePhase>[h.phase.value];
  h.phase.addListener(() => seen.add(h.phase.value));
  return seen;
}

void main() {
  test('200 means ready, 404 means onboarding', () async {
    final ready = _handshake(MockClient((_) async => http.Response('{}', 200)));
    await ready.start();
    expect(ready.phase.value, HandshakePhase.ready);

    final fresh = _handshake(MockClient((_) async => http.Response('{}', 404)));
    await fresh.start();
    expect(fresh.phase.value, HandshakePhase.needsOnboarding);
  });

  test('a 200 hands the targets response over; a 404 does not', () async {
    TargetsHandoff.clear();
    final fresh = _handshake(MockClient((_) async => http.Response('{"x":1}', 404)));
    await fresh.start();
    expect(TargetsHandoff.take('user-a'), isNull);

    final ready = _handshake(MockClient((_) async => http.Response('{"calorie_target":2000}', 200)));
    await ready.start();
    expect(TargetsHandoff.take('user-a'), '{"calorie_target":2000}');
  });

  test('a cold start (503s, then 200) shows waking and ends ready', () async {
    var calls = 0;
    final h = _handshake(MockClient((_) async {
      calls++;
      if (calls < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('booting', 503);
      }
      return http.Response('{}', 200);
    }));
    final phases = _record(h);

    await h.start();

    expect(calls, 4);
    expect(phases.first, HandshakePhase.checking);
    expect(phases, contains(HandshakePhase.waking));
    expect(phases.last, HandshakePhase.ready);
  });

  test('gives up at the deadline, and Retry really retries', () async {
    var serverUp = false;
    final h = _handshake(MockClient((_) async {
      if (!serverUp) return Completer<http.Response>().future; // hangs
      return http.Response('{}', 200);
    }));

    await h.start();
    expect(h.phase.value, HandshakePhase.unreachable);

    // The old Retry kept showing the error while the new request ran.
    serverUp = true;
    final retry = h.start();
    expect(h.phase.value, HandshakePhase.checking, reason: 'leaves the error screen at once');
    await retry;
    expect(h.phase.value, HandshakePhase.ready);
  });

  test('every attempt asks for a token; a 401 retries once with a forced refresh', () async {
    final tokenCalls = <bool>[];
    var calls = 0;
    final h = _handshake(
      MockClient((request) async {
        calls++;
        if (request.headers['Authorization'] == 'Bearer stale') return http.Response('', 401);
        return http.Response('{}', 200);
      }),
      tokens: ({bool forceRefresh = false}) async {
        tokenCalls.add(forceRefresh);
        return forceRefresh ? 'fresh' : 'stale';
      },
    );

    await h.start();

    expect(tokenCalls, [false, true]);
    expect(calls, 2);
    expect(h.phase.value, HandshakePhase.ready);
  });

  test('a 401 even after refreshing means signed out, not "unreachable"', () async {
    final h = _handshake(MockClient((_) async => http.Response('', 401)));
    await h.start();
    expect(h.phase.value, HandshakePhase.signedOut);
  });

  test('no session or a failed refresh means signed out', () async {
    final none = _handshake(
      MockClient((_) async => fail('must not call the API')),
      tokens: ({bool forceRefresh = false}) async => null,
    );
    await none.start();
    expect(none.phase.value, HandshakePhase.signedOut);

    final broken = _handshake(
      MockClient((_) async => fail('must not call the API')),
      tokens: ({bool forceRefresh = false}) async => throw const AuthException('refresh token revoked'),
    );
    await broken.start();
    expect(broken.phase.value, HandshakePhase.signedOut);
  });

  test('restarting abandons the previous run', () async {
    final first = Completer<http.Response>();
    var calls = 0;
    final h = _handshake(
      MockClient((_) {
        calls++;
        return calls == 1 ? first.future : Future.value(http.Response('{}', 404));
      }),
      deadline: const Duration(seconds: 5),
    );

    unawaited(h.start());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await h.start();
    expect(h.phase.value, HandshakePhase.needsOnboarding);

    first.complete(http.Response('{}', 200)); // late answer from run 1
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.phase.value, HandshakePhase.needsOnboarding);
  });

  group('waking-up screen', () {
    test('headline changes as the wait goes on', () {
      expect(WakingUpView.titleFor(const Duration(seconds: 4)), 'Waking up the server');
      expect(WakingUpView.titleFor(const Duration(seconds: 20)), 'Warming things up');
      expect(WakingUpView.titleFor(const Duration(seconds: 50)), 'Almost there');
    });

    test('progress rises but never claims to be done', () {
      final values = [0, 10, 30, 60, 300]
          .map((s) => WakingUpView.progressFor(Duration(seconds: s)))
          .toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
      expect(values.last, lessThan(0.95));
    });

    testWidgets('renders and ticks without errors', (tester) async {
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: WakingUpView(startedAt: DateTime.now().subtract(const Duration(seconds: 3))),
      ));
      expect(find.text('Waking up the server'), findsOneWidget);
      expect(find.textContaining('usually under a minute'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox()); // dispose timers cleanly
    });

    testWidgets('unreachable screen offers a working retry and sign out', (tester) async {
      var retries = 0;
      var signOuts = 0;
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: ServerUnreachableView(onRetry: () => retries++, onSignOut: () => signOuts++),
      ));
      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect((retries, signOuts), (1, 1));
    });
  });
}
