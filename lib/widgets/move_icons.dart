import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../models/mood.dart';
import '../models/workouts.dart';
import '../theme/tracker_colors.dart';

/// Our own small icon set for the Workouts tab: one consistent line style
/// (round caps, even stroke) drawn on a 24-unit grid, so the page reads as one
/// designed thing instead of a scatter of emoji. Each kind of movement and each
/// feeling has its own glyph.
enum MoveGlyph { strength, cardio, mobility, fun, tired, stressed, low, good, comfort }

extension MoveSliceLook on MoveSlice {
  MoveGlyph get glyph => switch (this) {
        MoveSlice.strength => MoveGlyph.strength,
        MoveSlice.cardio => MoveGlyph.cardio,
        MoveSlice.mobility => MoveGlyph.mobility,
        MoveSlice.fun => MoveGlyph.fun,
      };

  /// Each slice has its own colour, so the plate reads at a glance.
  Color get color => switch (this) {
        MoveSlice.strength => TrackerColors.flameStart,
        MoveSlice.cardio => TrackerColors.accentEndText,
        MoveSlice.mobility => TrackerColors.freeze,
        MoveSlice.fun => TrackerColors.flameEnd,
      };
}

extension MoodLook on Mood {
  MoveGlyph get glyph => switch (this) {
        Mood.tired => MoveGlyph.tired,
        Mood.stressed => MoveGlyph.stressed,
        Mood.low => MoveGlyph.low,
        Mood.good => MoveGlyph.good,
        Mood.comfort => MoveGlyph.comfort,
      };

  Color get color => switch (this) {
        Mood.tired => TrackerColors.freeze,
        Mood.stressed => TrackerColors.flameStart,
        Mood.low => TrackerColors.textSecondary,
        Mood.good => TrackerColors.flameEnd,
        Mood.comfort => TrackerColors.accentEndText,
      };
}

/// A glyph, optionally on a softly tinted rounded tile.
class MoveIcon extends StatelessWidget {
  const MoveIcon(this.glyph, {super.key, this.size = 24, this.color, this.tile = false});

  /// A slice's icon in its own colour.
  MoveIcon.slice(MoveSlice slice, {Key? key, double size = 24, bool tile = false, Color? color})
      : this(slice.glyph, key: key, size: size, tile: tile, color: color ?? slice.color);

  /// A feeling's icon in its own colour.
  MoveIcon.mood(Mood mood, {Key? key, double size = 24, bool tile = false})
      : this(mood.glyph, key: key, size: size, tile: tile, color: mood.color);

  final MoveGlyph glyph;

