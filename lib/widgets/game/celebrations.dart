import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../models/progress.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../app_button.dart';
import '../glass.dart';

const _emberColors = [
  TrackerColors.flameStart,
  TrackerColors.flameEnd,
  Color(0xFFFFD60A),
  Color(0xFFFFB86B),
];

/// A one-shot burst of embers from the centre, drifting up as they fade.
class EmberBurst extends StatefulWidget {
  const EmberBurst({super.key, this.particles = 34, this.spread = 1, this.seed = 7, this.onDone});

  final int particles;

  /// Multiplier on how far the embers fly.
  final double spread;
  final int seed;
  final VoidCallback? onDone;

  @override
  State<EmberBurst> createState() => _EmberBurstState();
}

class _EmberBurstState extends State<EmberBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final List<_Ember> _embers;

  @override
  void initState() {
    super.initState();
    final random = math.Random(widget.seed);
    _embers = List.generate(widget.particles, (i) {
      final angle = random.nextDouble() * 2 * math.pi;
      return _Ember(
        direction: Offset(math.cos(angle), math.sin(angle)),
        speed: 0.55 + random.nextDouble() * 0.45,
        size: 2.5 + random.nextDouble() * 4,
        color: _emberColors[i % _emberColors.length],
        delay: random.nextDouble() * 0.15,
      );
    });
    _controller.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _BurstPainter(_embers, _controller.value, widget.spread),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Ember {
  const _Ember({
    required this.direction,
    required this.speed,
    required this.size,
    required this.color,
    required this.delay,
  });

  final Offset direction;
  final double speed;
  final double size;
  final Color color;
  final double delay;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.embers, this.t, this.spread);

  final List<_Ember> embers;
  final double t;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final reach = size.shortestSide * 0.5 * spread;
    for (final e in embers) {
      final local = ((t - e.delay) / (1 - e.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final travel = Curves.easeOutCubic.transform(local) * reach * e.speed;
      final rise = -reach * 0.25 * local * local; // embers float upward
      final p = center + e.direction * travel + Offset(0, rise);
      final fade = 1 - Curves.easeIn.transform(local);
      final radius = e.size * (1 - 0.5 * local);
      canvas.drawCircle(
        p,
        radius * 2.4,
        Paint()
          ..color = TrackerColors.alpha(e.color, 0.25 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.6),
      );
      canvas.drawCircle(p, radius, Paint()..color = TrackerColors.alpha(e.color, fade));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// Burst embers over [target] (the calorie ring) with a rising "Perfect day"
/// chip. Non-blocking: the user can keep using the app.
void showPerfectDayBurst(BuildContext context, GlobalKey target) {
  final box = target.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached) return;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  HapticFeedback.heavyImpact();

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned.fromRect(
      rect: rect.inflate(40),
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: EmberBurst(
                particles: 46,
                spread: 1.15,
                onDone: () {
                  if (entry.mounted) entry.remove();
                },
              ),
            ),
            const _RisingChip(label: 'Perfect day', detail: '+30 XP'),
          ],
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

class _RisingChip extends StatelessWidget {
  const _RisingChip({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, t, child) {
        final appear = Curves.easeOutBack.transform((t / 0.3).clamp(0.0, 1.0));
        final fade = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
        return Transform.translate(
          offset: Offset(0, -40 * Curves.easeOut.transform(t)),
          child: Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.6 + 0.4 * appear, child: child),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: TrackerColors.calorieGradient,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppDecor.layeredGlow(TrackerColors.accentStart, opacity: 0.45),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.flame_fill, size: 15, color: TrackerColors.onAccent),
            const SizedBox(width: 6),
            Text(label, style: AppType.button(color: TrackerColors.onAccent, size: 15)),
            const SizedBox(width: 8),
            Text(
              detail,
              style: AppType.caption(color: TrackerColors.alpha(TrackerColors.onAccent, 0.85), size: 12)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen reveal for a new badge or level. Resolves when dismissed.
Future<void> showCelebrationCard(BuildContext context, Celebration celebration) {
  if (celebration is PerfectDayCelebration) return Future.value();
  HapticFeedback.mediumImpact();
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xCC000000),
    builder: (_) => _CelebrationCard(celebration: celebration),
  );
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.celebration});

  final Celebration celebration;

  @override
  Widget build(BuildContext context) {
    final (eyebrow, title, body, badge) = switch (celebration) {
      AchievementCelebration(:final achievement) => (
          'BADGE UNLOCKED',
          achievement.title,
          achievement.description,
          Icon(achievement.icon, size: 44, color: TrackerColors.onAccent) as Widget,
        ),
      LevelUpCelebration(:final level) => (
          'LEVEL UP',
          'Level $level',
          'Every meal you log earns XP. Keep it going to reach level ${level + 1}.',
          Text('$level', style: AppType.display(size: 44)) as Widget,
        ),
      PerfectDayCelebration() => ('', '', '', const SizedBox() as Widget),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.slow,
            curve: AppMotion.spring,
            builder: (context, t, child) => Transform.scale(scale: 0.85 + 0.15 * t, child: child),
            child: FrostedGlass(
              // Light mode needs a solid card: 12% white over the dark scrim is
              // a dark card, and the dark text on it can't be read.
              opacity: TrackerColors.isDark ? 0.12 : 0.97,
              tint: TrackerColors.surface,
              borderRadius: AppRadii.containerAll,
              border: Border.all(color: TrackerColors.borderStrong, width: 1),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 200,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned.fill(child: EmberBurst(particles: 40, spread: 1.3, seed: 11)),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.2, end: 1),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.elasticOut,
                          builder: (context, s, child) => Transform.scale(scale: s, child: child),
                          child: Container(
                            width: 104,
                            height: 104,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: TrackerColors.calorieGradient,
                              border: Border.all(
                                color: TrackerColors.alpha(TrackerColors.onAccent, 0.25),
                                width: 2,
                              ),
                              boxShadow: AppDecor.layeredGlow(TrackerColors.accentStart, opacity: 0.5),
                            ),
                            child: badge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    eyebrow,
                    style: AppType.sectionLabel(color: TrackerColors.accentEndText).copyWith(letterSpacing: 1.6),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(title, textAlign: TextAlign.center, style: AppType.display(size: 28)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: AppType.body(color: TrackerColors.textSecondary).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(label: 'Nice!', onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
