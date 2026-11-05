import 'package:flutter/cupertino.dart';

import '../../models/progress.dart';
import '../../theme/tracker_colors.dart';

/// How each streak tier looks. Warmer and brighter as the streak grows.
class FlameStyle {
  const FlameStyle({required this.gradient, required this.color, required this.glow});

  final Gradient gradient;

  /// Solid stand-in for text and small icons.
  final Color color;

  /// Glow strength, 0..1.
  final double glow;

  /// Streak-freeze snowflake colour; follows the mode (deeper blue on white).
  static Color get freezeColor => TrackerColors.freeze;
  static const _infernoRed = Color(0xFFFF3B30);

  /// The style for [tier]. The gradient is always vivid; [color], used for
  /// text and small icons, is deepened on light backgrounds so it stays
  /// readable. Pass [palette] to pin a mode (the share card is always dark).
  static FlameStyle of(FlameTier tier, {bool dim = false, TrackerPalette? palette}) {
    final p = palette ?? TrackerColors.palette;
    final style = _vivid(tier, dim: dim, palette: p);
    if (p.isDark || dim) return style;
    return FlameStyle(gradient: style.gradient, color: _ink(style.color), glow: style.glow);
  }

  /// A darker take on [c] with the same hue, for text on white.
  static Color _ink(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(hsl.lightness.clamp(0.0, 0.38)).toColor();
  }

  static FlameStyle _vivid(FlameTier tier, {required bool dim, required TrackerPalette palette}) {
    if (dim) {
      final p = palette;
      return FlameStyle(
        gradient: LinearGradient(
          colors: [TrackerColors.alpha(p.textSecondary, 0.9), TrackerColors.alpha(p.textSecondary, 0.6)],
        ),
        color: p.textSecondary,
        glow: 0,
      );
    }
    return switch (tier) {
      FlameTier.spark => const FlameStyle(
        gradient: LinearGradient(colors: [Color(0xFFFFB86B), TrackerColors.flameEnd]),
        color: Color(0xFFFFB86B),
        glow: 0.25,
      ),
      FlameTier.ember => const FlameStyle(
        gradient: LinearGradient(colors: [TrackerColors.flameEnd, Color(0xFFFFB340)]),
        color: TrackerColors.flameEnd,
        glow: 0.45,
      ),
      FlameTier.flame => const FlameStyle(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [TrackerColors.flameStart, TrackerColors.flameEnd]),
        color: TrackerColors.flameStart,
        glow: 0.6,
      ),
      FlameTier.blaze => const FlameStyle(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [TrackerColors.flameStart, TrackerColors.flameEnd, Color(0xFFFFD60A)],
        ),
        color: TrackerColors.flameStart,
        glow: 0.8,
      ),
      FlameTier.inferno => const FlameStyle(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_infernoRed, TrackerColors.flameStart, Color(0xFFFFD60A)],
        ),
        color: _infernoRed,
        glow: 1,
      ),
    };
  }
}

/// A flame icon painted with a tier's gradient.
class GradientIcon extends StatelessWidget {
  const GradientIcon(this.icon, {super.key, required this.gradient, this.size = 16, this.glowColor, this.glow = 0});

  final IconData icon;
  final Gradient gradient;
  final double size;
  final Color? glowColor;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Icon(
        icon,
        size: size,
        color: const Color(0xFFFFFFFF),
        shadows: glow > 0 && glowColor != null
            ? [Shadow(color: TrackerColors.alpha(glowColor!, 0.7 * glow), blurRadius: size * 0.7)]
            : null,
      ),
    );
  }
}