  /// The icon's own size; a tile is about 1.9 times that.
  final double size;
  final Color? color;
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? TrackerColors.textPrimary;
    final icon = SizedBox(width: size, height: size, child: CustomPaint(painter: _GlyphPainter(glyph, ink)));
    if (!tile) return icon;
    final side = size * 1.9;
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TrackerColors.alpha(ink, 0.14),
        borderRadius: BorderRadius.circular(side * 0.3),
      ),
      child: icon,
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final MoveGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final solid = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    switch (glyph) {
      case MoveGlyph.strength:
        // A dumbbell: bar, inner plates, outer plates.
        canvas.drawLine(const Offset(7, 12), const Offset(17, 12), line);
        final plate = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = color;
        canvas.drawLine(const Offset(7, 7.5), const Offset(7, 16.5), plate);
        canvas.drawLine(const Offset(17, 7.5), const Offset(17, 16.5), plate);
        canvas.drawLine(const Offset(3.6, 9.5), const Offset(3.6, 14.5), plate);
        canvas.drawLine(const Offset(20.4, 9.5), const Offset(20.4, 14.5), plate);
      case MoveGlyph.cardio:
        // A heartbeat line.
        final path = Path()
          ..moveTo(2, 12.5)
          ..lineTo(7, 12.5)
          ..lineTo(9.5, 6)
          ..lineTo(13.5, 19)
          ..lineTo(16, 12.5)
          ..lineTo(22, 12.5);
        canvas.drawPath(path, line);
      case MoveGlyph.mobility:
        // A figure sitting cross-legged with arms lifted.
        canvas.drawCircle(const Offset(12, 5), 2.3, line);
        canvas.drawLine(const Offset(12, 8.4), const Offset(12, 14.5), line);
        canvas.drawLine(const Offset(12, 10), const Offset(6.5, 6.5), line);
        canvas.drawLine(const Offset(12, 10), const Offset(17.5, 6.5), line);
        final legs = Path()
          ..moveTo(5.5, 19.5)
          ..quadraticBezierTo(12, 13.5, 18.5, 19.5);
        canvas.drawPath(legs, line);
      case MoveGlyph.fun:
        // Two beamed music notes.
        canvas.drawCircle(const Offset(7.5, 17.5), 2.5, solid);
        canvas.drawCircle(const Offset(16.5, 15.5), 2.5, solid);
        canvas.drawLine(const Offset(9.9, 17), const Offset(9.9, 6.5), line);
        canvas.drawLine(const Offset(18.9, 15), const Offset(18.9, 4.5), line);
        final beam = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = color;
        canvas.drawLine(const Offset(9.9, 6.8), const Offset(18.9, 4.8), beam);
      case MoveGlyph.tired:
        // A crescent moon.
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.2)),
          Path()..addOval(Rect.fromCircle(center: const Offset(16.2, 9.2), radius: 7)),
        );
        canvas.drawPath(moon, line);
      case MoveGlyph.stressed:
        // Choppy waves.
        for (final y in [8.5, 15.5]) {
          final wave = Path()
            ..moveTo(2.5, y)
            ..quadraticBezierTo(5.25, y - 3.5, 8, y)
            ..quadraticBezierTo(10.75, y + 3.5, 13.5, y)
            ..quadraticBezierTo(16.25, y - 3.5, 19, y)
            ..quadraticBezierTo(20.4, y - 1.8, 21.5, y - 0.6);
          canvas.drawPath(wave, line);
        }
      case MoveGlyph.low:
        // A rain cloud.
        final cloud = Path.combine(
          PathOperation.union,
          Path.combine(
            PathOperation.union,
            Path()..addOval(Rect.fromCircle(center: const Offset(8.3, 11.2), radius: 3.6)),
            Path()..addOval(Rect.fromCircle(center: const Offset(13.2, 9), radius: 4.6)),
          ),
          Path.combine(
            PathOperation.union,
            Path()..addOval(Rect.fromCircle(center: const Offset(17.4, 11.6), radius: 3.3)),
            Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(8.3, 10, 17.4, 14.9), const Radius.circular(3.2))),
          ),
        );
        canvas.drawPath(cloud, line);
        for (final x in [9.0, 13.0, 17.0]) {
          canvas.drawLine(Offset(x, 18), Offset(x - 1.2, 21), line);
        }
      case MoveGlyph.good:
        // A sun.
        canvas.drawCircle(const Offset(12, 12), 4.2, line);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(12 + math.cos(a) * 7.2, 12 + math.sin(a) * 7.2),
            Offset(12 + math.cos(a) * 9.6, 12 + math.sin(a) * 9.6),
            line,
          );
        }
      case MoveGlyph.comfort:
        // A warm mug with steam.
        final body = RRect.fromRectAndCorners(
          const Rect.fromLTRB(4.5, 10, 15.5, 20),
          topLeft: const Radius.circular(1.5),
          topRight: const Radius.circular(1.5),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        );
        canvas.drawRRect(body, line);
        canvas.drawArc(Rect.fromLTRB(13.5, 11.5, 20.5, 17.5), -math.pi / 2, math.pi, false, line);
        for (final x in [8.0, 12.0]) {
          final steam = Path()
            ..moveTo(x, 7.8)
            ..quadraticBezierTo(x - 1.6, 6, x, 4.2)
            ..quadraticBezierTo(x + 1.6, 2.6, x, 1.2);
          canvas.drawPath(steam, line);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}
