import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';
import 'widgets/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pbancnuceteomuyybrlb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBiYW5jbnVjZXRlb251eXlicmxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzOTE3MDEsImV4cCI6MjEwMDk2NzcwMX0.m-mD_QzfoYtCPkJzt6TSW4ulXQps82y1T3G3Dy3E1yk',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Calorie Tracker',
      theme: AppTheme.cupertino,
      home: const SplashGate(child: AuthGate()),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => const MainShell(),
      },
    );
  }
}
