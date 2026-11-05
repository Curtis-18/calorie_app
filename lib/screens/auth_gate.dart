import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/password_recovery.dart';
import '../services/server_handshake.dart';
import '../theme/tracker_colors.dart';
import '../widgets/animated_logo.dart';
import '../widgets/waking_up_view.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'reset_password_screen.dart';
import 'signup_screen.dart';
import 'username_screen.dart';

/// Routes a signed-in user to the app or to onboarding, after making sure
/// the backend is awake. See [ServerHandshake] for the connection logic and
/// [WakingUpView] for what's shown during a cold start.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.handshakeFactory});

  /// Test hook; defaults to a real [ServerHandshake].
  final ServerHandshake Function()? handshakeFactory;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _userId;
  ServerHandshake? _handshake;

  ServerHandshake _ensureHandshake(Session session) {
    final existing = _handshake;
    if (existing != null && _userId == session.user.id) return existing;
    _retire(existing);
    _userId = session.user.id;
    final handshake = (widget.handshakeFactory ?? ServerHandshake.new)();
    _handshake = handshake;
    handshake.start();
    return handshake;
  }

  /// Dispose an old handshake after this frame: a ValueListenableBuilder may
  /// still be subscribed to its notifier until it rebuilds.
  void _retire(ServerHandshake? handshake) {
    if (handshake == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => handshake.dispose());
  }

  Future<void> _signOut() async {
    try {
      // Local scope: works even when the server or the refresh token is gone.
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  @override
  void dispose() {
    _handshake?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Arrived through a reset link: choose a new password before anything else.
    return ValueListenableBuilder<bool>(
      valueListenable: PasswordRecovery.pending,
      builder: (context, recovering, _) {
        if (recovering && Supabase.instance.client.auth.currentSession != null) {
          return ResetPasswordScreen(
            onDone: PasswordRecovery.clear,
            onCancel: () async {
              PasswordRecovery.clear();
              await _signOut();
            },
          );
        }
        return _gate(context);
      },
    );
  }

  Widget _gate(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          _retire(_handshake);
          _handshake = null;
          _userId = null;
          return const SignUpScreen();
        }

        final handshake = _ensureHandshake(session);
        return ValueListenableBuilder<HandshakePhase>(
          valueListenable: handshake.phase,
          builder: (context, phase, _) {
            switch (phase) {
              case HandshakePhase.checking:
                // Usually a fraction of a second: keep the splash's calm look.
                return CupertinoPageScaffold(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: TrackerColors.background),
                    child: const Center(child: AnimatedLogo(size: 140, tile: true, sparks: false)),
                  ),
                );
              case HandshakePhase.waking:
                return WakingUpView(startedAt: handshake.startedAt);
              case HandshakePhase.ready:
                return const MainShell();
              case HandshakePhase.needsUsername:
                return UsernameScreen(
                  onDone: (_) => handshake.usernameChosen(),
                  onSignOut: _signOut,
                );
              case HandshakePhase.needsOnboarding:
                return const OnboardingScreen();
              case HandshakePhase.signedOut:
                // Session can't be refreshed: back to sign-in rather than a
                // misleading "Could not reach the server".
                WidgetsBinding.instance.addPostFrameCallback((_) => _signOut());
                return CupertinoPageScaffold(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: TrackerColors.background),
                    child: const Center(child: AnimatedLogo(size: 140, tile: true, sparks: false)),
                  ),
                );
              case HandshakePhase.unreachable:
                return ServerUnreachableView(
                  onRetry: handshake.start,
                  onSignOut: _signOut,
                );
            }
          },
        );
      },
    );
  }
}

