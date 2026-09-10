import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import '../theme/tracker_colors.dart';

class CalorieRing extends StatelessWidget {
  final int consumed;
  final int target;
  final double width;

  const CalorieRing({
    super.key,
    required this.consumed,
    required this.target,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = target - consumed;
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    const strokeWidth = 14.0;
    final radius = width / 2 - strokeWidth / 2;
    final gaugeHeight = radius + strokeWidth + 4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: gaugeHeight,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              size: Size(width, gaugeHeight),
              painter: _GaugePainter(progress: value),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          remaining >= 0 ? remaining.toString() : '0',
          style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(fontSize: 36),
        ),
        Text(
          'KCAL LEFT',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                color: TrackerColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;

  _GaugePainter({required this.progress});

  static const _strokeWidth = 14.0;
  static const _startAngle = math.pi;
  static const _maxSweep = math.pi;
  static const _progressGradient = SweepGradient(
    startAngle: _startAngle,
    endAngle: _startAngle + _maxSweep,
    colors: [TrackerColors.secondary, TrackerColors.primary],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - _strokeWidth / 2 - 2);
    final radius = size.width / 2 - _strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = TrackerColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _maxSweep, false, trackPaint);

    final glowPaint = Paint()
      ..color = TrackerColors.primary.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth + 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _maxSweep * progress, false, glowPaint);

    final progressPaint = Paint()
      ..shader = _progressGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _maxSweep * progress, false, progressPaint);

    final needleAngle = _startAngle + _maxSweep * progress;
    final needleEnd = Offset(
      center.dx + radius * 0.72 * math.cos(needleAngle),
      center.dy + radius * 0.72 * math.sin(needleAngle),
    );
    final tailEnd = Offset(
      center.dx - radius * 0.16 * math.cos(needleAngle),
      center.dy - radius * 0.16 * math.sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = TrackerColors.primary
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint..strokeWidth = 4);
    canvas.drawLine(center, tailEnd, needlePaint..strokeWidth = 3);

    canvas.drawCircle(center, 8, Paint()..color = TrackerColors.surface);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = TrackerColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}