import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../theme/tracker_colors.dart';
import '../widgets/page_header.dart';

/// The Workouts tab (built up in stages; see handover R9).
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: BoxDecoration(color: TrackerColors.background),
        child: Column(children: [PageHeader(title: tr('Workouts'))]),
      ),
    );
  }
}
