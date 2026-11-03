/// Passes the `GET /targets` response from the login handshake to the
/// profile provider, so the profile is fetched once per login, not twice.
///
/// The handshake has to call `GET /targets` anyway (200 = onboarded, 404 =
/// not yet), and the profile provider then asked for the very same data. On
/// a Render free-tier instance, the second request was pure extra latency.
///
/// Deliberately narrow: one response, for one user, consumed once, and only
/// if fresh. Anything later (a weigh-in changed the targets, say) must go to
/// the server, never to this.
class TargetsHandoff {
  TargetsHandoff._();

  static const maxAge = Duration(minutes: 2);

  static String? _userId;
  static String? _body;
  static DateTime? _at;

  static void offer(String userId, String body, {DateTime? now}) {
    _userId = userId;
    _body = body;
    _at = now ?? DateTime.now();
  }

  /// The handed-over response body for [userId], or null if there isn't one,
  /// it's for someone else, or it's too old. Taking it clears it.
  static String? take(String userId, {DateTime? now}) {
    final body = _body;
    final fresh = _at != null && (now ?? DateTime.now()).difference(_at!) <= maxAge;
    final mine = _userId == userId;
    clear();
    return (body != null && fresh && mine) ? body : null;
  }

  static void clear() {
    _userId = null;
    _body = null;
    _at = null;
  }
}
