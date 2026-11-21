import '../l10n/app_strings.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_field.dart';
import '../widgets/google_sign_in_button.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

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
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      // No connection, DNS failure, a timeout: these are not AuthExceptions,
      // so the spinner used to stop with no message at all.
      if (mounted) setState(() => _errorMessage = context.tr("Couldn't log you in. Check your connection and try again."));
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
        middle: Text(context.tr('Log in')),
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
                  Text(context.tr('Welcome back'), style: AppType.title()),
                  const SizedBox(height: 6),
                  Text(context.tr('Sign in to keep your streak alive.'), style: AppType.callout()),
                  const SizedBox(height: AppSpacing.xl),
                  AppField(
                    controller: _emailController,
                    placeholder: context.tr('Email'),
                    icon: CupertinoIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppField(
                    controller: _passwordController,
                    placeholder: context.tr('Password'),
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
                    label: context.tr('Log in'),
                    loading: _isLoading,
                    onPressed: _isLoading ? null : _logIn,
                  ),
                  const GoogleSignInButton(),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: context.tr('Forgot password?'),
                    style: AppButtonStyle.quiet,
                    height: 44,
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: context.tr("Don't have an account? Sign up"),
                    style: AppButtonStyle.quiet,
                    height: 44,
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (context) => const SignUpScreen()),
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
