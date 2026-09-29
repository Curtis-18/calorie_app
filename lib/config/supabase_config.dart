import 'dart:convert';

/// Reads the `ref` claim out of a Supabase JWT without verifying it.
String? projectRefFromKey(String key) {
  final parts = key.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final ref = payload is Map ? payload['ref'] : null;
    return ref is String ? ref : null;
  } catch (_) {
    return null;
  }
}

/// Reads the project ref out of a Supabase project URL.
String? projectRefFromUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  final parts = host.split('.');
  return parts.length >= 2 && parts.first.isNotEmpty ? parts.first : null;
}

/// The one thing that breaks login: a key and a URL for different projects.
String? validateKeyPair({required String url, required String anonKey}) {
  if (anonKey.trim().isEmpty) {
    return 'SUPABASE_ANON_KEY was not supplied at build time.\n\n'
        'Rebuild with:\n'
        '--dart-define=SUPABASE_URL=$url\n'
        '--dart-define=SUPABASE_ANON_KEY=<your anon key>\n\n'
        'Project Settings > API Keys in the Supabase dashboard.';
  }

  final keyRef = projectRefFromKey(anonKey);
  final urlRef = projectRefFromUrl(url);

  if (keyRef == null) return 'The anon key does not look like a Supabase JWT.';
  if (urlRef == null) return 'SUPABASE_URL is not a valid URL: $url';
  if (keyRef != urlRef) {
    return 'The anon key belongs to project "$keyRef" but SUPABASE_URL points '
        'at "$urlRef".\n\n'
        'Supabase rejects this pairing with "Invalid API key". Use the key '
        'from the same project as the URL.';
  }
  return null;
}

/// Supabase credentials are build-time inputs, not source code.
///
/// They used to be hardcoded in `main.dart`, where a stale key failed at
/// runtime with a bare `{"message":"Invalid API key"}` and no clue why. Pass
/// them in at build time instead:
///
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pbancnuceteomuyybrlb.supabase.co',
  );

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => anonKey.trim().isNotEmpty;

  /// The `ref` claim baked into the anon key, e.g. "abcdefghijklmnop".
  ///
  /// A Supabase anon key is only valid against the project it was issued
  /// for. If the URL points somewhere else the API answers 401
  /// "Invalid API key" with no further detail, which is exactly the trap
  /// that broke login before.
  static String? get keyProjectRef => projectRefFromKey(anonKey);

  static String? get urlProjectRef => projectRefFromUrl(url);

  /// Returns a human-readable problem, or null when the config is usable.
  static String? validate() =>
      validateKeyPair(url: url, anonKey: anonKey);
}
