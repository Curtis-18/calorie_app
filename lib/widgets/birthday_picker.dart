import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';
import 'pressable.dart';

/// Which part of a date a wheel sets.
enum BirthdayField { day, month, year }

/// The three wheels in the order the person's language writes dates:
/// month first in English (Mar 14, 1998), day first elsewhere (14 Mar 1998).
List<BirthdayField> birthdayFieldOrder(String language) => language == 'en'
    ? const [BirthdayField.month, BirthdayField.day, BirthdayField.year]
    : const [BirthdayField.day, BirthdayField.month, BirthdayField.year];

/// The twelve short month names, in the app's language.
List<String> shortMonthNames() => [
  tr('Jan'), tr('Feb'), tr('Mar'), tr('Apr'), tr('May'), tr('Jun'), //
  tr('Jul'), tr('Aug'), tr('Sep'), tr('Oct'), tr('Nov'), tr('Dec'),
];

/// "Mar 14, 1998" or "14 Mar 1998", by the language of the app.
String formatBirthday(DateTime date, [String? language]) {
  final month = shortMonthNames()[date.month - 1];
  return (language ?? AppStrings.active) == 'en'
      ? '$month ${date.day}, ${date.year}'
      : '${date.day} $month ${date.year}';
}

/// One row of "jump to" chips: a span of years such as 1990 to 1999.
class DecadeSpan {
  const DecadeSpan(this.from, this.to);

  final int from;
  final int to;

  String get label => '$from–${(to % 100).toString().padLeft(2, '0')}';

  /// Where the year wheel lands: the middle of the span.
  int get middle => (from + to) ~/ 2;
}

/// The date being chosen and the rules around it, apart from any widget so the
/// rules can be tested on their own: never earlier than [earliest], never later
/// than [latest] (the youngest allowed birthday, adults only), and a day that
/// does not exist in a month (31 February) slides back to the last real day.
class BirthdayModel {
  BirthdayModel({
    required this.earliest,
    required this.latest,
    DateTime? initial,
  }) : _value = DateTime(2000, 1, 1) {
    _value = _clamp(initial ?? DateTime(latest.year - 26, 1, 1));
  }

  final DateTime earliest;
  final DateTime latest;
  DateTime _value;

  DateTime get value => _value;
  int get firstYear => earliest.year;
  int get lastYear => latest.year;

  static int daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

  DateTime _clamp(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isAfter(latest)) {
      return DateTime(latest.year, latest.month, latest.day);
    }
    if (day.isBefore(earliest)) {
      return DateTime(earliest.year, earliest.month, earliest.day);
    }
    return day;
  }

  DateTime _with({int? year, int? month, int? day}) {
    final y = year ?? _value.year;
    final m = month ?? _value.month;
    final d = math.min(day ?? _value.day, daysIn(y, m));
    return _clamp(DateTime(y, m, d));
  }

  void setYear(int year) => _value = _with(year: year);
  void setMonth(int month) => _value = _with(month: month);
  void setDay(int day) => _value = _with(day: day);

  /// Whole years old on [today].
  int ageOn(DateTime today) {
    var age = today.year - _value.year;
    if (today.month < _value.month || (today.month == _value.month && today.day < _value.day)) {
      age--;
    }
    return age;
  }

  /// Spans of ten years that touch the allowed years, oldest first.
  List<DecadeSpan> decades() {
    final out = <DecadeSpan>[];
    for (var start = (firstYear ~/ 10) * 10; start <= lastYear; start += 10) {
      out.add(
        DecadeSpan(math.max(start, firstYear), math.min(start + 9, lastYear)),
      );
    }
    return out;
  }

  void jumpTo(DecadeSpan span) => setYear(span.middle);

  /// Whether [year] is inside [span], for highlighting the chip.
  bool inSpan(DecadeSpan span) =>
      _value.year >= span.from && _value.year <= span.to;
}

/// Opens the birthday picker as a sheet. Returns the chosen date, or null if
/// the sheet was dismissed.
Future<DateTime?> showBirthdayPicker(
  BuildContext context, {
  DateTime? initial,
  required DateTime latest,
  DateTime? earliest,
}) {
  final model = BirthdayModel(
    earliest: earliest ?? DateTime(1920),
    latest: latest,
    initial: initial,
  );
  return showAppSheet<DateTime>(
    context: context,
    builder: (sheetContext) => AppSheet(
      child: BirthdaySheet(
        model: model,
        onDone: (d) => Navigator.of(sheetContext).pop(d),
      ),
    ),
  );
}

/// The inside of the sheet: a readout, decade chips and the three wheels.
class BirthdaySheet extends StatefulWidget {
  const BirthdaySheet({
    super.key,
    required this.model,
    required this.onDone,
    this.today,
  });

  final BirthdayModel model;
  final ValueChanged<DateTime> onDone;

  /// Fixed in tests; the current day otherwise.
  final DateTime? today;

  @override
  State<BirthdaySheet> createState() => _BirthdaySheetState();
}

class _BirthdaySheetState extends State<BirthdaySheet> {
  late final FixedExtentScrollController _day;
  late final FixedExtentScrollController _month;
  late final FixedExtentScrollController _year;
  late final ScrollController _chips;

  static const double _chipWidth = 88;
  static const double _chipStride = _chipWidth + 8;

  BirthdayModel get _m => widget.model;

  @override
  void initState() {
    super.initState();
    final firstChip = _m.decades().indexWhere(_m.inSpan);
    _chips = ScrollController(initialScrollOffset: firstChip <= 0 ? 0 : firstChip * _chipStride - 120);
    _day = FixedExtentScrollController(initialItem: _m.value.day - 1);
    _month = FixedExtentScrollController(initialItem: _m.value.month - 1);
    _year = FixedExtentScrollController(
      initialItem: _m.value.year - _m.firstYear,
    );
  }

