import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/password_recovery.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_field.dart';

/// Shown when the user opens the emailed reset link: choose a new password.
/// They are already signed in by the link, so saving continues into the app.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone, required this.onCancel, this.actions});

  /// The new password was saved.
  final VoidCallback onDone;

  /// The user chose not to set one; sign them out.
  final VoidCallback onCancel;
  final PasswordActions? actions;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final PasswordActions _actions = widget.actions ?? PasswordActions();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final problem = validateNewPassword(_password.text, _confirm.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _actions.setPassword(_password.text);
      if (mounted) widget.onDone();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
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
                  Text('Choose a new password', style: AppType.title()),
                  const SizedBox(height: 6),
                  Text('Pick something you haven\'t used before. At least $minPasswordLength characters.',
                      style: AppType.callout()),
                  const SizedBox(height: AppSpacing.xl),
                  AppField(
                    controller: _password,
                    placeholder: 'New password',
                    icon: CupertinoIcons.lock,
                    obscure: true,
                    autofocus: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppField(
                    controller: _confirm,
                    placeholder: 'Type it again',
                    icon: CupertinoIcons.lock_shield,
                    obscure: true,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TrackerColors.alpha(TrackerColors.error, 0.12),
                        borderRadius: AppRadii.smallAll,
                        border: Border.all(color: TrackerColors.alpha(TrackerColors.error, 0.28), width: 1),
                      ),
                      child: Text(_error!, style: AppType.caption(color: TrackerColors.error, size: 12)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(label: 'Save password', loading: _saving, onPressed: _saving ? null : _save),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(label: 'Cancel', style: AppButtonStyle.quiet, height: 44, onPressed: widget.onCancel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
