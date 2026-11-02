import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';

enum TourShape { circle, roundedRect, pill }

/// How a tour ended. A system back press counts as [skipped].
enum TourResult { finished, skipped }

/// One spotlighted element of an [AppTour].
class TourStep {
  const TourStep({
    required this.targetKey,
    required this.title,
    required this.body,
    required this.icon,
    this.shape = TourShape.roundedRect,
    this.radius = AppRadii.container,
    this.padding = 8,
  });

  /// Key on the widget to spotlight. Steps whose target is not on screen
  /// when the tour reaches them are skipped rather than pointing at nothing.
  final GlobalKey targetKey;
  final String title;
  final String body;
  final IconData icon;
  final TourShape shape;

  /// Corner radius of the cutout for [TourShape.roundedRect].
  final double radius;

  /// Breathing room between the target and the cutout edge.
  final double padding;
}

/// A guided spotlight tour built from the app's own design system.
///
/// Replaces `tutorial_coach_mark`, whose loose white text, unlabeled
/// "tap the dark area to continue" interaction and corner Skip label (which
/// sat on top of the Dashboard tab) didn't fit the app.
///
/// Shown as a route on the root navigator, so it covers the tab bar, blocks
/// interaction underneath, and the Android back button dismisses it.
class AppTour {
  AppTour._();

  static Future<TourResult> show(BuildContext context, {required List<TourStep> steps}) async {
    final result = await Navigator.of(context, rootNavigator: true).push<TourResult>(
      _TourRoute(steps: steps),
    );
    return result ?? TourResult.skipped;
  }
}

class _TourRoute extends PopupRoute<TourResult> {
  _TourRoute({required this.steps});

  final List<TourStep> steps;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => AppMotion.medium;

