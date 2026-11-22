import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';

/// A slim row on Today that opens Insights (which is no longer a tab).
class InsightsRow extends StatelessWidget {
  const InsightsRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('Insights'),
      child: AppCard(
        key: const ValueKey('insights_row'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TrackerColors.alpha(TrackerColors.accentStart, 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(CupertinoIcons.chart_bar_alt_fill, size: 17, color: TrackerColors.accentStartText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Insights'), style: AppType.body(size: 15.5).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(
                    tr('Your week at a glance'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption(color: TrackerColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: TrackerColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
