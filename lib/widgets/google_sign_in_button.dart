import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../services/google_auth.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';

/// Google's own "G", in its own colours (brand rule: never recoloured).
const googleLogoAsset = 'assets/icons/google_g.png';

/// "Continue with Google", with a quiet "or" above it. Shown on the log-in and
/// sign-up screens, which are the same thing for Google (a new person simply
/// goes on to the usual onboarding).
///
/// The result comes back through the auth stream, so this listens for the
/// session and closes the pushed screens, as the email form does itself.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, this.start, this.signedIn, this.available});

  /// Test hooks. [start] begins the Google flow, [signedIn] announces a new
  /// session, [available] overrides the platform check.
  final Future<void> Function()? start;
  final Stream<bool>? signedIn;
  final bool? available;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  StreamSubscription<bool>? _sub;
  bool _busy = false;
  String? _error;

  bool get _available => widget.available ?? googleSignInAvailable();

  @override
  void initState() {
    super.initState();
    if (!_available) return;
    final stream = widget.signedIn ?? _sessionStream();
    _sub = stream.listen((yes) {
      if (yes && mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }, onError: (_) {});
  }

  static Stream<bool> _sessionStream() {
    try {
      return Supabase.instance.client.auth.onAuthStateChange
          .where((s) => s.event == AuthChangeEvent.signedIn && s.session != null)
          .map((_) => true);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.start ?? signInWithGoogle)();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = tr("Couldn't open Google sign-in. Check your connection and try again."));
    } finally {
      // On the web the page is already leaving; on a phone the browser is open.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: TrackerColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(context.tr('or'), style: AppType.caption(color: TrackerColors.textTertiary)),
            ),
            Expanded(child: Container(height: 1, color: TrackerColors.border)),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(
          key: const ValueKey('google_sign_in'),
          label: context.tr('Continue with Google'),
          style: AppButtonStyle.glass,
          leading: Image.asset(
            googleLogoAsset,
            key: const ValueKey('google_logo'),
            width: 20,
            height: 20,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
          loading: _busy,
          onPressed: _busy ? null : _go,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              key: const ValueKey('google_error'),
              textAlign: TextAlign.center,
              style: AppType.caption(color: TrackerColors.error, size: 12),
            ),
          ),
      ],
    );
  }
}
