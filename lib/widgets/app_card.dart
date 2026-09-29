import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'pressable.dart';

/// Primary surface container: #16181F, 1px rgba(255,255,255,0.08), 28px squircle.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
    this.gradient,
    this.borderRadius,
    this.border,
    this.shadow,
    this.onTap,
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? shadow;
  final VoidCallback? onTap;

  /// Accent colour used to build a soft outer glow.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadii.containerAll;

    Widget surface = AnimatedContainer(
      duration: AppMotion.quick,
      width: double.infinity,
      padding: padding,
      decoration: AppDecor.card(
        color: color,
        gradient: gradient,
        borderRadius: radius,
        border: border,
        shadow: shadow ?? (glow != null ? AppDecor.glow(glow!, blur: 24, opacity: 0.18) : null),
      ),
      child: child,
    );

    if (onTap != null) {
      surface = Pressable(
        onTap: onTap,
        haptics: true,
        borderRadius: radius,
        child: surface,
      );
    }

    if (margin != null) {
      surface = Padding(padding: margin!, child: surface);
    }
    return surface;
  }
}

/// Small rounded tag, e.g. the calorie pill on a food row.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.color = TrackerColors.accentStart,
    this.icon,
    this.filled = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(color, filled ? 0.9 : 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: TrackerColors.alpha(color, filled ? 0 : 0.28),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: filled ? TrackerColors.background : color),
            SizedBox(width: dense ? 4 : 5),
          ],
          Text(
            label,
            style: AppType.caption(
              color: filled ? TrackerColors.background : color,
              size: dense ? 11 : 12,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Hairline divider tuned for the dark surface.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0, this.opacity = 1});

  final double indent;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Container(height: 1, color: TrackerColors.alpha(TrackerColors.border, opacity)),
    );
  }
}

/// All-caps section eyebrow, e.g. "TODAY'S MEALS".
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: AppType.sectionLabel()),
        const SizedBox(width: AppSpacing.md),
        const Expanded(child: AppDivider()),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
      ],
    );
  }
}
