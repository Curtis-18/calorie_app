import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'pressable.dart';

enum AppButtonStyle { primary, glass, quiet }

/// 16px-radius action button. [AppButtonStyle.primary] paints the
/// coral -> amber calorie gradient with a matching glow.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.style = AppButtonStyle.primary,
    this.expand = true,
    this.height = 52,
    this.loading = false,
  });

  const AppButton.glass({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.height = 52,
    this.loading = false,
  }) : style = AppButtonStyle.glass;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonStyle style;
  final bool expand;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    final BoxDecoration decoration;
    final Color foreground;

    switch (style) {
      case AppButtonStyle.primary:
        decoration = BoxDecoration(
          gradient: enabled ? TrackerColors.calorieGradient : null,
          color: enabled ? null : TrackerColors.surfaceElevated,
          borderRadius: AppRadii.buttonAll,
          border: enabled ? null : Border.all(color: TrackerColors.border, width: 1),
          boxShadow: enabled ? AppDecor.glow(TrackerColors.accentStart, blur: 22, opacity: 0.3) : null,
        );
        foreground = enabled ? TrackerColors.textPrimary : TrackerColors.textTertiary;
      case AppButtonStyle.glass:
        decoration = BoxDecoration(
          color: TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
          borderRadius: AppRadii.buttonAll,
          border: Border.all(
            color: TrackerColors.alpha(TrackerColors.textPrimary, 0.12),
            width: 1,
          ),
        );
        foreground = TrackerColors.textPrimary;
      case AppButtonStyle.quiet:
        decoration = BoxDecoration(
          color: const Color(0x00000000),
          borderRadius: AppRadii.buttonAll,
        );
        foreground = TrackerColors.accentStart;
    }

    Widget content = AnimatedContainer(
      duration: AppMotion.quick,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: decoration,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            CupertinoActivityIndicator(radius: 9, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (label.isNotEmpty)
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.button(color: foreground).copyWith(letterSpacing: -0.1),
              ),
            ),
        ],
      ),
    );

    content = Pressable(
      onTap: enabled ? onPressed : null,
      dimWhenDisabled: true,
      borderRadius: AppRadii.buttonAll,
      child: content,
    );

    if (!expand) return content;
    return SizedBox(width: double.infinity, child: content);
  }
}

/// 40px glass icon button for headers and card corners.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
    this.iconSize = 18,
    this.color,
    this.background,
    this.glow,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      haptics: true,
      dimWhenDisabled: true,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background ?? TrackerColors.alpha(TrackerColors.textPrimary, 0.07),
          shape: BoxShape.circle,
          border: Border.all(color: TrackerColors.border, width: 1),
          boxShadow: glow == null ? null : AppDecor.glow(glow!, blur: 16, opacity: 0.35),
        ),
        child: Icon(icon, size: iconSize, color: color ?? TrackerColors.textPrimary),
      ),
    );
  }
}

/// Glowing circular action button for quick logging.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 60,
    this.iconSize = 26,
    this.gradient,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Gradient? gradient;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final isGradient = gradient != null;

    return Pressable(
      onTap: onPressed,
      haptics: true,
      dimWhenDisabled: true,
      scale: AppMotion.pressScaleSmall,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient,
          color: isGradient ? null : TrackerColors.surface,
          shape: BoxShape.circle,
          border: isGradient ? null : Border.all(color: TrackerColors.borderStrong, width: 1),
          boxShadow: isGradient
              ? AppDecor.layeredGlow(TrackerColors.accentStart, opacity: 0.38)
              : AppDecor.glow(TrackerColors.textPrimary, blur: 14, opacity: 0.12),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: foreground ?? TrackerColors.textPrimary,
        ),
      ),
    );
  }
}
