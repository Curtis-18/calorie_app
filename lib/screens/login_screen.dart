import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';
import '../services/auth_service.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _logIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TrackerColors.background, // FIXED: fog -> background
      appBar: AppBar(
        title: const Text('Log in'),
        backgroundColor: TrackerColors.background,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome back', 
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: TrackerColors.textPrimary)
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: TrackerColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: TrackerColors.textSecondary),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  style: const TextStyle(color: TrackerColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: TrackerColors.textSecondary),
                  ),
                  obscureText: true,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: TrackerColors.error, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _logIn,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: TrackerColors.background,
                            ),
                          )
                        : const Text('Log in'),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider(color: TrackerColors.divider, thickness: 1.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(color: TrackerColors.textSecondary),
                      ),
                    ),
                    const Expanded(child: Divider(color: TrackerColors.divider, thickness: 1.5)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login, color: TrackerColors.textPrimary),
                    label: const Text('Continue with Google', style: TextStyle(color: TrackerColors.textPrimary)),
                    onPressed: () async {
                      // Google sign-in logic
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SignUpScreen()),
                    );
                  },
                  child: const Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(color: TrackerColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
