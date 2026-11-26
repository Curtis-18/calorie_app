import 'package:flutter/foundation.dart';

class ApiConfig {
  /// The backend on Render. Also the destination of the `/api` rewrite in
  /// vercel.json: change one, change the other (a test checks they match).
  static const String renderHost = 'calorie-backend-odc3.onrender.com';

  static const String _configured = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://$renderHost',
  );

  static String get baseUrl =>
      resolveBaseUrl(configured: _configured, isWeb: kIsWeb, page: Uri.base);

  /// Some networks' DNS says every `*.onrender.com` name does not exist, so a
  /// browser there can load the app and never find its backend. The published
  /// web app therefore calls `/api` on its own address, and Vercel forwards
  /// that to Render.
  ///
  /// Direct calls stay for phone builds, for local development (there is no
  /// forwarding there), and when BACKEND_URL names some other server.
  static String resolveBaseUrl({
    required String configured,
    required bool isWeb,
    required Uri page,
  }) {
    final published = isWeb &&
        page.scheme == 'https' &&
        page.host != 'localhost' &&
        page.host != '127.0.0.1';
    if (published && Uri.tryParse(configured)?.host == renderHost) {
      return '${page.origin}/api';
    }
    return configured;
  }
}
