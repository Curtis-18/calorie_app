import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';

/// Where the post-login check stands.
enum HandshakePhase {
  /// First few seconds: a normal, quick request.
  checking,

  /// Taking long enough that the server is probably booting (Render's free
  /// tier sleeps after ~15 idle minutes and takes 30-60 s to wake).
  waking,

  /// Onboarded: go to the app.
  ready,

  /// Signed in but no targets yet: go to onboarding.
  needsOnboarding,

  /// The session is no longer valid even after a refresh: sign in again.
  signedOut,

  /// Gave up after [ServerHandshake.deadline].
  unreachable,
}

/// Signature for fetching an access token. [forceRefresh] asks for a new one
/// even if the current one looks valid (used after a 401).
typedef TokenProvider = Future<String?> Function({bool forceRefresh});

/// The check AuthGate runs after login: is the server up, and has this user
/// onboarded (`GET /targets` → 200 / 404)?
///
/// Replaces a single 60 s request whose failure showed "Could not reach the
/// server" with a Retry button that appeared not to work: FutureBuilder kept
/// showing the old error while the new request ran, and the retry reused the
/// access token captured when the screen was built, which may have expired.
/// This retries on its own until [deadline], fetches a fresh token for every
/// attempt, and treats a persistent 401 as "sign in again" rather than a
/// network failure.
class ServerHandshake {
  ServerHandshake({
    this._client,
    TokenProvider? tokenProvider,
    this.deadline = const Duration(seconds: 100),
    this.attemptTimeout = const Duration(seconds: 35),
    this.retryDelay = const Duration(seconds: 2),
    this.wakingAfter = const Duration(seconds: 3),
  }) : _tokenProvider = tokenProvider ?? supabaseToken;

  final http.Client? _client;
  final TokenProvider _tokenProvider;
  final Duration deadline;
  final Duration attemptTimeout;
  final Duration retryDelay;
  final Duration wakingAfter;

  final ValueNotifier<HandshakePhase> phase = ValueNotifier(HandshakePhase.checking);

  /// When the current run started, for the elapsed-time display.
  DateTime startedAt = DateTime.now();

  int _run = 0;
  Timer? _wakingTimer;
  bool _disposed = false;

  /// Start (or restart, for Retry) the check. Safe to call while running:
  /// the previous run is abandoned.
  Future<void> start() async {
    final run = ++_run;
    bool current() => !_disposed && run == _run;

    startedAt = DateTime.now();
    phase.value = HandshakePhase.checking;
    _wakingTimer?.cancel();
    _wakingTimer = Timer(wakingAfter, () {
      if (current() && phase.value == HandshakePhase.checking) {
        phase.value = HandshakePhase.waking;
      }
    });

    final stopwatch = Stopwatch()..start();
    var refreshedAfter401 = false;
    final client = _client ?? http.Client();

    try {
      while (current() && stopwatch.elapsed < deadline) {
        String? token;
        try {
          token = await _tokenProvider(forceRefresh: refreshedAfter401);
        } on AuthException {
          token = null;
        }
        if (!current()) return;
        if (token == null) return _finish(run, HandshakePhase.signedOut);

        int? status;
        try {
          final remaining = deadline - stopwatch.elapsed;
          final response = await client
              .get(Uri.parse('${ApiConfig.baseUrl}/targets'),
                  headers: {'Authorization': 'Bearer $token'})
              .timeout(remaining < attemptTimeout ? remaining : attemptTimeout);
          status = response.statusCode;
        } catch (_) {
          // Timeout or no connection: likely still booting. Retry below.
        }
        if (!current()) return;

        if (status == 200) return _finish(run, HandshakePhase.ready);
        if (status == 404) return _finish(run, HandshakePhase.needsOnboarding);
        if (status == 401) {
          if (refreshedAfter401) return _finish(run, HandshakePhase.signedOut);
          refreshedAfter401 = true; // one more go with a freshly refreshed token
          continue;
        }

        // 5xx while the instance spins up, a timeout, or offline: wait, retry.
        if (phase.value == HandshakePhase.checking && stopwatch.elapsed >= wakingAfter) {
          phase.value = HandshakePhase.waking;
        }
        await Future<void>.delayed(retryDelay);
      }
      if (current()) _finish(run, HandshakePhase.unreachable);
    } finally {
      if (_client == null) client.close();
    }
  }

  void _finish(int run, HandshakePhase result) {
    if (_disposed || run != _run) return;
    _wakingTimer?.cancel();
    phase.value = result;
  }

  void dispose() {
    _disposed = true;
    _wakingTimer?.cancel();
    phase.dispose();
  }

  /// The current access token, refreshed if it's expired, about to expire,
  /// or [forceRefresh] is set. Null when there is no usable session.
  static Future<String?> supabaseToken({bool forceRefresh = false}) async {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return null;
    final expiresAt = session.expiresAt;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (forceRefresh || expiresAt == null || expiresAt < nowSeconds + 60) {
      final refreshed = await auth.refreshSession();
      return refreshed.session?.accessToken;
    }
    return session.accessToken;
  }
}

/// Fire-and-forget request so a sleeping server starts booting as early as
/// possible: at launch (while the splash and login screens show) and when the
/// app returns to the foreground. Never throws, never blocks.
class ServerWarmup {
  ServerWarmup._();

  static DateTime? _lastPing;

  static void ping({http.Client? client}) {
    final now = DateTime.now();
    if (_lastPing != null && now.difference(_lastPing!) < const Duration(minutes: 2)) return;
    _lastPing = now;
    final c = client ?? http.Client();
    unawaited(c
        .get(Uri.parse('${ApiConfig.baseUrl}/'))
        .timeout(const Duration(seconds: 90))
        .then((_) {}, onError: (_) {})
        .whenComplete(() {
      if (client == null) c.close();
    }));
  }
}
