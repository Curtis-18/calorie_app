import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/profile_link.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'pressable.dart';

/// Your profile link in small type with a copy icon beside it. Tapping
/// anywhere on it copies the link, and the icon turns into a tick for a moment.
class ProfileLinkChip extends StatefulWidget {
  const ProfileLinkChip({super.key, required this.username});

  final String username;

  @override
  State<ProfileLinkChip> createState() => _ProfileLinkChipState();
}

class _ProfileLinkChipState extends State<ProfileLinkChip> {
  bool _copied = false;
  Timer? _reset;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: ProfileLink.urlFor(widget.username)));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _copied ? tr('Copied') : tr('Copy link'),
      excludeSemantics: true,
      child: Pressable(
        key: const ValueKey('copy_profile_link'),
        onTap: _copy,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                // Shrinks rather than cutting off the end of the link.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ProfileLink.display(widget.username),
                    key: const ValueKey('my_profile_link'),
                    maxLines: 1,
                    style: AppType.caption(color: TrackerColors.textSecondary, size: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: AppMotion.quick,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                child: Icon(
                  _copied ? CupertinoIcons.checkmark_alt : CupertinoIcons.doc_on_doc,
                  key: ValueKey(_copied),
                  size: 15,
                  color: _copied ? TrackerColors.success : TrackerColors.accentStartText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
