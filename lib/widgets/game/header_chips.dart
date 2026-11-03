import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../models/progress.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../glass.dart';
import '../pressable.dart';
import 'flame_style.dart';

/// Header pill: the streak flame (tinted by tier), the day count and any
/// streak freezes held. Dims when today hasn't been logged yet.
class FlameStreakPill extends StatelessWidget {
  const FlameStreakPill({super.key, required this.streak, this.onTap});

  final StreakInfo streak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final days = streak.current;
    final dim = days == 0 || streak.atRisk;
    final style = FlameStyle.of(streak.tier, dim: days == 0);
    final label = days == 0 ? 'Start a streak' : '$days day${days == 1 ? '' : 's'}';

    return Semantics(
      button: true,
      label: days == 0
          ? 'No streak yet. Open progress.'
          : '$days day streak, ${streak.tier.label}'
              '${streak.atRisk ? ', log today to keep it' : ''}. Open progress.',
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: FrostedGlass(
          opacity: dim ? 0.08 : 0.14,
          tint: dim ? null : style.color,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: TrackerColors.alpha(style.color, dim ? 0.18 : 0.32),
            width: 1,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: streak.atRisk ? 0.55 : 1,
                  child: GradientIcon(
                    CupertinoIcons.flame_fill,
                    gradient: style.gradient,
                    size: 13 + streak.tier.index * 0.75,
                    glowColor: style.color,
                    glow: streak.atRisk ? 0 : style.glow,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: AppType.caption(
                    color: dim ? TrackerColors.textSecondary : style.color,
                    size: 12,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                if (streak.freezes > 0) ...[
                  const SizedBox(width: 6),
                  Icon(CupertinoIcons.snow, size: 11, color: FlameStyle.freezeColor),
                  if (streak.freezes > 1)
                    Text(
                      '${streak.freezes}',
                      style: AppType.caption(color: FlameStyle.freezeColor, size: 11)
                          .copyWith(fontWeight: FontWeight.w800),
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

/// Compact level badge: the level number inside a ring that fills with XP.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.onTap, this.size = 34});

  final LevelInfo level;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Level ${level.level}, ${level.xpIntoLevel} of ${level.xpForLevel} XP. Open progress.',
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: level.fraction),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, fraction, _) => CustomPaint(
              painter: XpRingPainter(fraction: fraction, strokeWidth: 3),
              child: Center(
                child: Text(
                  '${level.level}',
                  style: AppType.caption(color: TrackerColors.textPrimary, size: size * 0.38)
                      .copyWith(fontWeight: FontWeight.w900, height: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular progress ring in the calorie gradient.
class XpRingPainter extends CustomPainter {
  /// Painters read colours while painting; this tells them the mode changed.
  final int _paletteEpoch = TrackerColors.paletteEpoch;

  XpRingPainter({required this.fraction, this.strokeWidth = 3, this.track});

  final double fraction;
  final double strokeWidth;
  final Color? track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(strokeWidth / 2);
    canvas.drawCircle(
      rect.center,
      ring.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track ?? TrackerColors.alpha(TrackerColors.textPrimary, 0.1),
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      ring,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: const [TrackerColors.accentStart, TrackerColors.accentEnd],
        ).createShader(ring),
    );
  }

  @override
  bool shouldRepaint(XpRingPainter old) =>
      old.fraction != fraction || old.track != track || old._paletteEpoch != _paletteEpoch;
}

/// Slim gradient XP bar.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.fraction, this.height = 8, this.track});

  final double fraction;
  final double height;

  /// The empty part of the bar; defaults to a faint wash of the text colour.
  final Color? track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: height,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: track ?? TrackerColors.alpha(TrackerColors.textPrimary, 0.08),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Container(
            width: math.max(height, constraints.maxWidth * value),
            decoration: BoxDecoration(
              gradient: TrackerColors.calorieGradient,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 10, opacity: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
