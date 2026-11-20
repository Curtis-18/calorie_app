import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/pending_scan.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'pressable.dart';
import 'shimmer.dart';
import '../l10n/app_strings.dart';

String _mealLabel(PendingScan scan) {
  final name = scan.meal.name;
  return '${name[0].toUpperCase()}${name.substring(1)}';
}

/// A meal photo on its way through the scan, shown on Today the moment it is
/// taken. Tapping it when the foods are ready opens the review.
class PendingScanCard extends StatelessWidget {
  const PendingScanCard({
    super.key,
    required this.scan,
    required this.onReview,
    required this.onRetry,
    required this.onDismiss,
    this.onNote,
  });

  final PendingScan scan;
  final VoidCallback onReview;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  /// Add a spoken or typed note and scan again. Null hides the button.
  final VoidCallback? onNote;

  @override
  Widget build(BuildContext context) {
    final ready = scan.status == ScanStatus.ready;
    final scanning = scan.status == ScanStatus.scanning;

    final String title;
    final String subtitle;
    switch (scan.status) {
      case ScanStatus.scanning:
        title = tr('Looking at your meal…');
        subtitle = tr('{meal} · you can keep using the app', {'meal': tr(_mealLabel(scan))});
      case ScanStatus.ready:
        final n = scan.foods.length;
        title = tr('Check your {v1}', {'v1': tr(_mealLabel(scan).toLowerCase())});
        subtitle = n == 1 ? tr('1 food found · tap to review') : tr('{n} foods found · tap to review', {'n': n});
      case ScanStatus.empty:
        title = tr('No food found');
        subtitle = tr('Try getting closer or improving the light.');
      case ScanStatus.failed:
        title = tr("Couldn't scan this photo");
        subtitle = scan.message ?? tr('Please try again.');
    }

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: AppDecor.card(),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(scan.image, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox()),
                  if (scanning)
                    Shimmer(
                      child: Container(color: TrackerColors.alpha(TrackerColors.textPrimary, 0.08)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.headline(color: TrackerColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
                ),
              ],
            ),
          ),
          if (onNote != null && scan.status != ScanStatus.failed)
            CupertinoButton(
              key: ValueKey('scan_note_${scan.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(32, 32),
              onPressed: onNote,
              child: Icon(
                scan.note == null ? CupertinoIcons.mic : CupertinoIcons.mic_fill,
                size: 20,
                color: TrackerColors.textSecondary,
              ),
            ),
          if (ready) Icon(CupertinoIcons.chevron_right, size: 16, color: TrackerColors.textTertiary),
          if (scan.status == ScanStatus.failed)
            CupertinoButton(
              key: ValueKey('scan_retry_${scan.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(32, 32),
              onPressed: onRetry,
              child: Text(tr('Try again'), style: AppType.callout(color: TrackerColors.ink(TrackerColors.accentStart))),
            ),
          if (!scanning)
            CupertinoButton(
              key: ValueKey('scan_dismiss_${scan.id}'),
              padding: const EdgeInsets.only(left: 4),
              minimumSize: const Size(32, 32),
              onPressed: onDismiss,
              child: Icon(CupertinoIcons.xmark_circle_fill, size: 20, color: TrackerColors.textTertiary),
            ),
        ],
      ),
    );

    if (!ready) return card;
    return Pressable(
      key: ValueKey('scan_review_${scan.id}'),
      scale: 0.99,
      onTap: () {
        HapticFeedback.lightImpact();
        onReview();
      },
      child: card,
    );
  }
}
