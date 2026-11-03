import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/appearance_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/main_shell.dart';
import 'services/server_handshake.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_shapes.dart';
import 'theme/tracker_colors.dart';
import 'widgets/glass.dart';
import 'widgets/splash.dart';
import 'widgets/theme_host.dart';

/// The onboarding steps are built from Material inputs (`TextFormField`,
/// `DropdownButtonFormField`) inside a `CupertinoApp`, which ships no
/// `MaterialLocalizations`.
///
/// `TextField` dereferences it while building rather than only in its debug
/// assertions — `_getEffectiveDecoration` calls `MaterialLocalizations.of`,
/// which null-asserts — so without this the Body Metrics step rendered as a
/// blank grey `ErrorWidget` in release. Steps built from `InputDecorator`
/// alone got away with it, which is why only step 2 broke, and why no test
/// caught it: the framework asserts are debug-only, and the app is deployed
/// as a release build.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  DefaultMaterialLocalizations.delegate,
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start waking a sleeping backend now, so it boots while the splash and
  // login screens are up instead of after the user has signed in.
  ServerWarmup.ping();

  final configError = SupabaseConfig.validate();
  if (configError == null) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  // Open in the user's chosen mode from the very first frame.
  final appearance = await AppearanceNotifier.load();
  TrackerColors.apply(appearance.resolve(WidgetsBinding.instance.platformDispatcher.platformBrightness));

  runApp(ProviderScope(
    overrides: [appearanceProvider.overrideWith((ref) => AppearanceNotifier(appearance))],
    child: MyApp(configError: configError),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.configError});

  final String? configError;

  @override
  Widget build(BuildContext context) {
    return ThemeHost(
      builder: (context, theme) => CupertinoApp(
        title: 'NuStreak',
        theme: theme,
        localizationsDelegates: appLocalizationsDelegates,
        home: SplashGate(
          child: configError == null ? const AuthGate() : ConfigErrorScreen(message: configError!),
        ),
        routes: {
          '/onboarding': (context) => const OnboardingScreen(),
          '/dashboard': (context) => const MainShell(),
        },
      ),
    );
  }
}

/// Shown instead of the auth flow when the build is missing a usable Supabase
/// key, so a misconfiguration reports itself rather than surfacing later as
/// an opaque "Invalid API key" on the login screen.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: BoxDecoration(color: TrackerColors.background),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: FrostedGlass(
                opacity: 0.07,
                borderRadius: BorderRadius.circular(AppRadii.container),
                border: Border.all(color: TrackerColors.borderStrong, width: 1),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: TrackerColors.alpha(TrackerColors.error, 0.14),
                              borderRadius: BorderRadius.circular(AppRadii.button),
                              border: Border.all(
                                color: TrackerColors.alpha(TrackerColors.error, 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              size: 18,
                              color: TrackerColors.error,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Supabase not configured',
                              style: TextStyle(
                                color: TrackerColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        message,
                        style: TextStyle(
                          color: TrackerColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
