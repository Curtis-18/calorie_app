import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'split_text.dart';

class WelcomeOverlay extends StatefulWidget {
  const WelcomeOverlay({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay> {
  int _step = 0;

  void _next() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: TrackerColors.calorieGradient,
                borderRadius: AppRadii.containerAll,
                boxShadow: AppDecor.layeredGlow(TrackerColors.accentStart, opacity: 0.35),
              ),
              child: const Icon(
                CupertinoIcons.flame_fill,
                size: 40,
                color: TrackerColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (_step == 0)
              SplitText(
                key: const ValueKey(0),
                text: 'Hello, you!',
                style: AppType.display(size: 34, color: TrackerColors.textPrimary),
                onComplete: _next,
              ),
            if (_step == 1)
              SplitText(
                key: const ValueKey(1),
                text: 'Welcome to Calorie Tracker',
                style: AppType.display(size: 30, color: TrackerColors.accentEnd),
                onComplete: _next,
              ),
            if (_step == 2)
              SplitText(
                key: const ValueKey(2),
                text: "Let's get you started.",
                style: AppType.body(size: 18, color: TrackerColors.textSecondary),
                onComplete: _next,
              ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == _step;
                return AnimatedContainer(
                  duration: AppMotion.quick,
                  curve: AppMotion.spring,
                  width: active ? 22 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    gradient: active ? TrackerColors.calorieGradient : null,
                    color: active ? null : TrackerColors.alpha(TrackerColors.textPrimary, 0.18),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
