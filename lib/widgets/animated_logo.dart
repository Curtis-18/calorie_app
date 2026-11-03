import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/tracker_colors.dart';

/// The NuStreak apple-and-flame, alive: the flame sways and flickers, a soft
/// glow breathes behind it, and sparks drift up.
///
/// Built from two images (the whole logo, and the flame cut out of it), so
/// the only moving parts are cheap transforms plus a handful of dots. Images
/// are decoded at display size, so it costs about 1 MB, and nothing runs when
/// the platform asks for reduced motion.
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key, this.size = 200, this.intro = false, this.sparks = true, this.tile = false});

  final double size;

  /// Play the ignite-into-place entrance (the launch screen). Otherwise it
  /// is simply there, and loops.
  final bool intro;

  /// Drifting sparks. Switch off for small or busy spots.
  final bool sparks;

  /// Draw it as a rounded dark tile, like the app icon. Needed on screens
  /// whose background isn't the dark brand colour (the image has its own).
  final bool tile;

  static const _logoAsset = 'assets/logo/logo.png';
  static const _flameAsset = 'assets/logo/flame.png';

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _loop.value = 0.25;
      _intro.value = 1;
      _loop.stop();
    } else {
      if (!_loop.isAnimating) _loop.repeat();
      if (widget.intro) {
        if (_intro.status == AnimationStatus.dismissed) _intro.forward();
      } else {
        _intro.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    Widget image(String asset) => Image.asset(
      asset,
      width: size,
      height: size,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    Widget base = image(AnimatedLogo._logoAsset);
    base = widget.tile
        ? ClipRRect(borderRadius: BorderRadius.circular(size * 0.22), child: base)
        // Fade the picture's own dark backdrop into the screen's.
        : ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const RadialGradient(
              radius: 0.5,
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
              stops: [0, 0.72, 1],
            ).createShader(rect),
            child: base,
          );

    final flame = image(AnimatedLogo._flameAsset);

    return Semantics(
      label: 'NuStreak',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_loop, _intro]),
            builder: (context, _) {
              final t = _loop.value * 2 * math.pi;
              final intro = Curves.easeOutCubic.transform(_intro.value);
              // The flame lights a beat after the apple appears.
              final ignite = Curves.easeOut.transform(((_intro.value - 0.25) / 0.75).clamp(0.0, 1.0));

              final sway = math.sin(t) * 0.018 + math.sin(t * 3) * 0.006;
              final flicker = 0.93 + 0.07 * math.sin(t * 2 + 1) * math.sin(t * 5);
              final breath = 0.5 + 0.5 * math.sin(t);

              Widget flameLayer = Transform(
                alignment: const Alignment(-0.55, 0.55), // the flame's root
                transform: Matrix4.identity()
                  ..rotateZ(sway)
                  ..scaleByDouble(
                    1.0 + 0.012 * math.sin(t * 2),
                    (0.94 + 0.06 * ignite) + 0.018 * math.sin(t * 2 + 0.8),
                    1.0,
                    1.0,
                  ),
                child: flame,
              );
              flameLayer = Opacity(opacity: (flicker * ignite).clamp(0.0, 1.0), child: flameLayer);

              return Opacity(
                opacity: intro.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.86 + 0.14 * intro,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Warm glow, breathing. (The tile is self-contained.)
                      if (!widget.tile)
                        Positioned.fill(
                          child: Transform.scale(
                            scale: 1.05 + 0.06 * breath,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0.2, -0.1),
                                  radius: 0.42,
                                  colors: [
                                    TrackerColors.alpha(TrackerColors.accentStart, (0.22 + 0.12 * breath) * ignite),
                                    TrackerColors.alpha(TrackerColors.accentStart, 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      base,
                      flameLayer,
                      if (widget.sparks && !_reduceMotion)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SparkPainter(progress: _loop.value, strength: ignite),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A few embers rising off the flame. Positions are fractions of the logo.
class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.progress, required this.strength});

  final double progress;
  final double strength;

  // x, y (start), speed multiplier, phase offset
  static const _seeds = [
    (0.80, 0.30, 1.0, 0.00),
    (0.70, 0.38, 0.8, 0.13),
    (0.84, 0.22, 1.2, 0.27),
    (0.62, 0.46, 0.9, 0.41),
    (0.88, 0.38, 1.1, 0.55),
    (0.74, 0.18, 0.7, 0.68),
    (0.56, 0.54, 1.0, 0.80),
    (0.86, 0.28, 0.9, 0.91),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint();
    final core = Paint();
    for (final (x, y, speed, phase) in _seeds) {
      final p = (progress * speed + phase) % 1.0;
      final alpha = math.sin(p * math.pi) * strength;
      if (alpha <= 0.02) continue;
      final dx = x * size.width + math.sin(p * 6 + phase * 9) * size.width * 0.012 + p * size.width * 0.05;
      final dy = y * size.height - p * size.height * 0.24;
      final r = size.width * 0.011 * (1.15 - p * 0.6);
      final c = Color.lerp(TrackerColors.accentEnd, const Color(0xFFFFD27A), 1 - p)!;
      glow.color = c.withValues(alpha: alpha * 0.28);
      core.color = c.withValues(alpha: alpha * 0.95);
      canvas.drawCircle(Offset(dx, dy), r * 2.4, glow);
      canvas.drawCircle(Offset(dx, dy), r, core);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.progress != progress || old.strength != strength;
}
