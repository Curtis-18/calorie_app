import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/tracker_colors.dart';

/// iOS frosted glass: `backdrop-filter: blur(20px)` over a translucent fill.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.opacity = 0.08,
    this.tint,
    this.borderRadius,
    this.border,
    this.blur = AppDecor.blur,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final Color? tint;
  final BorderRadius? borderRadius;
  final Border? border;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadii.containerAll;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.compose(
          outer: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal),
          inner: ImageFilter.matrix(
            Float64List.fromList(const <double>[
              1.18, 0, 0, 0, //
              0, 1.18, 0, 0, //
              0, 0, 1.18, 0, //
              0, 0, 0, 1, //
            ]),
          ),
        ),
        child: DecoratedBox(
          decoration: AppDecor.glass(
            opacity: opacity,
            borderRadius: radius,
            border: border,
            tint: tint,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// The little grab handle pill at the top of every bottom sheet.
class AppGrabHandle extends StatelessWidget {
  const AppGrabHandle({super.key, this.width = 38, this.height = 5});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: TrackerColors.alpha(TrackerColors.textPrimary, 0.24),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    );
  }
}

/// Bottom sheet chrome: 28px top corners, grab handle, blurred dark surface.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 0),
    this.showHandle = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.86;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: FrostedGlass(
          blur: 24,
          opacity: 0.96,
          tint: TrackerColors.sheetFill,
          borderRadius: AppRadii.sheetTop,
          border: Border.all(color: TrackerColors.borderStrong, width: 1),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showHandle) ...[
                    const AppGrabHandle(),
                    const SizedBox(height: 16),
                  ],
                  child,
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Presents [builder] as an iOS-style bottom sheet that springs up from the
/// bottom edge. Returns the value popped from the sheet route.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0xB3000000),
    builder: (sheetContext) => _SheetEntrance(child: Builder(builder: builder)),
  );
}

class _SheetEntrance extends StatefulWidget {
  const _SheetEntrance({required this.child});

  final Widget child;

  @override
  State<_SheetEntrance> createState() => _SheetEntranceState();
}

class _SheetEntranceState extends State<_SheetEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.sheet,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.springSoft);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, (1 - t) * 60),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: Align(alignment: Alignment.bottomCenter, child: widget.child),
    );
  }
}
