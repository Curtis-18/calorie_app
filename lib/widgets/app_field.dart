import 'package:flutter/cupertino.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';

/// Dark pill-style text field with a leading icon.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.placeholder,
    this.controller,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.autofocus = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  });

  final String placeholder;
  final TextEditingController? controller;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final bool autofocus;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      placeholderStyle: AppType.body(size: 15, color: TrackerColors.textTertiary),
      style: AppType.body(size: 15),
      cursorColor: TrackerColors.accentStart,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofocus: autofocus,
      padding: padding,
      suffix: suffix == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 12),
              child: suffix,
            ),
      prefix: icon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(icon, size: 17, color: TrackerColors.textTertiary),
            ),
      decoration: BoxDecoration(
        color: TrackerColors.surfaceElevated,
        borderRadius: AppRadii.buttonAll,
        border: Border.all(color: TrackerColors.border, width: 1),
      ),
    );
  }
}

/// Ambient gradient wash with soft accent blooms behind a screen.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: TrackerColors.background),
      child: Stack(
        children: [
          const Positioned(top: -120, right: -80, child: _Bloom(color: TrackerColors.accentStart, size: 300)),
          const Positioned(bottom: -160, left: -110, child: _Bloom(color: TrackerColors.accentEnd, size: 320)),
          child,
        ],
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [TrackerColors.alpha(color, 0.18), TrackerColors.alpha(color, 0)],
          ),
        ),
      ),
    );
  }
}
