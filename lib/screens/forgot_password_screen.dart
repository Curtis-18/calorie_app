import 'package:flutter/cupertino.dart';
import '../services/password_recovery.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_field.dart';

/// Asks for an email and sends the reset link.
///
/// The confirmation is the same whether or not an account exists, so this
/// screen can't be used to find out who has one.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = '', this.actions});

  final String initialEmail;
  final PasswordActions? actions;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  late final PasswordActions _actions = widget.actions ?? PasswordActions();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  Future<void> _send() async {
    final problem = validateEmail(_email.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _actions.sendLink(_email.text.trim(), PasswordActions.redirectTo);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: TrackerColors.navFill,
        border: AppDecor.hairlineTop,
        middle: const Text('Reset password'),
      ),
      child: AppBackdrop(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: AppCard(
              glow: TrackerColors.accentStart,
              child: _sent ? _confirmation(context) : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Forgot your password?', style: AppType.title()),
          const SizedBox(height: 6),
          Text('Enter your email and we\'ll send you a link to choose a new one.', style: AppType.callout()),
          const SizedBox(height: AppSpacing.xl),
          AppField(
            controller: _email,
            placeholder: 'Email',
            icon: CupertinoIcons.mail,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _ErrorBox(message: _error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Send reset link', loading: _sending, onPressed: _sending ? null : _send),
        ],
      );

  Widget _confirmation(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(gradient: TrackerColors.calorieGradient, shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.mail_solid, color: TrackerColors.onAccent, size: 26),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Check your email', style: AppType.title(), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'If ${_email.text.trim()} has an account, a reset link is on its way. It can take a minute, so check spam too.',
            style: AppType.callout(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Back to log in', onPressed: () => Navigator.of(context).pop()),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Send it again',
            style: AppButtonStyle.quiet,
            height: 44,
            onPressed: () => setState(() => _sent = false),
          ),
        ],
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(TrackerColors.error, 0.12),
        borderRadius: AppRadii.smallAll,
        border: Border.all(color: TrackerColors.alpha(TrackerColors.error, 0.28), width: 1),
      ),
      child: Text(message, style: AppType.caption(color: TrackerColors.error, size: 12)),
    );
  }
}
