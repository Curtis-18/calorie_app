import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (response.session != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            content: const Text('Check your email to confirm your account, then log in.'),
            actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text('OK'))],
          ),
        );
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sign up'),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create your account', 
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(color: TrackerColors.textPrimary)
                ),
                const SizedBox(height: 24),
                CupertinoTextField(
                  controller: _emailController,
                  placeholder: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: _passwordController,
                  placeholder: 'Password',
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
                  child: CupertinoButton.filled(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CupertinoActivityIndicator(
                              color: TrackerColors.background,
                            ),
                          )
                        : const Text('Sign up'),
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    'Already have an account? Log in',
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
