import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';

/// Circular calorie meter: coral -> amber sweep with a 20px glow, spring
/// animated fill, and a large centred remaining-calorie counter.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 244,
    this.strokeWidth = 18,
    this.showTicks = true,
  });

  final int consumed;
  final int target;
  final double size;
  final double strokeWidth;
  final bool showTicks;

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - consumed).clamp(0, 999999);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: AppMotion.ringFill,
      curve: AppMotion.spring,
      builder: (context, value, _) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.86, end: 1),
          duration: AppMotion.slow,
          curve: AppMotion.spring,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(size, size),
                    painter: _RingPainter(
                      progress: value,
                      strokeWidth: strokeWidth,
                      showTicks: showTicks,
                    ),
                  ),
                  _RingCenter(
                    remaining: remaining,
                    consumed: consumed,
                    target: target,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingCenter extends StatelessWidget {
  const _RingCenter({
    required this.remaining,
    required this.consumed,
    required this.target,
  });

  final int remaining;
  final int consumed;
  final int target;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.standard,
          switchOutCurve: AppMotion.exit,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
          child: Text(
            '$remaining',
            key: ValueKey(remaining),
            style: AppType.display(size: 58),
          ),
        ),
        const SizedBox(height: 2),
        Text('KCAL LEFT', style: AppType.sectionLabel()),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: TrackerColors.border, width: 1),
          ),
          child: Text(
            '$consumed / $target eaten',
            style: AppType.caption(size: 11).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.showTicks,
  });

  final double progress;
  final double strokeWidth;
  final bool showTicks;

  static const double _start = -math.pi / 2; // 12 o'clock
  static const double _sweep = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (showTicks) _paintTicks(canvas, center, radius);

    // Unfilled track.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = TrackerColors.alpha(TrackerColors.textPrimary, 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;

    // Halo: `0 0 20px rgba(255, 94, 58, 0.25)` rendered as a real blur.
    canvas.drawArc(
      rect,
      _start,
      _sweep * progress,
      false,
      Paint()
        ..shader = TrackerColors.calorieSweep.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Filled progress.
    canvas.drawArc(
      rect,
      _start,
      _sweep * progress,
      false,
      Paint()
        ..shader = TrackerColors.calorieSweep.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Glowing head cap.
    final angle = _start + _sweep * progress;
    final cap = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
    canvas.drawCircle(
      cap,
      strokeWidth * 0.5,
      Paint()
        ..color = TrackerColors.textPrimary
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      cap,
      strokeWidth * 0.26,
      Paint()..color = TrackerColors.textPrimary,
    );
  }

  void _paintTicks(Canvas canvas, Offset center, double radius) {
    const tickCount = 48;
    final paint = Paint()
      ..color = TrackerColors.alpha(TrackerColors.textPrimary, 0.14)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < tickCount; i++) {
      final angle = _start + _sweep * (i / tickCount);
      final outer = radius + strokeWidth / 2 + 6;
      final inner = outer - (i % 4 == 0 ? 7 : 4);
      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle), center.dy + inner * math.sin(angle)),
        Offset(center.dx + outer * math.cos(angle), center.dy + outer * math.sin(angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.showTicks != showTicks;
}
