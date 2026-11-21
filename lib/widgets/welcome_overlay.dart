import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';

/// The first thing a new person sees after choosing a username.
///
/// It is one scene that builds up rather than three screens that replace each
/// other: the flame pops in with a burst of confetti, then "Hello, NAME!",
/// then "Welcome to NuStreak", then a line about what comes next, and last a
/// button. Nothing is timed to disappear, so nobody is rushed: the button is
/// the only way forward. A tap anywhere jumps to the end for people in a hurry,
/// and with "reduce motion" switched on the finished scene is shown at once.
class WelcomeOverlay extends StatefulWidget {
  const WelcomeOverlay({super.key, required this.onFinished, this.name});

  final VoidCallback onFinished;

  /// The username to greet. Without one the greeting stays friendly and general.
  final String? name;

  /// How long the whole build-up takes.
  static const Duration buildUp = Duration(milliseconds: 6400);

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _scene = AnimationController(
    vsync: this,
    duration: WelcomeOverlay.buildUp,
  );
  // Runs forever, slowly: the glow breathes and the background drifts.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat(reverse: true);

  bool _started = false;
  bool _poppedHaptic = false;

  @override
  void initState() {
    super.initState();
    _scene.addListener(() {
      if (!_poppedHaptic && _scene.value >= 0.04) {
        _poppedHaptic = true;
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _scene.value = 1; // reduce motion: the finished scene, no build-up
    } else {
      _scene.forward();
    }
  }

  @override
  void dispose() {
    _scene.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// Slice of the timeline [from]..[to] as its own 0..1 animation.
  Animation<double> _part(
    double from,
    double to, [
    Curve curve = Curves.linear,
  ]) => CurvedAnimation(
    parent: _scene,
    curve: Interval(from, to, curve: curve),
  );

  void _skipAhead() {
    if (_scene.value < 0.86) {
      _scene.animateTo(1, duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name?.trim();
    final greeting = name == null || name.isEmpty
        ? tr('Hello, you!')
        : tr('Hello, {name}!', {'name': name});
    final welcome = tr('Welcome to NuStreak');

    return Semantics(
      container: true,
      label: '$greeting $welcome',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skipAhead,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Drift(animation: _ambient),
            Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FlameBurst(
                      pop: _part(0, 0.2, Curves.elasticOut),
                      burst: _part(0.05, 0.4, Curves.easeOutCubic),
                      glow: _ambient,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _Letters(
                      key: const ValueKey('welcome_hello'),
                      text: greeting,
                      highlight: name,
                      progress: _part(0.22, 0.48),
                      style: AppType.display(
                        size: 34,
                        color: TrackerColors.textPrimary,
                      ),
                      highlightColor: TrackerColors.accentEndText,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Letters(
                      key: const ValueKey('welcome_to'),
                      text: welcome,
                      progress: _part(0.46, 0.68),
                      style: AppType.display(
                        size: 26,
                        color: TrackerColors.accentStartText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _Rise(
                      animation: _part(0.66, 0.82, Curves.easeOutCubic),
                      child: Text(
                        tr("Let's build your plan in a minute."),
                        textAlign: TextAlign.center,
                        style: AppType.body(
                          size: 18,
                          color: TrackerColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    _GoButton(
                      appear: _part(0.8, 0.94, Curves.easeOutBack),
                      pulse: _ambient,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        widget.onFinished();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two soft colour blooms drifting behind the scene.
class _Drift extends StatelessWidget {
  const _Drift({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(animation.value);
          return Stack(
            children: [
              Positioned(
                top: -140 + 50 * t,
                right: -110 + 40 * t,
                child: _bloom(TrackerColors.accentStart, 340, 0.2),
              ),
              Positioned(
                bottom: -170 + 40 * (1 - t),
                left: -130 + 50 * (1 - t),
                child: _bloom(TrackerColors.accentEnd, 360, 0.16),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _bloom(Color color, double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          TrackerColors.alpha(color, opacity),
          TrackerColors.alpha(color, 0),
        ],
      ),
    ),
  );
}

/// The flame tile: springs in, glows, and sends out a burst of confetti.
class _FlameBurst extends StatelessWidget {
  const _FlameBurst({
    required this.pop,
    required this.burst,
    required this.glow,
  });

  final Animation<double> pop;
  final Animation<double> burst;
  final Animation<double> glow;

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: burst,
                builder: (context, _) =>
                    CustomPaint(painter: _ConfettiPainter(burst.value)),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([pop, glow]),
            builder: (context, _) {
              final p = pop.value.clamp(0.0, 1.4);
              final breathe =
                  0.30 + 0.12 * Curves.easeInOut.transform(glow.value);
              return Opacity(
                opacity: p.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: (1 - p.clamp(0.0, 1.0)) * -0.35,
                  child: Transform.scale(
                    scale: p,
                    child: Container(
                      width: _size,
                      height: _size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: TrackerColors.calorieGradient,
                        borderRadius: AppRadii.containerAll,
                        boxShadow: AppDecor.layeredGlow(
                          TrackerColors.accentStart,
                          opacity: breathe,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.flame_fill,
                        size: 44,
                        color: TrackerColors.onAccent,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A one-off burst of little shapes that fly out from the flame, arc down and fade.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static List<_Piece>? _cached;

  static List<_Piece> get _pieces => _cached ??= _make();

  static List<_Piece> _make() {
    final random = math.Random(11);
    final colors = [
      TrackerColors.accentStart,
      TrackerColors.accentEnd,
      TrackerColors.macroProtein,
      TrackerColors.macroCarbs,
      TrackerColors.macroFat,
    ];
    return List.generate(34, (i) {
      final angle = (i / 34) * math.pi * 2 + random.nextDouble() * 0.5;
      return _Piece(
        angle: angle,
        speed: 70 + random.nextDouble() * 70,
        spin: (random.nextDouble() - 0.5) * 8,
        size: 4 + random.nextDouble() * 5,
        color: colors[i % colors.length],
        round: i.isEven,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final fade =
        (1 - Curves.easeIn.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0)));
    for (final p in _pieces) {
      final out = p.speed * t;
      final position =
          center +
          Offset(math.cos(p.angle) * out, math.sin(p.angle) * out + 46 * t * t);
      final paint = Paint()..color = p.color.withValues(alpha: fade * 0.95);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 1.5,
              height: p.size * 0.7,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
  final bool round;
}

/// Text whose letters bounce up one after another. [highlight], when it
/// appears in [text], is drawn in [highlightColor] (the person's name).
class _Letters extends StatelessWidget {
  const _Letters({
    super.key,
    required this.text,
    required this.progress,
    required this.style,
    this.highlight,
    this.highlightColor,
  });

  final String text;
  final Animation<double> progress;
  final TextStyle style;
  final String? highlight;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final chars = text.characters.toList();
    var from = -1;
    var to = -1;
    if (highlight != null && highlight!.isNotEmpty) {
      final at = text.indexOf(highlight!);
      if (at >= 0) {
        // Positions are in characters, not UTF-16 units, so names with
        // accents or emoji line up.
        from = text.substring(0, at).characters.length;
        to = from + highlight!.characters.length;
      }
    }
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final n = chars.length;
        return Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < n; i++)
              Builder(
                builder: (context) {
                  // Each letter starts a little after the one before it.
                  final start = n <= 1 ? 0.0 : (i / n) * 0.6;
                  final local = ((progress.value - start) / 0.4).clamp(
                    0.0,
                    1.0,
                  );
                  final eased = Curves.easeOutBack.transform(local);
                  final highlighted = i >= from && i < to;
                  return Opacity(
                    opacity: Curves.easeOut.transform(local),
                    child: Transform.translate(
                      offset: Offset(0, 22 * (1 - eased)),
                      child: Text(
                        chars[i] == ' ' ? ' ' : chars[i],
                        style: highlighted
                            ? style.copyWith(color: highlightColor)
                            : style,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Fades a child up from slightly below.
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// "Let's go": pops in last and then breathes gently until it is tapped.
class _GoButton extends StatelessWidget {
  const _GoButton({
    required this.appear,
    required this.pulse,
    required this.onPressed,
  });

  final Animation<double> appear;
  final Animation<double> pulse;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appear, pulse]),
      builder: (context, _) {
        final shown = appear.value.clamp(0.0, 1.0);
        final scale =
            (0.6 + 0.4 * appear.value) *
            (1 + 0.02 * Curves.easeInOut.transform(pulse.value) * shown);
        return IgnorePointer(
          ignoring: shown < 0.6,
          child: Opacity(
            opacity: shown,
            child: Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 240,
                child: AppButton(
                  key: const ValueKey('welcome_go'),
                  label: tr("Let's go"),
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
