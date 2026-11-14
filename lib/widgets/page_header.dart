import 'package:flutter/cupertino.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'glass.dart';

/// The top bar every tab shares: a small eyebrow, a large title, an optional
/// subtitle, actions on the right and an optional row underneath (a search
/// field, say). One widget so the five tabs read as one app; each tab used to
/// build its own bar with its own paddings and title size.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.titleAccessory,
    this.actions = const [],
    this.bottom,
  });

  final String title;

  /// Small line above the title, e.g. the greeting on Today.
  final String? eyebrow;
  final String? subtitle;

  /// Sits right after the title, e.g. the day arrows on Today.
  final Widget? titleAccessory;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      opacity: 0.9,
      tint: TrackerColors.navFill,
      blur: 24,
      borderRadius: BorderRadius.zero,
      border: AppDecor.hairlineTop,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 8, AppSpacing.xl, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (eyebrow != null) ...[
                          Text(
                            eyebrow!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption(color: TrackerColors.textSecondary, size: 12.5),
                          ),
                          const SizedBox(height: 1),
                        ],
                        Row(
                          children: [
                            Flexible(
                              child: AnimatedSwitcher(
                                duration: AppMotion.quick,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [...previous, ?current],
                                ),
                                child: Text(
                                  title,
                                  key: ValueKey(title),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.navLargeTitle(size: 28),
                                ),
                              ),
                            ),
                            if (titleAccessory != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              titleAccessory!,
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption(color: TrackerColors.textSecondary, size: 12.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  for (final action in actions) ...[const SizedBox(width: AppSpacing.sm), action],
                ],
              ),
              if (bottom != null) ...[const SizedBox(height: AppSpacing.md), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}
