import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';

/// Pulsing glowing accent ring shown on the splash screen. The ring expands
/// and dissolves exactly as the dashboard ring animates in.
class SplashRing extends StatefulWidget {
  const SplashRing({super.key, this.size = 132, this.dismissing = false});

  final double size;
  final bool dismissing;

  @override
  State<SplashRing> createState() => _SplashRingState();
}

class _SplashRingState extends State<SplashRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.splash,
  );

  late final Animation<double> _pulse = Tween(begin: 0.82, end: 1.06).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant SplashRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dismissing && !_controller.isAnimating) {
      _controller.stop();
      _controller.animateTo(1, duration: AppMotion.medium, curve: AppMotion.standard);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = _pulse.value;
        final scale = widget.dismissing ? 1.35 : pulse;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: TrackerColors.alpha(TrackerColors.accentStart, 0.9), width: 3),
                    boxShadow: AppDecor.layeredGlow(TrackerColors.accentStart, opacity: 0.5),
                  ),
                ),
              ),
              Transform.scale(
                scale: 1 + (pulse - 0.82) * 1.4,
                child: Opacity(
                  opacity: (1.2 - pulse) * 2.4,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: TrackerColors.alpha(TrackerColors.accentEnd, 0.7),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.flame_fill,
                size: widget.size * 0.3,
                color: TrackerColors.accentEnd,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-screen launch surface. Fades out once [visible] flips to false.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: AppMotion.medium,
              curve: AppMotion.standard,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: TrackerColors.background),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SplashRing(dismissing: !visible),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'CALORIE TRACKER',
                        style: AppType.sectionLabel(color: TrackerColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the launch ring until the first real frame (plus a short beat) is
/// painted, then hands off to the app.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child, this.minDuration = AppMotion.splash});

  final Widget child;
  final Duration minDuration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    final startedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = widget.minDuration - elapsed;
      Future<void>.delayed(remaining.isNegative ? Duration.zero : remaining, () {
        if (!mounted) return;
        setState(() => _visible = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppSplash(visible: _visible, child: widget.child);
  }
}
