import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/tracker_colors.dart';

/// Dark pulsing gradient used in place of generic loading spinners.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.borderRadius,
    this.baseColor = TrackerColors.shimmerBase,
    this.highlightColor = TrackerColors.shimmerHighlight,
    this.enabled = true,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final Color baseColor;
  final Color highlightColor;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppRadii.smallAll;

    if (!widget.enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(color: widget.baseColor, borderRadius: radius),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1.6 + _controller.value * 3.2, 0),
              end: Alignment(-0.6 + _controller.value * 3.2, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.15, 0.5, 0.85],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Single skeleton block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadii.small,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
      ),
    );
  }
}

/// Skeleton shaped like a dashboard card.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 160, this.padding = const EdgeInsets.all(20)});

  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      padding: padding,
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 120, height: 12, radius: 6),
          const SizedBox(height: AppSpacing.lg),
          const SkeletonBox(height: 16, radius: 8),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBox(height: 16, radius: 8),
          const SizedBox(height: AppSpacing.md),
          const FractionallySizedBox(
            widthFactor: 0.7,
            child: SkeletonBox(height: 16, radius: 8),
          ),
        ],
      ),
    );
  }
}

/// Skeleton list of recipe-style rows with a leading thumbnail.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.count = 5, this.thumbnail = true});

  final int count;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: AppDecor.card(borderRadius: AppRadii.buttonAll),
            child: Row(
              children: [
                if (thumbnail) ...[
                  const SkeletonBox(width: 56, height: 56, radius: AppRadii.small),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.6,
                        child: const SkeletonBox(height: 14, radius: 6),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.35,
                        child: const SkeletonBox(height: 11, radius: 6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Shimmered stand-in for the calorie ring.
class SkeletonRing extends StatelessWidget {
  const SkeletonRing({super.key, this.size = 240, this.strokeWidth = 18});

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Shimmer(
        enabled: false,
        borderRadius: BorderRadius.circular(size),
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TrackerColors.shimmerBase, width: strokeWidth),
            ),
          ),
        ),
      ),
    );
  }
}
