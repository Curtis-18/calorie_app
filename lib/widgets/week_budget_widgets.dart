import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/week_budget.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'pressable.dart';

String _kcal(int n) => NumberFormat.decimalPattern().format(n);

/// Seven small dots under the ring, one per day of the week, in neutral tones
/// (no red or green: a bigger day is not a failure). Tap for the whole week.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.week});

  final WeekBudgetData week;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const ValueKey('week_strip'),
      onTap: () {
        HapticFeedback.lightImpact();
        showWeekSheet(context, week);
      },
      scale: 0.99,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text("Today's plan: ${_kcal(week.allowanceToday)} kcal", style: AppType.headline()),
                ),
                Text('See the week', style: AppType.caption(size: 11)),
                const SizedBox(width: 2),
                Icon(CupertinoIcons.chevron_right, size: 12, color: TrackerColors.textTertiary),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final d in week.days) _Dot(day: d)],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.day});

  final BudgetDay day;

  @override
  Widget build(BuildContext context) {
    final today = day.state == BudgetDayState.today;
    final logged = day.state == BudgetDayState.pastLogged || (today && (day.eaten ?? 0) > 0);
    final color = TrackerColors.accentEnd;
    return Column(
      children: [
        Text(
          DateFormat('E').format(day.date).substring(0, 1),
          style: AppType.caption(size: 11, color: today ? TrackerColors.textPrimary : TrackerColors.textTertiary),
        ),
        const SizedBox(height: 4),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: logged ? TrackerColors.alpha(color, 0.85) : null,
            border: Border.all(
              color: today ? color : TrackerColors.alpha(TrackerColors.textTertiary, logged ? 0 : 0.5),
              width: today ? 2 : 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// The whole week: what each day was or is planned to be, and why today's plan
/// is what it is. Plain numbers and one neutral colour.
Future<void> showWeekSheet(BuildContext context, WeekBudgetData week) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => Container(
      key: const ValueKey('week_sheet'),
      color: TrackerColors.background,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: DefaultTextStyle(
        style: AppType.body(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your week', style: AppType.title()),
            const SizedBox(height: 6),
            Text(week.explanation, style: AppType.callout(size: 13)),
            const SizedBox(height: 14),
            for (final d in week.days) _DayRow(day: d),
            const SizedBox(height: 10),
            Text(
              'Plans stay inside your healthy range, and days you didn’t log are left out. Not medical advice.',
              style: AppType.caption(size: 11),
            ),
            const SizedBox(height: 14),
            AppButton.glass(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final BudgetDay day;

  @override
  Widget build(BuildContext context) {
    final today = day.state == BudgetDayState.today;
    final future = day.state == BudgetDayState.future;
    final eaten = day.eaten;
    final fill = eaten == null || day.allowance == 0 ? 0.0 : (eaten / day.allowance).clamp(0.0, 1.0);
    final String right;
    if (future) {
      right = '${_kcal(day.base)} planned';
    } else if (eaten == null) {
      right = day.state == BudgetDayState.pastUnlogged ? 'Not logged' : '0 of ${_kcal(day.allowance)}';
    } else {
      right = '${_kcal(eaten)} of ${_kcal(day.allowance)}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              DateFormat('E').format(day.date),
              style: AppType.body(size: 13, color: today ? TrackerColors.textPrimary : TrackerColors.textSecondary)
                  .copyWith(fontWeight: today ? FontWeight.w800 : FontWeight.w500),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Stack(
                children: [
                  Container(height: 8, color: TrackerColors.alpha(TrackerColors.textTertiary, 0.2)),
                  FractionallySizedBox(
                    widthFactor: fill,
                    child: Container(height: 8, color: TrackerColors.accentEnd),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Text(right, textAlign: TextAlign.right, style: AppType.caption(size: 12)),
          ),
        ],
      ),
    );
  }
}

/// After a bigger day: one kind, optional suggestion. Two buttons, no streak or
/// score consequence either way.
class BudgetNudgeCard extends StatelessWidget {
  const BudgetNudgeCard({super.key, required this.nudge, required this.onSpread, required this.onDismiss});

  final BudgetNudge nudge;
  final VoidCallback onSpread;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('budget_nudge'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nudge.message, style: AppType.body(size: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (nudge.canSpread)
                Expanded(
                  child: AppButton(
                    key: const ValueKey('nudge_spread'),
                    label: 'Yes, spread it',
                    height: 42,
                    onPressed: onSpread,
                  ),
                ),
              if (nudge.canSpread) const SizedBox(width: 10),
              Expanded(
                child: AppButton.glass(
                  key: const ValueKey('nudge_dismiss'),
                  label: nudge.canSpread ? 'Not now' : 'OK',
                  height: 42,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
