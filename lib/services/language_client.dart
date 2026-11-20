import 'package:http/http.dart' as http;

import '../l10n/app_strings.dart';

/// An HTTP client that tells the server which language the app is showing
/// (the Accept-Language header), so the words the server writes (the weekly
/// report, badges, insights, the one-tap extras, scan names) come back in it.
/// Use it wherever a service would create `http.Client()`.
http.Client languageClient([http.Client? inner]) => _LanguageClient(inner ?? http.Client());

class _LanguageClient extends http.BaseClient {
  _LanguageClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Read when the request is sent, so a language chosen a second ago counts.
    request.headers['Accept-Language'] = AppStrings.active;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
