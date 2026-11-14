import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/username_rules.dart';
import '../services/username_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/animated_logo.dart';
import '../widgets/app_button.dart';
import '../widgets/app_field.dart';

enum _NameStatus { empty, invalid, checking, available, unavailable, error }

/// "Pick your username": the name friends will find you by.
///
/// Shown right after sign-up for new people and on the next sign-in for
/// everyone who joined before usernames existed.
class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key, required this.onDone, this.onSignOut, this.service, this.current});

  /// Called with the saved username.
  final ValueChanged<String> onDone;

  /// Offered so nobody is stuck here if they signed in to the wrong account.
  final VoidCallback? onSignOut;

  final UsernameService? service;

  /// The name they have now. When set this is the "change your username"
  /// screen, opened from the profile sheet, with a way back.
  final String? current;

  bool get changing => current != null;

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _controller = TextEditingController();
  late final UsernameService _service = widget.service ?? UsernameService();

  Timer? _debounce;
  int _generation = 0;
  _NameStatus _status = _NameStatus.empty;
  String? _message;
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(_NameStatus status, [String? message]) =>
      setState(() {
        _status = status;
        _message = message;
      });

  void _onChanged(String value) {
    _debounce?.cancel();
    final generation = ++_generation; // late answers for older text are dropped
    final name = value.trim();

    if (name.isEmpty) {
      _show(_NameStatus.empty);
      return;
    }
    final problem = validateUsername(name);
    if (problem != null) {
      // Don't nag while they are still typing the first couple of letters.
      name.length < usernameMinLength ? _show(_NameStatus.empty) : _show(_NameStatus.invalid, problem);
      return;
    }
    _show(_NameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await _service.check(name);
        if (!mounted || generation != _generation) return;
        result.available
            ? _show(_NameStatus.available)
            : _show(_NameStatus.unavailable, result.reason ?? UsernameService.taken);
      } on UsernameException catch (e) {
        if (!mounted || generation != _generation) return;
        _show(_NameStatus.error, e.message);
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _status != _NameStatus.available) return;
    setState(() => _saving = true);
    try {
      final saved = await _service.choose(_controller.text);
      HapticFeedback.mediumImpact();
      if (mounted) widget.onDone(saved);
    } on UsernameException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = e.message == UsernameService.taken ? _NameStatus.unavailable : _NameStatus.error;
        _message = e.message;
      });
    }
  }

  Widget _statusLine() {
    final (icon, color, text) = switch (_status) {
      _NameStatus.available => (CupertinoIcons.checkmark_circle_fill, TrackerColors.accentStartText, "It's yours if you want it"),
      _NameStatus.checking => (CupertinoIcons.time, TrackerColors.textTertiary, 'Checking…'),
      _NameStatus.invalid || _NameStatus.unavailable || _NameStatus.error =>
        (CupertinoIcons.exclamationmark_circle, TrackerColors.warning, _message ?? ''),
      _NameStatus.empty => (null, TrackerColors.textTertiary, '3–20 letters, numbers or underscores'),
    };
    return Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 6)],
        Expanded(child: Text(text, style: AppType.caption(color: color, size: 12.5))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: widget.changing
          ? CupertinoNavigationBar(
              backgroundColor: TrackerColors.navFill,
              border: AppDecor.hairlineTop,
              middle: const Text('Username'),
            )
          : null,
      child: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.changing) ...[
                  const Center(child: AnimatedLogo(size: 96, tile: true, sparks: false)),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Text(
                  widget.changing ? 'Change your username' : 'Pick your username',
                  style: AppType.navLargeTitle(size: 28),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.changing
                      ? "You're @${widget.current} now. Friends keep you on their list and see the new name. "
                          'You can change it once every 30 days.'
                      : 'This is how friends will find you and send you food bites. '
                          'You can change it once every 30 days.',
                  style: AppType.body(color: TrackerColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppField(
                  placeholder: 'username',
                  controller: _controller,
                  icon: CupertinoIcons.at,
                  autofocus: true,
                  keyboardType: TextInputType.visiblePassword, // no autocorrect or suggestions
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
                    LengthLimitingTextInputFormatter(usernameMaxLength),
                  ],
                  onChanged: _onChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedSwitcher(
                  duration: AppMotion.quick,
                  child: KeyedSubtree(key: ValueKey('$_status$_message'), child: _statusLine()),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _saving ? 'Saving…' : (widget.changing ? 'Save' : 'Continue'),
                  onPressed: _status == _NameStatus.available && !_saving ? _save : null,
                ),
                if (widget.onSignOut != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: CupertinoButton(
                      onPressed: widget.onSignOut,
                      child: Text('Sign out', style: AppType.caption(color: TrackerColors.textTertiary, size: 13)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
