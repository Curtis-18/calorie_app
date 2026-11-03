import 'dart:async';

import 'package:calorie_app/models/insights.dart';
import 'package:calorie_app/providers/insights_provider.dart';
import 'package:flutter_test/flutter_test.dart';

InsightsData _insights(String narrative) => InsightsData(
      narrative: narrative,
      tips: const [],
      weeklyTrend: const [],
      generatedAt: DateTime(2026, 11, 2),
    );

/// Fake backend: answers with the narrative for whichever user is "signed in".
class _Backend {
  String? user;
  int calls = 0;
  final pending = <Completer<InsightsData>>[];
  bool holdResponses = false;

  Future<InsightsData> fetch({bool refresh = false}) {
    calls++;
    if (holdResponses) {
      final c = Completer<InsightsData>();
      pending.add(c);
      return c.future;
    }
    return Future.value(_insights('insights for $user'));
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late StreamController<String?> auth;
  late _Backend backend;

  setUp(() {
    auth = StreamController<String?>.broadcast();
    backend = _Backend();
  });

  tearDown(() => auth.close());

  InsightsNotifier build({String? initialUser}) {
    backend.user = initialUser;
    return InsightsNotifier(
      fetch: backend.fetch,
      currentUserId: () => initialUser,
      userIdChanges: auth.stream,
    );
  }

  test('loads immediately when a session already exists', () async {
    final n = build(initialUser: 'a');
    await _settle();
    expect(n.state.value?.narrative, 'insights for a');
    expect(backend.calls, 1);
  });

  test('does not call the API while signed out', () async {
    final n = build();
    await _settle();
    expect(n.state.isLoading, isTrue);
    expect(backend.calls, 0);
  });

  test("sign-out clears the previous user's insights", () async {
    final n = build(initialUser: 'a');
    await _settle();
    auth.add(null);
    await _settle();
    expect(n.state.hasValue, isFalse);
    expect(n.state.isLoading, isTrue);
  });

  test('a different user signing in gets their own insights', () async {
    final n = build(initialUser: 'a');
    await _settle();
    auth.add(null);
    backend.user = 'b';
    auth.add('b');
    await _settle();
    expect(n.state.value?.narrative, 'insights for b');
  });

  test('token refresh for the same user does not refetch', () async {
    build(initialUser: 'a');
    await _settle();
    auth.add('a'); // replayed / tokenRefreshed event
    auth.add('a');
    await _settle();
    expect(backend.calls, 1);
  });

  test("a slow response for the old user can't overwrite the new user", () async {
    backend.holdResponses = true;
    final n = build(initialUser: 'a');
    await _settle();
    auth.add('b');
    await _settle();
    expect(backend.pending, hasLength(2));

    backend.pending[1].complete(_insights('insights for b'));
    await _settle();
    backend.pending[0].complete(_insights('insights for a')); // late, stale
    await _settle();

    expect(n.state.value?.narrative, 'insights for b');
  });

  test('a load that finishes after sign-out is discarded', () async {
    backend.holdResponses = true;
    final n = build(initialUser: 'a');
    await _settle();
    auth.add(null);
    await _settle();
    backend.pending.single.complete(_insights('insights for a'));
    await _settle();
    expect(n.state.hasValue, isFalse);
  });

  test('manual refresh still works for the current user', () async {
    final n = build(initialUser: 'a');
    await _settle();
    await n.load(refresh: true);
    expect(backend.calls, 2);
    expect(n.state.value?.narrative, 'insights for a');
  });

  group('after the food log changes', () {
    test('reloads quietly: the old insights stay on screen until the new ones land', () async {
      final n = build(initialUser: 'a');
      await _settle();
      expect(backend.calls, 1);

      backend.holdResponses = true;
      n.reloadSoon(debounce: const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(backend.calls, 2);
      expect(n.state.isLoading, isFalse, reason: 'no skeleton flash');
      expect(n.state.value?.narrative, 'insights for a');

      backend.pending.single.complete(_insights('you logged a meal'));
      await _settle();
      expect(n.state.value?.narrative, 'you logged a meal');
    });

    test('a burst of changes makes one request', () async {
      final n = build(initialUser: 'a');
      await _settle();
      for (var i = 0; i < 4; i++) {
        n.reloadSoon(debounce: const Duration(milliseconds: 20));
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(backend.calls, 2);
    });

    test('a failed quiet reload keeps what is already shown', () async {
      final failing = InsightsNotifier(
        fetch: ({bool refresh = false}) async {
          backend.calls++;
          if (backend.calls > 1) throw Exception('offline');
          return _insights('first');
        },
        currentUserId: () => 'a',
        userIdChanges: auth.stream,
      );
      await _settle();
      failing.reloadSoon(debounce: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(failing.state.value?.narrative, 'first');
    });
  });
}