  @override
  void dispose() {
    _day.dispose();
    _month.dispose();
    _year.dispose();
    _chips.dispose();
    super.dispose();
  }

  FixedExtentScrollController _controller(BirthdayField f) => switch (f) {
    BirthdayField.day => _day,
    BirthdayField.month => _month,
    BirthdayField.year => _year,
  };

  /// After one wheel moves, the model may have nudged the others (31 Feb
  /// Keeps the highlighted decade chip in view as the year moves.
  void _showActiveChip() {
    if (!_chips.hasClients) return;
    final spans = _m.decades();
    final index = spans.indexWhere(_m.inSpan);
    if (index < 0) return;
    // Every chip is the same width, so the active one can be centred exactly.
    final target = (index * _chipStride - _chips.position.viewportDimension / 2 + _chipWidth / 2)
        .clamp(0.0, _chips.position.maxScrollExtent);
    _chips.animateTo(target, duration: AppMotion.medium, curve: AppMotion.standard);
  }

  void _syncWheels() {
    _showActiveChip();
    void glide(FixedExtentScrollController c, int item) {
      if (!c.hasClients || c.selectedItem == item) return;
      c.animateToItem(
        item,
        duration: AppMotion.medium,
        curve: AppMotion.standard,
      );
    }

    glide(_day, _m.value.day - 1);
    glide(_month, _m.value.month - 1);
    glide(_year, _m.value.year - _m.firstYear);
  }

  void _changed(BirthdayField field, int item) {
    final before = _m.value;
    switch (field) {
      case BirthdayField.day:
        _m.setDay(item + 1);
      case BirthdayField.month:
        _m.setMonth(item + 1);
      case BirthdayField.year:
        _m.setYear(_m.firstYear + item);
    }
    if (_m.value != before) HapticFeedback.selectionClick();
    setState(() {});
    _syncWheels();
  }

  void _jump(DecadeSpan span) {
    HapticFeedback.selectionClick();
    _m.jumpTo(span);
    setState(() {});
    _syncWheels();
  }

  Widget _wheel(BirthdayField field) {
    final names = shortMonthNames();
    final count = switch (field) {
      BirthdayField.day => 31,
      BirthdayField.month => 12,
      BirthdayField.year => _m.lastYear - _m.firstYear + 1,
    };
    final days = BirthdayModel.daysIn(_m.value.year, _m.value.month);
    return Expanded(
      flex: field == BirthdayField.month ? 3 : 2,
      child: CupertinoPicker(
        key: ValueKey('birthday_${field.name}'),
        scrollController: _controller(field),
        itemExtent: 40,
        magnification: 1.08,
        useMagnifier: true,
        squeeze: 1.1,
        selectionOverlay: Container(
          decoration: BoxDecoration(
            color: TrackerColors.alpha(TrackerColors.accentStart, 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onSelectedItemChanged: (item) => _changed(field, item),
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Text(
                switch (field) {
                  BirthdayField.day => '${i + 1}',
                  BirthdayField.month => names[i],
                  BirthdayField.year => '${_m.firstYear + i}',
                },
                style: AppType.body(
                  size: 20,
                  // Days that this month does not have fade out.
                  color: field == BirthdayField.day && i + 1 > days
                      ? TrackerColors.textTertiary
                      : TrackerColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.today ?? DateTime.now();
    final age = _m.ageOn(today);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('Date of birth'), style: AppType.title()),
        const SizedBox(height: AppSpacing.md),
        // What they are picking, in words, and the age it makes.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TrackerColors.alpha(TrackerColors.accentStart, 0.16),
                TrackerColors.alpha(TrackerColors.accentEnd, 0.1),
              ],
            ),
            borderRadius: AppRadii.containerAll,
            border: Border.all(
              color: TrackerColors.alpha(TrackerColors.accentStart, 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.gift_fill,
                size: 22,
                color: TrackerColors.accentStartText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatBirthday(_m.value),
                      key: const ValueKey('birthday_readout'),
                      style: AppType.headline(),
                    ),
                    AnimatedSwitcher(
                      duration: AppMotion.medium,
                      switchInCurve: AppMotion.spring,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.85,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, ?current],
                      ),
                      child: Text(
                        tr("You're {n} years old", {'n': age}),
                        key: ValueKey('birthday_age_$age'),
                        style: AppType.caption(
                          color: TrackerColors.accentStartText,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Skip the scrolling: jump straight to a stretch of years.
        SizedBox(
          height: 36,
          child: ListView.separated(
            controller: _chips,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _m.decades().length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final span = _m.decades()[i];
              final active = _m.inSpan(span);
              return Pressable(
                key: ValueKey('decade_${span.from}'),
                onTap: () => _jump(span),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: AnimatedContainer(
                  duration: AppMotion.quick,
                  alignment: Alignment.center,
                  width: _chipWidth,
                  decoration: BoxDecoration(
                    gradient: active ? TrackerColors.calorieGradient : null,
                    color: active ? null : TrackerColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: active
                        ? null
                        : Border.all(color: TrackerColors.border),
                  ),
                  child: Text(
                    span.label,
                    style: AppType.caption(
                      color: active
                          ? TrackerColors.onAccent
                          : TrackerColors.textSecondary,
                      size: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 180,
          child: Row(
            children: [
              for (final f in birthdayFieldOrder(AppStrings.active)) _wheel(f),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr('You need to be 18 or older.'),
          style: AppType.caption(color: TrackerColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          key: const ValueKey('birthday_done'),
          label: tr('Done'),
          onPressed: () => widget.onDone(_m.value),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
