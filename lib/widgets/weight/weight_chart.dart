import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../models/weight.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';

/// Weigh-ins as faint dots with the smoothed trend drawn over them as a
/// glowing gradient line. The trend is the honest signal; the dots show the
/// day-to-day noise around it.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.points, required this.unit, this.height = 170});

  final List<WeightPoint> points;
  final WeightUnit unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return SizedBox(height: height);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${points.length}-${points.first.date}-${unit.name}'),
        tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
        duration: AppMotion.slow,
        curve: AppMotion.standard,
        builder: (context, reveal, _) => CustomPaint(
          size: Size.infinite,
          painter: _WeightChartPainter(
            points: points,
            unit: unit,
            reveal: reveal,
            labelStyle: AppType.caption(color: TrackerColors.textTertiary, size: 10),
          ),
        ),
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({
    required this.points,
    required this.unit,
    required this.reveal,
    required this.labelStyle,
  });

  final List<WeightPoint> points;
  final WeightUnit unit;
  final double reveal;
  final TextStyle labelStyle;

  static const _leftGutter = 34.0;
  static const _bottomGutter = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [for (final p in points) ...[unit.fromKg(p.weightKg), unit.fromKg(p.trendKg)]];
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    final pad = math.max((hi - lo) * 0.15, unit == WeightUnit.kg ? 0.6 : 1.3);
    lo -= pad;
    hi += pad;

    final plot = Rect.fromLTRB(_leftGutter, 6, size.width - 6, size.height - _bottomGutter);
    final first = points.first.date;
    final spanDays = math.max(points.last.date.difference(first).inDays, 1);

    Offset at(DateTime date, double kg) {
      final x = points.length == 1
          ? plot.center.dx
          : plot.left + plot.width * date.difference(first).inDays / spanDays;
      final y = plot.bottom - plot.height * (unit.fromKg(kg) - lo) / (hi - lo);
      return Offset(x, y);
    }

    // Grid and y labels.
    final grid = Paint()
      ..color = TrackerColors.alpha(TrackerColors.textPrimary, 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final value = lo + (hi - lo) * (i + 0.5) / 3;
      final y = plot.bottom - plot.height * (value - lo) / (hi - lo);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(canvas, value.toStringAsFixed(0), Offset(0, y - 6), width: _leftGutter - 6, align: TextAlign.right);
    }

    // Date labels.
    _text(canvas, _short(first), Offset(plot.left, plot.bottom + 4), width: 80);
    if (points.length > 1) {
      _text(canvas, _short(points.last.date), Offset(plot.right - 80, plot.bottom + 4),
          width: 80, align: TextAlign.right);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, plot.left + plot.width * reveal + 8, size.height));

    // Weigh-in dots.
    final dot = Paint()..color = TrackerColors.alpha(TrackerColors.textPrimary, 0.28);
    for (final p in points) {
      canvas.drawCircle(at(p.date, p.weightKg), 2.6, dot);
    }

    if (points.length > 1) {
      final trend = [for (final p in points) at(p.date, p.trendKg)];
      final path = _smooth(trend);

      final area = Path.from(path)
        ..lineTo(trend.last.dx, plot.bottom)
        ..lineTo(trend.first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TrackerColors.alpha(TrackerColors.accentStart, 0.22),
              TrackerColors.alpha(TrackerColors.accentStart, 0),
            ],
          ).createShader(plot),
      );
      final shader = TrackerColors.calorieGradient.createShader(plot);
      canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = const Color(0x55FFFFFF),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Latest point.
    final last = at(points.last.date, points.length > 1 ? points.last.trendKg : points.last.weightKg);
    canvas.drawCircle(
      last,
      9,
      Paint()
        ..color = TrackerColors.alpha(TrackerColors.accentEnd, 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(last, 4.5, Paint()..color = TrackerColors.accentEnd);
    canvas.drawCircle(last, 2, Paint()..color = TrackerColors.textPrimary);
    canvas.restore();
  }

  /// A smooth curve through [pts] (Catmull-Rom as cubic Béziers).
  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _text(Canvas canvas, String text, Offset at, {required double width, TextAlign align = TextAlign.left}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);
    painter.paint(canvas, at);
  }

  static String _short(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.points != points || old.unit != unit || old.reveal != reveal;
}
