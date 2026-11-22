import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/mood.dart';
import '../models/workouts.dart';
import '../providers/shell_provider.dart';
import '../providers/workouts_provider.dart';
import '../services/tour_service.dart';
import '../services/workout_picks.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_tour.dart';
import '../widgets/app_card.dart';
import '../widgets/glass.dart';
import '../widgets/log_movement_sheet.dart';
import '../widgets/move_icons.dart';
import '../widgets/move_week_card.dart';
import '../widgets/page_header.dart';
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';
import '../widgets/workout_detail_sheet.dart';
import '../widgets/workout_tiles.dart';

/// The Workouts tab (roadmap R9): your week at a glance, short "Move bites",
/// sessions by length, a way to log anything else, and what you did lately.
/// Movement here is its own thing: it is never tied to the food streak, never
/// shared, and never turns into calories to eat or to "earn".
class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  Mood? _feeling;
  int _maxMinutes = 0;
  MoveSlice? _slice;

  Future<void> _open(WorkoutCard card) => showWorkoutDetail(
    context,
    card,
    loader: ref.read(workoutsServiceProvider).detail,
  );

  // What the spotlight tour points at.
  final _helpKey = GlobalKey(debugLabel: 'tourWorkoutsHelp');
  final _logKey = GlobalKey(debugLabel: 'tourWorkoutsLog');
  final _weekKey = GlobalKey(debugLabel: 'tourWorkoutsWeek');
  final _plateKey = GlobalKey(debugLabel: 'tourWorkoutsPlate');
  final _feelingsKey = GlobalKey(debugLabel: 'tourWorkoutsFeelings');
  final _bitesKey = GlobalKey(debugLabel: 'tourWorkoutsBites');
  final _libraryKey = GlobalKey(debugLabel: 'tourWorkoutsLibrary');
  final _planKey = GlobalKey(debugLabel: 'tourWorkoutsPlan');

  bool _tourChecked = false;

  @override
  void initState() {
    super.initState();
    // Already on this tab when it is built (a shortcut, a restored session).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(shellTabProvider) == ShellTab.workouts) {
        _maybeStartTour();
      }
    });
  }

  /// The first time the tab is opened: the spotlight tour, once. Never over
  /// another page or sheet; the ? button shows it again whenever.
  Future<void> _maybeStartTour() async {
    if (_tourChecked) return;
    _tourChecked = true;
    try {
      if (await TourService.hasSeen(TourService.workouts)) return;
      // Give the week and the library a moment to load, so there is
      // something real to point at.
      for (var i = 0; i < 10 && mounted; i++) {
        if (ref.read(workoutLibraryProvider).hasValue &&
            ref.read(moveProvider).loaded) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted || ref.read(shellTabProvider) != ShellTab.workouts) {
        _tourChecked = false; // try again next time the tab is opened
        return;
      }
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) {
        _tourChecked = false;
        return;
      }
      await _showTour();
      await TourService.markSeen(TourService.workouts);
    } catch (_) {
      // A tour is a nicety; never let it break the tab.
    }
  }

  Future<void> _showTour() async {
    if (!mounted) return;
    await AppTour.show(
      context,
      steps: workoutsTourSteps(
        weekKey: _weekKey,
        plateKey: _plateKey,
        feelingsKey: _feelingsKey,
        bitesKey: _bitesKey,
        libraryKey: _libraryKey,
        planKey: _planKey,
        logKey: _logKey,
        helpKey: _helpKey,
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(workoutLibraryProvider);
    await ref.read(moveProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final move = ref.watch(moveProvider);
    final library = ref.watch(workoutLibraryProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    ref.listen<ShellTab>(shellTabProvider, (_, tab) {
      if (tab == ShellTab.workouts) _maybeStartTour();
    });

    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: BoxDecoration(color: TrackerColors.background),
        child: Column(
          children: [
            PageHeader(
              title: tr('Workouts'),
              subtitle: tr('Move your way'),
              actions: [
                KeyedSubtree(
                  key: _helpKey,
                  child: Pressable(
                    key: const ValueKey('workouts_help'),
                    onTap: _showTour,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: TrackerColors.glassFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.question,
                        size: 20,
                        color: TrackerColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                KeyedSubtree(
                  key: _logKey,
                  child: Pressable(
                    key: const ValueKey('log_other'),
                    onTap: () => showLogMovementSheet(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: TrackerColors.glassFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.add,
                        size: 20,
                        color: TrackerColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _refresh),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      18,
                      24,
                      AppSpacing.tabBarClearance + bottomInset,
                    ),
                    // One block rather than a lazy list: everything is built, so the
                    // tour can scroll to any part of the page and point at it.
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KeyedSubtree(
                            key: _weekKey,
                            child: !move.loaded
                                ? const _Skeleton(
                                    key: ValueKey('week_loading'),
                                    height: 250,
                                  )
                                : MoveWeekCard(
                                    week: move.week,
                                    nudge: sliceToTry(move.week),
                                    plateKey: _plateKey,
                                  ),
                          ),
                          const SizedBox(height: 22),
                          ..._library(library),
                          const SizedBox(height: 22),
                          _logRow(),
                          const SizedBox(height: 22),
                          KeyedSubtree(
                            key: _planKey,
                            child: _PlanChoice(
                              percent: move.week.eatBackPercent,
                              addedKcal: move.week.eatBackKcal,
                            ),
                          ),
                          if (move.entries.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            ..._recent(move.entries),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _library(AsyncValue<WorkoutLibrary> library) {
    return library.when(
      loading: () => const [
        _Skeleton(key: ValueKey('library_loading'), height: 160),
      ],
      error: (_, _) => [
        AppCard(
          key: const ValueKey('library_error'),
          child: Column(
            children: [
              Text(
                tr(
                  "Couldn't load the workouts. Check your connection and try again.",
                ),
                style: AppType.body(
                  size: 14,
                  color: TrackerColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              AppButton.glass(
                key: const ValueKey('library_retry'),
                label: tr('Try again'),
                expand: false,
                onPressed: () => ref.invalidate(workoutLibraryProvider),
              ),
            ],
          ),
        ),
      ],
      data: (lib) {
        final all = lib.routines;
        final bites = bitesOf(all);
        final shown = filterLibrary(
          all,
          maxMinutes: _maxMinutes,
          slice: _slice,
        );
        return [
          KeyedSubtree(key: _feelingsKey, child: _feelings(all)),
          if (bites.isNotEmpty) ...[
            const SizedBox(height: 22),
            KeyedSubtree(
              key: _bitesKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Move bites'), style: AppType.sectionLabel()),
                  const SizedBox(height: 2),
                  Text(
                    tr('A few minutes, anywhere.'),
                    style: AppType.caption(size: 12.5),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 152,
                    child: ListView.separated(
                      key: const ValueKey('bites'),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: bites.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => BiteTile(
                        key: ValueKey('bite_${bites[i].id}'),
                        card: bites[i],
                        onTap: () => _open(bites[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          KeyedSubtree(
            key: _libraryKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('All workouts'), style: AppType.sectionLabel()),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    key: const ValueKey('length_filters'),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: [
                      for (final m in lengthFilters) ...[
                        FilterChipButton(
                          key: ValueKey('length_$m'),
                          label: m == 0
                              ? tr('Any length')
                              : tr('Up to {n} min', {'n': '$m'}),
                          selected: _maxMinutes == m,
                          onTap: () => setState(() => _maxMinutes = m),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    key: const ValueKey('slice_filters'),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: [
                      FilterChipButton(
                        key: const ValueKey('slice_all'),
                        label: tr('All'),
                        selected: _slice == null,
                        onTap: () => setState(() => _slice = null),
                      ),
                      const SizedBox(width: 8),
                      for (final s in MoveSlice.values) ...[
                        FilterChipButton(
                          key: ValueKey('slice_${s.name}'),
                          label: s.label,
                          icon: MoveIcon.slice(s, size: 16),
                          selected: _slice == s,
                          onTap: () =>
                              setState(() => _slice = _slice == s ? null : s),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                tr('Nothing matches. Try a longer length or another kind.'),
                key: const ValueKey('library_none'),
                style: AppType.body(
                  size: 14,
                  color: TrackerColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final c in shown) ...[
              WorkoutTile(
                key: ValueKey('workout_${c.id}'),
                card: c,
                onTap: () => _open(c),
              ),
              const SizedBox(height: 10),
            ],
        ];
      },
    );
  }

  Widget _feelings(List<WorkoutCard> all) {
    final picks = _feeling == null
        ? const <WorkoutCard>[]
        : suggestFor(_feeling!, all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('How are you feeling?'), style: AppType.sectionLabel()),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            key: const ValueKey('feelings'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final m in Mood.values) ...[
                FilterChipButton(
                  key: ValueKey('feeling_${m.name}'),
                  label: m.label,
                  icon: MoveIcon.mood(m, size: 16),
                  selected: _feeling == m,
                  onTap: () =>
                      setState(() => _feeling = _feeling == m ? null : m),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (_feeling != null && picks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(tr('Ideas for now'), style: AppType.caption(size: 12.5)),
          const SizedBox(height: 8),
          for (final c in picks) ...[
            WorkoutTile(
              key: ValueKey('pick_${c.id}'),
              card: c,
              onTap: () => _open(c),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _logRow() {
    return AppCard(
      key: const ValueKey('log_row'),
      padding: const EdgeInsets.all(16),
      onTap: () => showLogMovementSheet(context),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.plus_circle,
            size: 24,
            color: TrackerColors.accentStartText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Log something else'),
                  style: AppType.body(
                    size: 15,
                    color: TrackerColors.textPrimary,
                  ),
                ),
                Text(
                  tr('A walk, a swim, a game, anything you did.'),
                  style: AppType.caption(size: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _recent(List<MovementEntry> entries) {
    return [
      Text(tr('Recently'), style: AppType.sectionLabel()),
      const SizedBox(height: 10),
      for (final e in entries.take(8)) ...[
        _EntryRow(
          key: ValueKey('entry_${e.id}'),
          entry: e,
          onTap: () => _confirmDelete(e),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  Future<void> _confirmDelete(MovementEntry e) async {
    final remove = await showAppSheet<bool>(
      context: context,
      builder: (ctx) => AppSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MoveIcon.slice(e.slice, size: 20, tile: true),
                const SizedBox(width: 12),
                Expanded(child: Text(e.label, style: AppType.title())),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('{n} min', {'n': '${e.minutes}'}),
              style: AppType.body(size: 14, color: TrackerColors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppButton.glass(
              key: const ValueKey('entry_remove'),
              label: tr('Remove this'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
            AppButton.glass(
              key: const ValueKey('entry_keep'),
              label: tr('Keep it'),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (remove == true) await ref.read(moveProvider.notifier).delete(e.id);
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({super.key, required this.entry, required this.onTap});

  final MovementEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TrackerColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: TrackerColors.border),
        ),
        child: Row(
          children: [
            MoveIcon.slice(entry.slice, size: 18, tile: true),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(
                  size: 14.5,
                  color: TrackerColors.textPrimary,
                ),
              ),
            ),
            Text(
              tr('{n} min', {'n': '${entry.minutes}'}),
              style: AppType.body(
                size: 13.5,
                color: TrackerColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      borderRadius: BorderRadius.circular(AppRadii.container),
      child: SizedBox(height: height, width: double.infinity),
    );
  }
}

/// "Add movement to my calorie plan": off until the person turns it on. Plainly
/// worded, because the numbers behind it are rough (roadmap D11).
class _PlanChoice extends ConsumerStatefulWidget {
  const _PlanChoice({required this.percent, required this.addedKcal});

  final int percent;
  final int addedKcal;

  @override
  ConsumerState<_PlanChoice> createState() => _PlanChoiceState();
}

class _PlanChoiceState extends ConsumerState<_PlanChoice> {
  bool _failed = false;
  bool _busy = false;

  static const options = [0, 25, 50];

  Future<void> _choose(int percent) async {
    if (_busy || percent == widget.percent) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref.read(moveProvider.notifier).setEatBack(percent);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('plan_choice'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Add movement to my calorie plan'),
            style: AppType.body(size: 15, color: TrackerColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'Off by default. Your plan already allows for your activity level. If you turn this on, a share of the rough estimate for what you log is added to today’s calories. Estimates are rough, so a smaller share is the safer choice. At most 500 kcal a day.',
            ),
            key: const ValueKey('plan_choice_text'),
            style: AppType.caption(size: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final p in options) ...[
                Expanded(
                  child: FilterChipButton(
                    key: ValueKey('eat_back_$p'),
                    label: p == 0 ? tr('Off') : '$p%',
                    selected: widget.percent == p,
                    onTap: () => _choose(p),
                  ),
                ),
                if (p != options.last) const SizedBox(width: 8),
              ],
            ],
          ),
          if (widget.addedKcal > 0) ...[
            const SizedBox(height: 10),
            Text(
              tr('+{n} kcal added to today’s plan', {
                'n': '${widget.addedKcal}',
              }),
              key: const ValueKey('plan_added'),
              style: AppType.body(
                size: 13.5,
                color: TrackerColors.accentStartText,
              ),
            ),
          ],
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              tr("Couldn't save. Try again"),
              key: const ValueKey('plan_failed'),
              style: AppType.body(size: 13.5, color: TrackerColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// The spotlight tour of the Workouts tab, top to bottom as the page is laid
/// out, then the two buttons in the corner. Steps whose target is not there
/// (the library failed to load, say) are skipped by the tour itself.
@visibleForTesting
List<TourStep> workoutsTourSteps({
  required GlobalKey weekKey,
  required GlobalKey plateKey,
  required GlobalKey feelingsKey,
  required GlobalKey bitesKey,
  required GlobalKey libraryKey,
  required GlobalKey planKey,
  required GlobalKey logKey,
  required GlobalKey helpKey,
}) => [
  TourStep(
    targetKey: weekKey,
    icon: CupertinoIcons.calendar,
    title: tr('Your week, at a glance'),
    body: tr(
      'The ring fills as you move toward a weekly guide. The dots are your days. Rest days stay empty, and that is completely fine.',
    ),
    scrollIntoView: true,
    padding: 4,
  ),
  TourStep(
    targetKey: plateKey,
    icon: CupertinoIcons.sparkles,
    title: tr('Fill your move plate'),
    body: tr(
      'Strength, cardio, gentle movement, and dance and play. A slice lights up when you do something in it. Try them all, no pressure.',
    ),
    scrollIntoView: true,
    padding: 6,
  ),
  TourStep(
    targetKey: feelingsKey,
    icon: CupertinoIcons.smiley,
    title: tr('Pick by how you feel'),
    body: tr(
      'Tired? Stressed? Feeling good? Tap a feeling and get a few ideas that suit. We never save it or share it.',
    ),
    scrollIntoView: true,
    padding: 6,
  ),
  TourStep(
    targetKey: bitesKey,
    icon: CupertinoIcons.timer,
    title: tr('Tiny bites, big wins'),
    body: tr(
      'Only got 2 minutes? Perfect. Swipe through short sessions for between meetings or while the kettle boils.',
    ),
    scrollIntoView: true,
    padding: 6,
  ),
  TourStep(
    targetKey: libraryKey,
    icon: CupertinoIcons.slider_horizontal_3,
    title: tr('Find your fit'),
    body: tr(
      'Filter by length or kind, then tap any workout to see its moves and hit Start. The player counts for you.',
    ),
    scrollIntoView: true,
    padding: 6,
  ),
  TourStep(
    targetKey: planKey,
    icon: CupertinoIcons.flame,
    title: tr('Your calories, your call'),
    body: tr(
      'Off by default. If you like, add a share of what you log to today’s calories. Estimates are rough, so go gently.',
    ),
    scrollIntoView: true,
    padding: 4,
  ),
  TourStep(
    targetKey: logKey,
    icon: CupertinoIcons.add_circled,
    title: tr('Did something else? Count it'),
    body: tr('A walk, a swim, a kickabout. Tap + and log it. Anything counts.'),
    shape: TourShape.circle,
    padding: 6,
  ),
  TourStep(
    targetKey: helpKey,
    icon: CupertinoIcons.question_circle,
    title: tr('Need a recap?'),
    body: tr('Tap ? any time to see this tour again. Now go and move!'),
    shape: TourShape.circle,
    padding: 6,
  ),
];
