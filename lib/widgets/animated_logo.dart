import 'dart:async';
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

  static const _logoAsset = 'assets/logo/logo.webp';
  static const _flameAsset = 'assets/logo/flame.webp';

  /// The picture's own dark backdrop (used behind it when drawn as a tile).
  static const _backdrop = Color(0xFF0C1017);

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
  bool _started = false;
  ImageProvider? _logo;
  ImageProvider? _flame;

  /// Decode at the size it is shown (capped at 2x: phones gain nothing from
  /// more here, and it keeps memory and decode time down).
  ImageProvider _provider(String asset, int width) => ResizeImage(AssetImage(asset), width: width);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dpr = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
    final width = (widget.size * dpr).round();
    _logo = _provider(AnimatedLogo._logoAsset, width);
    _flame = _provider(AnimatedLogo._flameAsset, width);

    if (_reduceMotion) {
      _loop.value = 0.25;
      _intro.value = 1;
      _loop.stop();
      return;
    }
    if (!_loop.isAnimating) _loop.repeat();
    if (!widget.intro) {
      _intro.value = 1;
    } else if (!_started) {
      _started = true;
      _startWhenLoaded();
    }
  }

  /// The entrance only starts once the pictures are ready. On a phone they
  /// arrive over the network, and an animation that ran before then played
  /// out to nothing and the logo just popped in.
  Timer? _fallback;

  void _startWhenLoaded() {
    // If the pictures are slow or fail, play anyway after a while.
    _fallback = Timer(const Duration(seconds: 6), _play);
    Future.wait([
      precacheImage(_logo!, context),
      precacheImage(_flame!, context),
    ]).then((_) => _play(), onError: (_) => _play());
  }

  void _play() {
    _fallback?.cancel();
    if (mounted && _intro.status == AnimationStatus.dismissed) _intro.forward();
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _loop.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    Widget image(ImageProvider provider, Animation<double> opacity) => Image(
      image: provider,
      width: size,
      height: size,
      opacity: opacity,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );

    // Fade by painting the pictures with an alpha, not by wrapping them in
    // Opacity or ShaderMask widgets: those render through offscreen layers
    // every frame, which is what made this stutter on phones.
    final introFade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    Widget base = image(_logo!, introFade);
    if (widget.tile) {
      base = ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: ColoredBox(color: AnimatedLogo._backdrop, child: base),
      );
    }

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

              final flameLayer = Transform(
                alignment: const Alignment(-0.55, 0.55), // the flame's root
                transform: Matrix4.identity()
                  ..rotateZ(sway)
                  ..scaleByDouble(
                    1.0 + 0.012 * math.sin(t * 2),
                    (0.94 + 0.06 * ignite) + 0.018 * math.sin(t * 2 + 0.8),
                    1.0,
                    1.0,
                  ),
                child: image(_flame!, AlwaysStoppedAnimation((flicker * ignite).clamp(0.0, 1.0))),
              );

              return Transform.scale(
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
                                  TrackerColors.alpha(
                                    TrackerColors.accentStart,
                                    (0.22 + 0.12 * breath) * ignite * intro,
                                  ),
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
