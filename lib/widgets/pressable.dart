import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../theme/app_motion.dart';

/// Touch feedback wrapper: scales its child down while held
/// (the Flutter equivalent of `active:scale-95`) over 150ms.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = AppMotion.pressScale,
    this.behavior = HitTestBehavior.opaque,
    this.haptics = false,
    this.dimWhenDisabled = false,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final HitTestBehavior behavior;
  final bool haptics;
  final bool dimWhenDisabled;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final child = GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptics) HapticFeedback.lightImpact();
              widget.onTap!.call();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed && enabled ? widget.scale : 1,
        duration: AppMotion.press,
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        child: AnimatedOpacity(
          opacity: enabled || !widget.dimWhenDisabled ? 1 : 0.45,
          duration: AppMotion.quick,
          child: widget.child,
        ),
      ),
    );

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }
}
