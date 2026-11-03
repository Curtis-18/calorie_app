import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import 'animated_logo.dart';
import '../theme/app_typography.dart';

const _splashBackground = Color(0xFF0B0C10);
const _splashText = Color(0xFF8E8E93);

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
                // The launch screen is always the dark brand colour, like the
                // app icon, whichever mode the app is in.
                decoration: const BoxDecoration(color: _splashBackground),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: visible ? 1 : 1.12,
                        duration: AppMotion.medium,
                        curve: AppMotion.standard,
                        child: const AnimatedLogo(size: 220, intro: true),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'NUSTREAK',
                        style: AppType.sectionLabel(color: _splashText),
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
