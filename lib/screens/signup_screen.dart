import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_field.dart';
import 'login_screen.dart';

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
        await showAppDialog(
          context: context,
          title: 'Almost there',
          message: 'Check your email to confirm your account, then log in.',
          confirmLabel: 'OK',
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
      navigationBar: CupertinoNavigationBar(
        backgroundColor: TrackerColors.navFill,
        border: AppDecor.hairlineTop,
        middle: const Text('Sign up'),
      ),
      child: AppBackdrop(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: AppCard(
              glow: TrackerColors.accentStart,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create your account', style: AppType.title()),
                  const SizedBox(height: 6),
                  Text('Start tracking in under a minute.', style: AppType.callout()),
                  const SizedBox(height: AppSpacing.xl),
                  AppField(
                    controller: _emailController,
                    placeholder: 'Email',
                    icon: CupertinoIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppField(
                    controller: _passwordController,
                    placeholder: 'Password',
                    icon: CupertinoIcons.lock,
                    obscure: true,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TrackerColors.alpha(TrackerColors.error, 0.12),
                        borderRadius: AppRadii.smallAll,
                        border: Border.all(
                          color: TrackerColors.alpha(TrackerColors.error, 0.28),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppType.caption(color: TrackerColors.error, size: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Sign up',
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _signUp,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Already have an account? Log in',
                    style: AppButtonStyle.quiet,
                    height: 44,
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
