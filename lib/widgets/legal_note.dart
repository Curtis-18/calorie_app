import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../services/legal_links.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';

/// "By continuing you agree to our Terms of Service and Privacy Policy", for
/// the log-in and sign-up screens (it covers Google sign-in too). The two
/// names open the public pages.
class LegalNote extends StatelessWidget {
  const LegalNote({super.key, this.open});

  /// Test hook: called instead of opening a browser.
  final Future<bool> Function(Uri url)? open;

  @override
  Widget build(BuildContext context) {
    Widget link(String key, String label, Uri url) => CupertinoButton(
          key: ValueKey(key),
          minimumSize: const Size(44, 32),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onPressed: () => LegalLinks.open(url, launcher: open),
          child: Text(
            label,
            style: AppType.caption(color: TrackerColors.accentStartText, size: 12).copyWith(decoration: TextDecoration.underline),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Text(
            context.tr('By continuing you agree to our'),
            textAlign: TextAlign.center,
            style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              link('legal_terms', context.tr('Terms of Service'), LegalLinks.terms()),
              link('legal_privacy', context.tr('Privacy Policy'), LegalLinks.privacy()),
            ],
          ),
        ],
      ),
    );
  }
}
