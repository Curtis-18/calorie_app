import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';

/// A small flame with the streak count, shown on a friend's row.
/// Lit (warm) once you've both sent today; dimmer while the day is still open.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.count, required this.lit});

  final int count;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final color = lit ? TrackerColors.flameStart : TrackerColors.textTertiary;
    return Semantics(
      label: '$count day streak',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TrackerColors.alpha(color, 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: TrackerColors.alpha(color, 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(opacity: lit ? 1 : 0.55, child: const Text('🔥', style: TextStyle(fontSize: 13))),
            const SizedBox(width: 3),
            Text('$count', style: AppType.caption(color: color, size: 12.5).copyWith(fontWeight: FontWeight.w800)),
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
                        child: const Text('🔥', style: TextStyle(fontSize: 104, decoration: TextDecoration.none)),
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
