import 'package:url_launcher/url_launcher.dart';

import 'profile_link.dart';

/// The public Privacy Policy and Terms pages (static pages shipped with the web
/// build, `web/privacy.html` and `web/terms.html`; Vercel serves them at
/// `/privacy` and `/terms`). They live on the app's own address, so a phone
/// build points at the same place as profile links do.
class LegalLinks {
  LegalLinks._();

  static Uri privacy({String? base}) => Uri.parse('${base ?? ProfileLink.base}/privacy');
  static Uri terms({String? base}) => Uri.parse('${base ?? ProfileLink.base}/terms');

  /// Opens [url] in the browser (a new tab on the web). [launcher] is a test
  /// hook. Returns false when nothing could open it; never throws.
  static Future<bool> open(Uri url, {Future<bool> Function(Uri url)? launcher}) async {
    try {
      return await (launcher ?? _launch)(url);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _launch(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);
}
