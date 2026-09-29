import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';

/// Dark replacement for [CupertinoAlertDialog]. Returns `true` when the
/// primary action was chosen, `false` on cancel/dismiss, `null` when dismissed.
Future<bool?> showAppDialog({
  required BuildContext context,
  String? title,
  String? message,
  String confirmLabel = 'OK',
  String? cancelLabel,
  bool destructive = false,
}) {
  return showCupertinoDialog<bool>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (dialogContext) => _AppDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
}

class _AppDialog extends StatelessWidget {
  const _AppDialog({
    this.title,
    this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
  });

  final String? title;
  final String? message;
  final String confirmLabel;
  final String? cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: AppMotion.quick,
          curve: AppMotion.spring,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child)),
          child: FrostedGlass(
            blur: 24,
            opacity: 0.97,
            tint: TrackerColors.surface,
            borderRadius: AppRadii.containerAll,
            border: Border.all(color: TrackerColors.borderStrong, width: 1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    Text(title!, textAlign: TextAlign.center, style: AppType.headline()),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: AppType.callout(color: TrackerColors.textSecondary, size: 14),
                      ),
                    ),
                  Row(
                    children: [
                      if (cancelLabel case final cancel?) ...[
                        Expanded(
                          child: AppButton.glass(
                            label: cancel,
                            height: 46,
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: AppButton(
                          label: confirmLabel,
                          height: 46,
                          style: destructive ? AppButtonStyle.glass : AppButtonStyle.primary,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocking progress overlay with a glowing ring, used while a photo is
/// being analyzed.
class AppLoadingDialog extends StatelessWidget {
  const AppLoadingDialog({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: FrostedGlass(
          blur: 24,
          opacity: 0.96,
          tint: TrackerColors.surface,
          borderRadius: AppRadii.containerAll,
          border: Border.all(color: TrackerColors.borderStrong, width: 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulsingRing(size: 46, strokeWidth: 4),
                if (label != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(label!, style: AppType.callout(size: 14)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slowly pulsing glow ring — the app's shared "working" indicator.
class PulsingRing extends StatefulWidget {
  const PulsingRing({
    super.key,
    this.size = 64,
    this.strokeWidth = 5,
    this.color = TrackerColors.accentStart,
  });

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  State<PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<PulsingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: TrackerColors.alpha(
                      widget.color,
                      0.45 * (1 - t),
                    ),
                    width: widget.strokeWidth,
                  ),
                ),
              ),
              Container(
                width: widget.size * (0.55 + 0.45 * t),
                height: widget.size * (0.55 + 0.45 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: TrackerColors.alpha(widget.color, 0.9 * (1 - t * 0.85)),
                    width: widget.strokeWidth,
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
