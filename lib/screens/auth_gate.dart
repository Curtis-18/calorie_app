import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_field.dart';
import '../widgets/empty_state.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'signup_screen.dart';

enum _OnboardingStatus { done, notDone, error }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastUserId;
  Future<_OnboardingStatus>? _onboardingFuture;

  Future<_OnboardingStatus> _checkOnboarding(String accessToken) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/targets'), headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) return _OnboardingStatus.done;
      if (response.statusCode == 404) return _OnboardingStatus.notDone;
      return _OnboardingStatus.error;
    } catch (_) {
      return _OnboardingStatus.error;
    }
  }

  void _ensureCheckStarted(Session session) {
    if (_lastUserId == session.user.id && _onboardingFuture != null) return;
    _lastUserId = session.user.id;
    _onboardingFuture = _checkOnboarding(session.accessToken);
  }

  void _retry(Session session) {
    setState(() {
      _onboardingFuture = _checkOnboarding(session.accessToken);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          _lastUserId = null;
          _onboardingFuture = null;
          return const SignUpScreen();
        }

        _ensureCheckStarted(session);

        return FutureBuilder<_OnboardingStatus>(
          future: _onboardingFuture,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const CupertinoPageScaffold(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: TrackerColors.background),
                  child: Center(child: PulsingRing()),
                ),
              );
            }
            switch (snap.data!) {
              case _OnboardingStatus.done:
                return const MainShell();
              case _OnboardingStatus.notDone:
                return const OnboardingScreen();
              case _OnboardingStatus.error:
                return _RetryScreen(onRetry: () => _retry(session));
            }
          },
        );
      },
    );
  }
}

class _RetryScreen extends StatelessWidget {
  const _RetryScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: AppBackdrop(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppEmptyState(
              icon: CupertinoIcons.wifi_exclamationmark,
              title: 'Could not reach the server',
              message: 'Check your connection and try again.',
              accent: TrackerColors.error,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
              child: AppButton(
                label: 'Retry',
                icon: CupertinoIcons.refresh,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
