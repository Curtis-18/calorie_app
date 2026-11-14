import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../models/progress.dart';
import '../../theme/tracker_colors.dart';
import '../game/flame_style.dart';

/// The flame tier a shared streak of [days] has earned: the same tiers as your
/// own daily streak, so a long streak with a friend burns hotter.
FlameTier flameTierForDays(int days) {
  var tier = FlameTier.spark;
  for (final t in FlameTier.values) {
    if (days >= t.minDays) tier = t;
  }
  return tier;
}

/// A painted, flickering flame. Hotter colours and a bigger body as [tier]
/// rises; grey and still while the day is still open ([lit] false).
class FlameMark extends StatefulWidget {
  const FlameMark({super.key, required this.tier, required this.lit, this.size = 20});

  final FlameTier tier;
  final bool lit;

  /// Height of the flame in logical pixels at the smallest tier.
  final double size;

  @override
  State<FlameMark> createState() => _FlameMarkState();
}

class _FlameMarkState extends State<FlameMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(FlameMark old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Flickers only while lit, and not at all when the device asks for less motion.
  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.lit && !still) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A little bigger at each tier, so the flame itself shows how long it has burned.
    final grow = 1 + widget.tier.index * 0.07;
    final height = widget.size * grow;
    final width = height * 0.78;
    final style = FlameStyle.of(widget.tier, dim: !widget.lit);
    return SizedBox(
      width: width * 1.5, // room for the glow and the sway
      height: height * 1.15,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _FlamePainter(
            t: _controller.value,
            gradient: style.gradient,
            glow: widget.lit ? style.glow : 0,
            glowColor: style.color,
            lit: widget.lit,
            tier: widget.tier,
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({
    required this.t,
    required this.gradient,
    required this.glow,
    required this.glowColor,
    required this.lit,
    required this.tier,
  });

  final double t;
  final Gradient gradient;
  final double glow;
  final Color glowColor;
  final bool lit;
  final FlameTier tier;

  /// A flame with a leaning tip and a small tongue licking up the left side,
  /// drawn inside [r]. (A plain teardrop reads as water once it is greyed out.)
  Path _flame(Rect r, double sway) {
    final w = r.width, h = r.height;
    final x = r.left, y = r.top;
    final tipX = x + w * (0.5 + sway * 0.14);
    final tongueX = x + w * (0.16 - sway * 0.05);
    return Path()
      ..moveTo(tipX, y)
      ..cubicTo(x + w * 0.60, y + h * 0.22, x + w, y + h * 0.40, x + w, y + h * 0.66)
      ..cubicTo(x + w, y + h * 0.88, x + w * 0.76, y + h, x + w * 0.5, y + h)
      ..cubicTo(x + w * 0.24, y + h, x, y + h * 0.88, x, y + h * 0.62)
      ..cubicTo(x, y + h * 0.48, x + w * 0.08, y + h * 0.36, tongueX, y + h * 0.24)
      ..cubicTo(x + w * 0.22, y + h * 0.38, x + w * 0.28, y + h * 0.44, x + w * 0.38, y + h * 0.42)
      ..cubicTo(x + w * 0.34, y + h * 0.26, x + w * 0.42, y + h * 0.10, tipX, y)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 1.15;
    final w = h * 0.78;
    // Flicker: the tip sways and the body breathes, out of step with each other.
    final sway = lit ? sin(t * 2 * pi) : 0.0;
    final breathe = lit ? 1 + 0.045 * sin(t * 4 * pi + 1) : 1.0;
    final bodyH = h * breathe;
    final rect = Rect.fromLTWH((size.width - w) / 2, size.height - bodyH, w, bodyH);
    final outer = _flame(rect, sway);

    if (glow > 0) {
      canvas.drawPath(
        outer,
        Paint()
          ..color = glowColor.withValues(alpha: 0.55 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.45),
      );
    }
    canvas.drawPath(outer, Paint()..shader = gradient.createShader(rect));

    // The bright core, nearer the base. Greyed along with the rest when unlit.
    final core = Rect.fromLTWH(
      rect.left + w * 0.27,
      rect.top + bodyH * 0.42,
      w * 0.46,
      bodyH * 0.55,
    );
    canvas.drawPath(
      _flame(core, -sway * 0.8),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: lit
              ? const [Color(0xFFFFF6D6), Color(0xFFFFD060)]
              : const [Color(0x55FFFFFF), Color(0x22FFFFFF)],
        ).createShader(core),
    );
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.t != t || old.lit != lit || old.tier != tier || old.glow != glow || old.gradient != gradient;
}

/// A flame with the streak count, shown on a friend's row. The flame gets
/// hotter as the streak grows; it burns (flickers, glows) once you have both
/// sent today and sits greyed out while the day is still open.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.count, required this.lit, this.compact = false});

  final int count;
  final bool lit;

  /// Smaller, on a solid backing, to sit on the corner of an avatar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tier = flameTierForDays(count);
    final style = FlameStyle.of(tier, dim: !lit);
    final color = style.color;
    return Semantics(
      label: '$count day streak${lit ? '' : ', not kept yet today'}',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('streak_badge'),
        padding: compact ? const EdgeInsets.fromLTRB(3, 1, 6, 1) : const EdgeInsets.fromLTRB(5, 2, 10, 2),
        decoration: BoxDecoration(
          color: compact
              ? Color.alphaBlend(TrackerColors.alpha(color, lit ? 0.18 : 0.10), TrackerColors.background)
              : TrackerColors.alpha(color, lit ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: TrackerColors.alpha(color, lit ? 0.38 : 0.25)),
          boxShadow: lit && style.glow > 0.4
              ? [BoxShadow(color: TrackerColors.alpha(color, 0.22 * style.glow), blurRadius: 12)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlameMark(tier: tier, lit: lit, size: compact ? 12 : 18),
            Text(
              '$count',
              style: AppType.caption(color: color, size: compact ? 11 : 13).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// A burst of embers rising from the bottom of the screen. Plays once.
class EmberBurst extends StatefulWidget {
  const EmberBurst({super.key, this.count = 28, this.onDone});

  final int count;
  final VoidCallback? onDone;

  @override
  State<EmberBurst> createState() => _EmberBurstState();
}

class _EmberBurstState extends State<EmberBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Ember> _embers;

  @override
  void initState() {
    super.initState();
    final random = Random(7);
    _embers = List.generate(widget.count, (_) => _Ember(random));
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _EmberPainter(_embers, _controller.value),
        ),
      ),
    );
  }
}

class _Ember {
  _Ember(Random r)
      : x = r.nextDouble(),
        drift = (r.nextDouble() - 0.5) * 0.25,
        speed = 0.55 + r.nextDouble() * 0.45,
        delay = r.nextDouble() * 0.35,
        size = 3 + r.nextDouble() * 5,
        hue = r.nextDouble();

  final double x, drift, speed, delay, size, hue;
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.embers, this.t);

  final List<_Ember> embers;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in embers) {
      final p = ((t - e.delay) / (1 - e.delay)).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final rise = Curves.easeOut.transform(p) * e.speed;
      final dx = (e.x + e.drift * p) * size.width + sin(p * pi * 3 + e.x * 9) * 8;
      final dy = size.height * (1.02 - rise * 0.95);
      final fade = p < 0.7 ? 1.0 : (1 - p) / 0.3;
      final color = Color.lerp(const Color(0xFFFFB347), const Color(0xFFFF4D2E), e.hue)!;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.9 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(dx, dy), e.size * (1 - p * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => old.t != t;
}

/// Full-screen "streak lit" moment: a flame that pops in with a glow, the
/// count ticking up, and embers rising behind it. Dismisses itself.
Future<void> showStreakCelebration(BuildContext context, {required String username, required int streak}) {
  HapticFeedback.heavyImpact();
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xCC000000),
    builder: (_) => _StreakCelebration(username: username, streak: streak),
  );
}

class _StreakCelebration extends StatefulWidget {
  const _StreakCelebration({required this.username, required this.streak});

  final String username;
  final int streak;

  @override
  State<_StreakCelebration> createState() => _StreakCelebrationState();
}

class _StreakCelebrationState extends State<_StreakCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const EmberBurst(count: 40),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final pop = AppMotion.spring.transform(Curves.easeOut.transform((_controller.value * 1.4).clamp(0, 1)));
                final shown = max(1, (widget.streak * Curves.easeOut.transform(_controller.value)).round());
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.2 + 0.8 * pop,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7A2E).withValues(alpha: 0.55 * pop),
                              blurRadius: 70,
                              spreadRadius: 18,
                            ),
                          ],
                        ),
                        child: FlameMark(tier: flameTierForDays(widget.streak), lit: true, size: 96),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '$shown',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFFFFF),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Text(
                      'day streak with @${widget.username}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFFFFF),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
