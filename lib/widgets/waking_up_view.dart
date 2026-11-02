import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'app_field.dart' show AppBackdrop;
import 'glass.dart';

/// Shown while the backend boots after a cold start.
///
/// Render's free tier sleeps after ~15 idle minutes and takes 30-60 s to wake.
/// A bare spinner for that long reads as "broken", so this explains what's
/// happening, shows honest progress, and gives the user something to read.
class WakingUpView extends StatefulWidget {
  const WakingUpView({super.key, required this.startedAt});

  /// When the connection attempt began; drives the timer and progress bar.
  final DateTime startedAt;

  static const tips = [
    'Snap a photo of your plate to log a whole meal in seconds.',
    'Use the arrows next to the date to look back at earlier days.',
    'Insights turns your week into a few simple, personal tips.',
    'Logging as you eat keeps the ring accurate all day.',
  ];

  /// Headline for how long we've been waiting.
  static String titleFor(Duration elapsed) {
    if (elapsed < const Duration(seconds: 15)) return 'Waking up the server';
    if (elapsed < const Duration(seconds: 40)) return 'Warming things up';
    return 'Almost there';
  }

  /// Eases toward 94% so the bar never claims "done" before the server is.
  static double progressFor(Duration elapsed) =>
      0.94 * (1 - math.exp(-elapsed.inMilliseconds / 22000));

  @override
  State<WakingUpView> createState() => _WakingUpViewState();
}

class _WakingUpViewState extends State<WakingUpView> with SingleTickerProviderStateMixin {
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final Timer _clock;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startedAt);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(widget.startedAt));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _orbit.stop();
    } else if (!_orbit.isAnimating) {
      _orbit.repeat();
    }
  }

  @override
  void dispose() {
    _clock.cancel();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final title = WakingUpView.titleFor(_elapsed);
    final seconds = _elapsed.inSeconds;
    final tip = WakingUpView.tips[(seconds ~/ 7) % WakingUpView.tips.length];

    return CupertinoPageScaffold(
      child: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Semantics(
                  label: 'Connecting to the server',
                  child: _Ember(animation: _orbit, reduceMotion: reduceMotion),
                ),
                const SizedBox(height: 40),
                AnimatedSwitcher(
                  duration: AppMotion.medium,
                  switchInCurve: AppMotion.standard,
                  child: Text(
                    title,
                    key: ValueKey(title),
                    textAlign: TextAlign.center,
                    style: AppType.display(size: 28),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    "Our server naps when it's quiet. The first load can take up "
                    "to a minute, and after that everything's quick.",
                    textAlign: TextAlign.center,
                    style: AppType.body(color: TrackerColors.textSecondary).copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 32),
                _ProgressBar(value: WakingUpView.progressFor(_elapsed), animate: !reduceMotion),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${seconds}s · usually under a minute',
                  style: AppType.caption(color: TrackerColors.textTertiary),
                ),
                const Spacer(flex: 2),
                AnimatedSwitcher(
                  duration: AppMotion.slow,
                  child: _TipCard(key: ValueKey(tip), tip: tip),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient badge with an arc orbiting it and a slow breathing glow.
class _Ember extends StatelessWidget {
  const _Ember({required this.animation, required this.reduceMotion});

  final Animation<double> animation;
  final bool reduceMotion;

  static const _size = 172.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = reduceMotion ? 0.0 : animation.value;
        final breath = reduceMotion ? 0.5 : 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        return SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: _size * 0.62,
                height: _size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppDecor.glow(
                    TrackerColors.accentStart,
                    blur: 50 + 20 * breath,
                    opacity: 0.22 + 0.12 * breath,
                  ),
                ),
              ),
              CustomPaint(
                size: const Size.square(_size),
                painter: _OrbitPainter(rotation: t),
              ),
              Transform.scale(
                scale: 0.97 + 0.03 * breath,
                child: Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: TrackerColors.calorieGradient,
                    borderRadius: AppRadii.containerAll,
                    boxShadow: AppDecor.layeredGlow(TrackerColors.accentStart, opacity: 0.35),
                  ),
                  child: const Icon(
                    CupertinoIcons.flame_fill,
                    size: 38,
                    color: TrackerColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.rotation});

  /// 0..1 of a full turn.
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
    );

    const sweep = math.pi * 0.62;
    final start = rotation * 2 * math.pi - math.pi / 2;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [
          TrackerColors.alpha(TrackerColors.accentStart, 0),
          TrackerColors.accentStart,
          TrackerColors.accentEnd,
        ],
        stops: const [0, 0.6, 1],
        transform: GradientRotation(start),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, arcPaint);

    final head = center + Offset(math.cos(start + sweep), math.sin(start + sweep)) * radius;
    canvas.drawCircle(
      head,
      7,
      Paint()
        ..color = TrackerColors.alpha(TrackerColors.accentEnd, 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(head, 3.5, Paint()..color = TrackerColors.accentEnd);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.rotation != rotation;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.animate});

  final double value;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    const width = 220.0;
    return Container(
      width: width,
      height: 6,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: TrackerColors.alpha(TrackerColors.textPrimary, 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: AnimatedContainer(
        duration: animate ? const Duration(seconds: 1) : Duration.zero,
        curve: Curves.linear,
        width: width * value.clamp(0.02, 1.0),
        decoration: BoxDecoration(
          gradient: TrackerColors.calorieGradient,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 10, opacity: 0.4),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({super.key, required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      opacity: 0.06,
      borderRadius: AppRadii.buttonAll,
      border: Border.all(color: TrackerColors.border, width: 1),
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
      child: Row(
        children: [
          const Icon(CupertinoIcons.lightbulb_fill, size: 18, color: TrackerColors.accentEnd),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              tip,
              style: AppType.callout(color: TrackerColors.textSecondary).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the server still hasn't answered after the full wait.
class ServerUnreachableView extends StatelessWidget {
  const ServerUnreachableView({super.key, required this.onRetry, required this.onSignOut});

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TrackerColors.alpha(TrackerColors.error, 0.12),
                    borderRadius: AppRadii.containerAll,
                    border: Border.all(color: TrackerColors.alpha(TrackerColors.error, 0.3)),
                  ),
                  child: const Icon(CupertinoIcons.wifi_exclamationmark, size: 36, color: TrackerColors.error),
                ),
                const SizedBox(height: 32),
                Text(
                  "Couldn't reach the server",
                  textAlign: TextAlign.center,
                  style: AppType.display(size: 26),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    "It may still be starting up, or your connection dropped. "
                    'Check your connection, then try again.',
                    textAlign: TextAlign.center,
                    style: AppType.body(color: TrackerColors.textSecondary).copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 32),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: AppButton(label: 'Try again', icon: CupertinoIcons.refresh, onPressed: onRetry),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Sign out',
                  style: AppButtonStyle.quiet,
                  expand: false,
                  height: 44,
                  onPressed: onSignOut,
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
