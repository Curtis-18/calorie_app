import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/weight.dart';
import '../../providers/weight_provider.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../app_button.dart';
import '../app_card.dart';
import '../app_dialog.dart';
import '../glass.dart';
import '../pressable.dart';
import '../share/share_sheet.dart';
import 'weight_chart.dart';

enum _Range {
  month('1M', 31),
  quarter('3M', 92),
  all('All', null);

  const _Range(this.label, this.days);
  final String label;
  final int? days;
}

/// Weight progress: change since the first weigh-in, start/now/lowest, the
/// trend chart and a way to log or review weigh-ins.
///
/// Changes are shown in a neutral accent, never red/green: whether a number
/// went "the right way" depends on the user's goal and isn't ours to judge.
class WeightProgressCard extends ConsumerStatefulWidget {
  const WeightProgressCard({super.key});

  @override
  ConsumerState<WeightProgressCard> createState() => _WeightProgressCardState();
}

class _WeightProgressCardState extends ConsumerState<WeightProgressCard> {
  _Range _range = _Range.quarter;

  List<WeightPoint> _visible(List<WeightPoint> all) {
    final days = _range.days;
    if (days == null || all.isEmpty) return all;
    final cutoff = all.last.date.subtract(Duration(days: days));
    final within = all.where((p) => !p.date.isBefore(cutoff)).toList();
    return within.isEmpty ? [all.last] : within;
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(weightProvider);
    final unit = ref.watch(weightUnitProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            label: 'Weight progress',
            trailing: UnitToggle(
              unit: unit,
              onChanged: (u) => ref.read(weightUnitProvider.notifier).set(u),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          history.when(
            loading: () => const SizedBox(height: 120, child: Center(child: PulsingRing(size: 34, strokeWidth: 3))),
            error: (e, _) => _Message(
              icon: CupertinoIcons.wifi_exclamationmark,
              text: '$e',
              action: AppButton.glass(
                label: 'Try again',
                height: 44,
                onPressed: () => ref.read(weightProvider.notifier).load(),
              ),
            ),
            data: (h) => h.isEmpty ? _empty(context) : _content(context, h, unit),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => _Message(
        icon: CupertinoIcons.chart_bar_alt_fill,
        text: 'Log your first weigh-in to start tracking your progress over time.',
        action: AppButton(label: 'Log weight', icon: CupertinoIcons.plus, onPressed: () => showLogWeightSheet(context)),
      );

  Widget _content(BuildContext context, WeightHistory h, WeightUnit unit) {
    final s = h.summary!;
    final visible = _visible(h.entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          h.entries.length == 1 ? unit.format(s.currentKg) : unit.formatChange(s.changeKg),
          style: AppType.display(size: 34, color: TrackerColors.accentEnd),
        ),
        const SizedBox(height: 2),
        Text(
          h.entries.length == 1
              ? 'Your starting point · log again to see your trend'
              : 'since ${_long(s.startDate)} · ${s.count} weigh-ins',
          style: AppType.caption(color: TrackerColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _Stat(label: 'Start', value: unit.format(s.startKg)),
            _Stat(label: 'Now', value: unit.format(s.currentKg)),
            _Stat(label: 'Lowest', value: unit.format(s.lowestKg)),
          ],
        ),
        if (h.entries.length > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (final r in _Range.values) ...[
                _RangeChip(label: r.label, selected: r == _range, onTap: () => setState(() => _range = r)),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          WeightChart(points: visible, unit: unit),
        ],
        if (s.daysSinceLast >= 7) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            "It's been ${s.daysSinceLast} days. Time for a weigh-in?",
            style: AppType.caption(color: TrackerColors.accentEnd, size: 12.5),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Log weight',
                icon: CupertinoIcons.plus,
                height: 46,
                onPressed: () => showLogWeightSheet(context),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton.glass(
              label: 'History',
              expand: false,
              height: 46,
              onPressed: () => showWeightHistorySheet(context),
            ),
            if (h.entries.length > 1) ...[
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                button: true,
                label: 'Share weight progress',
                child: AppIconButton(
                  icon: CupertinoIcons.share,
                  size: 46,
                  iconSize: 18,
                  onPressed: () => showShareProgressSheet(context, includeWeight: true),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String _long(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppType.sectionLabel().copyWith(fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, style: AppType.headline()),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? TrackerColors.alpha(TrackerColors.accentEnd, 0.16)
              : TrackerColors.alpha(TrackerColors.textPrimary, 0.05),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? TrackerColors.alpha(TrackerColors.accentEnd, 0.4) : TrackerColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppType.caption(
            color: selected ? TrackerColors.accentEnd : TrackerColors.textSecondary,
            size: 12,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class UnitToggle extends StatelessWidget {
  const UnitToggle({super.key, required this.unit, required this.onChanged});

  final WeightUnit unit;
  final ValueChanged<WeightUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(TrackerColors.textPrimary, 0.05),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: TrackerColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final u in WeightUnit.values)
            Pressable(
              onTap: () => onChanged(u),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: u == unit ? TrackerColors.calorieGradient : null,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  u.label,
                  style: AppType.caption(
                    color: u == unit ? TrackerColors.textPrimary : TrackerColors.textSecondary,
                    size: 11.5,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.action});

  final IconData icon;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: TrackerColors.accentEnd),
        const SizedBox(height: AppSpacing.md),
        Text(text, textAlign: TextAlign.center, style: AppType.callout()),
        const SizedBox(height: AppSpacing.lg),
        action,
      ],
    );
  }
}

// --- sheets ---------------------------------------------------------------------

Future<void> showLogWeightSheet(BuildContext context) {
  return showAppSheet<void>(context: context, builder: (_) => const AppSheet(child: _LogWeightSheet()));
}

class _LogWeightSheet extends ConsumerStatefulWidget {
  const _LogWeightSheet();

  @override
  ConsumerState<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends ConsumerState<_LogWeightSheet> {
  final _controller = TextEditingController();
  DateTime _day = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final last = ref.read(weightProvider).value?.summary?.currentKg;
    if (last != null) {
      _controller.text = ref.read(weightUnitProvider).fromKg(last).toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  Future<void> _pickDay() async {
    var picked = _day;
    final now = DateTime.now();
    final chosen = await showAppSheet<DateTime>(
      context: context,
      builder: (sheet) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Weigh-in date', style: AppType.title()),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _day,
                minimumDate: DateTime(now.year - 2, now.month, now.day),
                maximumDate: now,
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Done', onPressed: () => Navigator.of(sheet).pop(picked)),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _day = chosen);
  }

  Future<void> _save() async {
    final unit = ref.read(weightUnitProvider);
    final kg = parseWeightKg(_controller.text, unit);
    if (kg == null) {
      setState(() => _error = 'Enter a weight between ${unit.format(20, decimals: 0)} and ${unit.format(400, decimals: 0)}.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notice = await ref.read(weightProvider.notifier).log(kg, on: _day);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (notice != null) {
        await showAppDialog(context: context, title: 'Goal updated', message: notice, confirmLabel: 'Got it');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(weightUnitProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Log weight', style: AppType.title()),
              const Spacer(),
              UnitToggle(
                unit: unit,
                onChanged: (u) {
                  final current = parseWeightKg(_controller.text, unit);
                  ref.read(weightUnitProvider.notifier).set(u);
                  if (current != null) _controller.text = u.fromKg(current).toStringAsFixed(1);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          CupertinoTextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.0',
            style: AppType.display(size: 44),
            placeholderStyle: AppType.display(size: 44, color: TrackerColors.textTertiary),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Text(unit.label, style: AppType.headline(color: TrackerColors.textSecondary)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: TrackerColors.surfaceElevated,
              borderRadius: AppRadii.buttonAll,
              border: Border.all(color: _error == null ? TrackerColors.border : TrackerColors.error),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, textAlign: TextAlign.center, style: AppType.caption(color: TrackerColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          Pressable(
            onTap: _pickDay,
            borderRadius: AppRadii.buttonAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.calendar, size: 15, color: TrackerColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(_isToday ? 'Today' : _long(_day), style: AppType.callout()),
                  const SizedBox(width: 4),
                  const Icon(CupertinoIcons.chevron_down, size: 12, color: TrackerColors.textTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Save', loading: _saving, onPressed: _saving ? null : _save),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Weigh in at the same time of day for the clearest trend. Morning, after the bathroom, works best.',
            textAlign: TextAlign.center,
            style: AppType.caption(color: TrackerColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

Future<void> showWeightHistorySheet(BuildContext context) {
  return showAppSheet<void>(context: context, builder: (_) => const AppSheet(child: _HistorySheet()));
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(weightProvider).value?.entries.reversed.toList() ?? const <WeightPoint>[];
    final unit = ref.watch(weightUnitProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weigh-ins', style: AppType.title()),
        const SizedBox(height: AppSpacing.md),
        Flexible(
          child: entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('No weigh-ins yet', style: AppType.callout())),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => Container(height: 1, color: TrackerColors.divider),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final previous = i + 1 < entries.length ? entries[i + 1] : null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(child: Text(_long(e.date), style: AppType.body())),
                          if (previous != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                unit.formatChange(e.weightKg - previous.weightKg),
                                style: AppType.caption(color: TrackerColors.textTertiary),
                              ),
                            ),
                          Text(unit.format(e.weightKg), style: AppType.headline()),
                          const SizedBox(width: 8),
                          AppIconButton(
                            icon: CupertinoIcons.delete,
                            size: 32,
                            iconSize: 14,
                            color: TrackerColors.error,
                            background: TrackerColors.alpha(TrackerColors.error, 0.1),
                            onPressed: () async {
                              final ok = await showAppDialog(
                                context: context,
                                title: 'Delete weigh-in?',
                                message: '${unit.format(e.weightKg)} on ${_long(e.date)}',
                                confirmLabel: 'Delete',
                                cancelLabel: 'Cancel',
                                destructive: true,
                              );
                              if (ok == true) {
                                try {
                                  await ref.read(weightProvider.notifier).delete(e.date);
                                } catch (err) {
                                  if (context.mounted) {
                                    await showAppDialog(context: context, title: 'Couldn\'t delete', message: '$err');
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
