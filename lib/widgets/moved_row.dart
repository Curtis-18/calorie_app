import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';

/// "Moved today" on Today: shown only once something was logged, so an empty
/// day is never marked with a blank or a nag. Opens the Workouts tab.
class MovedRow extends StatelessWidget {
  const MovedRow({super.key, required this.minutes, required this.onTap});

  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('Moved today'),
      child: AppCard(
        key: const ValueKey('moved_row'),
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
                color: TrackerColors.alpha(TrackerColors.flameStart, 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(CupertinoIcons.bolt_fill, size: 17, color: TrackerColors.flameStart),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tr('Moved today'), style: AppType.body(size: 15.5).copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(tr('{n} min', {'n': '$minutes'}), key: const ValueKey('moved_minutes'), style: AppType.body(size: 14.5, color: TrackerColors.textSecondary)),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, size: 14, color: TrackerColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
