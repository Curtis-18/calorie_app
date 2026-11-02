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

  static const freezeColor = Color(0xFF64D2FF);
  static const _infernoRed = Color(0xFFFF3B30);

  static FlameStyle of(FlameTier tier, {bool dim = false}) {
    if (dim) {
      return FlameStyle(
        gradient: LinearGradient(colors: [
          TrackerColors.alpha(TrackerColors.textSecondary, 0.9),
          TrackerColors.alpha(TrackerColors.textSecondary, 0.6),
        ]),
        color: TrackerColors.textSecondary,
        glow: 0,
      );
    }
    return switch (tier) {
      FlameTier.spark => const FlameStyle(
          gradient: LinearGradient(colors: [Color(0xFFFFB86B), TrackerColors.accentEnd]),
          color: Color(0xFFFFB86B),
          glow: 0.25,
        ),
      FlameTier.ember => const FlameStyle(
          gradient: LinearGradient(colors: [TrackerColors.accentEnd, Color(0xFFFFB340)]),
          color: TrackerColors.accentEnd,
          glow: 0.45,
        ),
      FlameTier.flame => const FlameStyle(
          gradient: TrackerColors.calorieGradient,
          color: TrackerColors.accentStart,
          glow: 0.6,
        ),
      FlameTier.blaze => const FlameStyle(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [TrackerColors.accentStart, TrackerColors.accentEnd, Color(0xFFFFD60A)],
          ),
          color: TrackerColors.accentStart,
          glow: 0.8,
        ),
      FlameTier.inferno => const FlameStyle(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [_infernoRed, TrackerColors.accentStart, Color(0xFFFFD60A)],
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