  @override
  Duration get reverseTransitionDuration => AppMotion.quick;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _TourOverlay(steps: steps);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.standard, reverseCurve: AppMotion.exit),
      child: child,
    );
  }
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({required this.steps});

  final List<TourStep> steps;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this, duration: AppMotion.sheet);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  /// Indices of [TourStep]s whose targets were on screen at the start.
  late final List<int> _visible;
  int _position = 0;
  _Hole? _from;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _visible = [
      for (var i = 0; i < widget.steps.length; i++)
        if (_targetRect(widget.steps[i]) != null) i,
    ];
    if (_visible.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close(TourResult.finished));
    } else {
      _move.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _pulse.dispose();
    super.dispose();
  }

  TourStep get _step => widget.steps[_visible[_position]];
  bool get _isLast => _position == _visible.length - 1;

  static Rect? _targetRect(TourStep step) {
    final object = step.targetKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) return null;
    return object.localToGlobal(Offset.zero) & object.size;
  }

  _Hole? _holeFor(TourStep step) {
    final rect = _targetRect(step);
    if (rect == null) return null;
    final inflated = rect.inflate(step.padding);
    if (step.shape == TourShape.circle) {
      final side = math.max(inflated.width, inflated.height);
      return _Hole(Rect.fromCenter(center: rect.center, width: side, height: side), side / 2);
    }
    if (step.shape == TourShape.pill) {
      return _Hole(inflated, inflated.shortestSide / 2);
    }
    return _Hole(inflated, step.radius + step.padding);
  }

  void _next() {
    if (_closing) return;
    HapticFeedback.selectionClick();
    // Skip any later step whose target has since left the screen.
    var nextPosition = _position + 1;
    while (nextPosition < _visible.length && _targetRect(widget.steps[_visible[nextPosition]]) == null) {
      nextPosition++;
    }
    if (nextPosition >= _visible.length) {
      _close(TourResult.finished);
      return;
    }
    setState(() {
      _from = _holeFor(_step);
      _position = nextPosition;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _move.value = 1;
    } else {
      _move.forward(from: 0);
    }
  }

  void _close(TourResult result) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_visible.isEmpty) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final target = _holeFor(_step);
    // Target vanished mid-tour (e.g. layout change): end quietly.
    if (target == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close(TourResult.finished));
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_move, _pulse]),
      builder: (context, _) {
        final t = AppMotion.standard.transform(_move.value);
        final hole = _from == null ? target : _Hole.lerp(_from!, target, t);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _next,
                child: CustomPaint(
                  painter: _ScrimPainter(
                    hole: hole,
                    pulse: MediaQuery.disableAnimationsOf(context) ? null : _pulse.value,
                  ),
                ),
              ),
            ),
            _placeCard(media, target),
          ],
        );
      },
    );
  }

  /// Puts the card on whichever side of the target has more room, inside the
  /// safe area, so it never covers the thing it is describing.
  Widget _placeCard(MediaQueryData media, _Hole target) {
    const gap = 18.0;
    const side = 20.0;
    final top = media.padding.top + 12;
    final bottom = media.size.height - media.padding.bottom - 12;
    final spaceAbove = target.rect.top - gap - top;
    final spaceBelow = bottom - (target.rect.bottom + gap);
    final below = spaceBelow >= spaceAbove;

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.medium,
        // Staggered rather than a straight cross-fade: the outgoing card is
        // gone in the first 40% and the incoming one starts at 40%, so the two
        // cards' text never shows on top of each other mid-switch.
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(_position);
          final curved = CurvedAnimation(
            parent: animation,
            curve: incoming
                ? const Interval(0.4, 1, curve: AppMotion.standard)
                : const Interval(0.6, 1),
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, below ? 0.06 : -0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        layoutBuilder: (current, previous) => Stack(
          alignment: below ? Alignment.topCenter : Alignment.bottomCenter,
          children: [...previous, ?current],
        ),
        child: _TourCard(
          key: ValueKey(_position),
          step: _step,
          index: _position,
          count: _visible.length,
          isLast: _isLast,
          onNext: _next,
          onSkip: () => _close(TourResult.skipped),
        ),
      ),
    );

    return Positioned(
      left: side,
      right: side,
      top: below ? math.min(target.rect.bottom + gap, bottom) : null,
      bottom: below ? null : math.max(media.size.height - (target.rect.top - gap), media.size.height - bottom),
      child: Align(
        alignment: below ? Alignment.topCenter : Alignment.bottomCenter,
        child: card,
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final TourStep step;
  final int index;
  final int count;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Step ${index + 1} of $count',
      // Swallow taps on the card so they don't fall through to the scrim.
      child: GestureDetector(
        onTap: () {},
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadii.containerAll,
            boxShadow: AppDecor.glow(const Color(0xFF000000), blur: 40, opacity: 0.5),
          ),
          child: FrostedGlass(
            opacity: 0.1,
            tint: TrackerColors.surface,
            borderRadius: AppRadii.containerAll,
            border: Border.all(color: TrackerColors.borderStrong, width: 1),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: TrackerColors.calorieGradient,
                        borderRadius: BorderRadius.circular(AppRadii.small),
                        boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 14, opacity: 0.35),
                      ),
                      child: Icon(step.icon, size: 18, color: TrackerColors.textPrimary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(step.title, style: AppType.headline())),
                    Text('${index + 1} / $count', style: AppType.caption(color: TrackerColors.textTertiary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  step.body,
                  style: AppType.body(color: TrackerColors.textSecondary).copyWith(height: 1.45),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    _Dots(index: index, count: count),
                    const Spacer(),
                    if (!isLast)
                      AppButton(
                        label: 'Skip',
                        style: AppButtonStyle.quiet,
                        expand: false,
                        height: 40,
                        onPressed: onSkip,
                      ),
                    const SizedBox(width: AppSpacing.xs),
                    AppButton(
                      label: isLast ? 'Got it' : 'Next',
                      expand: false,
                      height: 40,
                      onPressed: onNext,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress dots, matching the welcome overlay.
class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.spring,
            width: active ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              gradient: active ? TrackerColors.calorieGradient : null,
              color: active ? null : TrackerColors.alpha(TrackerColors.textPrimary, 0.18),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          );
        }),
      ),
    );
  }
}

class _Hole {
  const _Hole(this.rect, this.radius);

  final Rect rect;
  final double radius;

  RRect get rrect => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  static _Hole lerp(_Hole a, _Hole b, double t) =>
      _Hole(Rect.lerp(a.rect, b.rect, t)!, lerpDouble(a.radius, b.radius, t)!);
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole, this.pulse});

  final _Hole hole;

  /// 0..1 phase of the breathing ring, or null when motion is reduced.
  final double? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = hole.rrect;
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutout);
    canvas.drawPath(scrim, Paint()..color = TrackerColors.alpha(TrackerColors.background, 0.78));

    final shader = TrackerColors.calorieGradient.createShader(cutout.outerRect);

    // Soft glow hugging the cutout.
    canvas.drawRRect(
      cutout,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..color = const Color(0x66FFFFFF),
    );
    // Crisp gradient edge.
    canvas.drawRRect(
      cutout,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // A slow ring breathing outward, so the eye finds the target.
    final phase = pulse;
    if (phase != null) {
      final grow = 14 * Curves.easeOut.transform(phase);
      final ring = cutout.inflate(grow);
      canvas.drawRRect(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = TrackerColors.alpha(TrackerColors.accentEnd, 0.45 * (1 - phase)),
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole.rect != hole.rect || old.hole.radius != hole.radius || old.pulse != pulse;
}
