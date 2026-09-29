import 'package:flutter/cupertino.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';

/// Shared empty / error state used across tabs and lists.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accent = TrackerColors.accentStart,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TrackerColors.alpha(accent, 0.12),
                borderRadius: AppRadii.buttonAll,
                border: Border.all(color: TrackerColors.alpha(accent, 0.24), width: 1),
                boxShadow: AppDecor.glow(accent, blur: 20, opacity: 0.14),
              ),
              child: Icon(icon, size: 26, color: accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: AppType.headline()),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppType.callout(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
