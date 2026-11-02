import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food_entry.dart';
import '../providers/food_log_provider.dart';
import '../providers/user_provider.dart';
import '../services/log_cache_reader.dart';
import '../services/photo_estimation.dart';
import '../services/server_handshake.dart';
import '../services/tour_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_tour.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/glass.dart';
import '../widgets/macro_breakdown.dart';
import '../widgets/meal_section.dart';
import '../widgets/save_toast.dart';
import '../widgets/shimmer.dart';
import 'auth_gate.dart';
import 'food_search_screen.dart';
import 'main_shell.dart';
import 'photo_review_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// A past day being browsed, or null for "today", which follows the clock.
  /// This used to be a date fixed when the screen was created, so after
  /// midnight the dashboard showed "Yesterday" with an empty list and no add
  /// buttons until the app was restarted.
  DateTime? _pastDay;
  List<FoodEntry> _pastEntries = const [];
  late final AppLifecycleListener _lifecycle;
  bool _loadingPast = false;
  int _streak = 0;

  // First-run tour targets.
  final _ringKey = GlobalKey(debugLabel: 'tourRing');
  final _addButtonKey = GlobalKey(debugLabel: 'tourAddButton');
  final _cameraButtonKey = GlobalKey(debugLabel: 'tourCamera');
  bool _tourScheduled = false;

  /// Lets the splash fade, the shell's route transition finish and the ring
  /// card's fade-in settle before anything is measured. Starting on the first
  /// frame spotlighted targets mid-animation, in the wrong place.
  static const _tourDelay = Duration(milliseconds: 1400);

  DateTime get _viewDay => _pastDay ?? DateTime.now();

  bool get _isToday => _pastDay == null || LogCacheReader.isSameDay(_pastDay!, DateTime.now());

  @override
  void initState() {
    super.initState();
    _refreshStreak();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Back in the foreground, possibly on a new day (timers don't run while a
  /// phone app is suspended): roll the log over and refresh the date label
  /// and streak.
  void _onResume() {
    // The server may have gone to sleep while the app was in the background;
    // start waking it before the user's next action needs it.
    ServerWarmup.ping();
    ref.read(foodLogProvider.notifier).ensureCurrentDay();
    _refreshStreak();
    if (mounted) setState(() {});
  }

  Future<void> _maybeStartTour() async {
    if (_tourScheduled) return;
    _tourScheduled = true;
    if (await TourService.hasSeen(TourService.dashboard)) return;
    await Future<void>.delayed(_tourDelay);
    if (!mounted || !_canShowTour()) return;

    await AppTour.show(context, steps: _tourSteps());
    // Skipped, finished or dismissed with back: don't show it again.
    await TourService.markSeen(TourService.dashboard);
  }

  /// Only start when the dashboard is what the user is actually looking at:
  /// its tab is selected and nothing (a dialog, a pushed screen, a sheet)
  /// sits on top of the shell. Otherwise wait for the next launch.
  bool _canShowTour() {
    if (!TickerMode.valuesOf(context).enabled) return false; // another tab
    final local = ModalRoute.of(context);
    if (local != null && !local.isCurrent) return false; // pushed within the tab
    final shellContext = MainShell.insightsTabKey.currentContext;
    if (shellContext == null) return false;
    final shell = ModalRoute.of(shellContext);
    return shell == null || shell.isCurrent;
  }

  List<TourStep> _tourSteps() => [
        TourStep(
          targetKey: _ringKey,
          icon: CupertinoIcons.flame_fill,
          title: 'Your daily budget',
          body: 'The ring shows how many calories you have left today. '
              'It fills up as you log meals.',
          radius: AppRadii.container,
          padding: 6,
        ),
        TourStep(
          targetKey: _addButtonKey,
          icon: CupertinoIcons.search,
          title: 'Log food by name',
          body: 'Search for any food, then enter how much you had.',
          shape: TourShape.circle,
          padding: 5,
        ),
        TourStep(
          targetKey: _cameraButtonKey,
          icon: CupertinoIcons.camera_fill,
          title: 'Or just snap a photo',
          body: "Take a picture of your plate. We'll spot the foods and estimate "
              'portions for you to check before saving.',
          shape: TourShape.circle,
          padding: 6,
        ),
        TourStep(
          targetKey: MainShell.insightsTabKey,
          icon: CupertinoIcons.chart_bar_alt_fill,
          title: 'Your weekly coach',
          body: 'Insights shows your trends and personal tips based on what '
              "you've logged.",
          shape: TourShape.pill,
          padding: 6,
        ),
      ];

  Future<void> _refreshStreak() async {
    final streak = await LogCacheReader.currentStreak();
    if (!mounted) return;
    if (streak == _streak) return;
    setState(() => _streak = streak);
  }

  Future<void> _selectDay(DateTime day) async {
    final isToday = LogCacheReader.isSameDay(day, DateTime.now());
    if (isToday) {
      setState(() {
        _pastDay = null;
        _pastEntries = const [];
      });
      return;
    }

    setState(() {
      _pastDay = day;
      _loadingPast = true;
    });
    final entries = await LogCacheReader.entriesFor(day);
    if (!mounted) return;
    setState(() {
      _pastEntries = entries;
      _loadingPast = false;
    });
  }

  Future<MealType?> _showMealPicker(BuildContext context) {
    return showAppSheet<MealType>(
      context: context,
      builder: (sheetContext) => AppSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log a Meal', style: AppType.title(), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Which meal are we adding to?', style: AppType.callout(), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ...MealType.values.map(
              (meal) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppButton.glass(
                  label: meal.name,
                  icon: _iconFor(meal),
                  height: 50,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(sheetContext).pop(meal);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(MealType meal) {
    switch (meal) {
      case MealType.breakfast:
        return CupertinoIcons.sun_max_fill;
      case MealType.lunch:
        return CupertinoIcons.sun_max;
      case MealType.dinner:
        return CupertinoIcons.moon_stars_fill;
      case MealType.snack:
        return CupertinoIcons.circle_grid_hex_fill;
    }
  }

  Future<void> _startScan(BuildContext context) async {
    final meal = await _showMealPicker(context);
    if (meal == null || !context.mounted) return;
    await _captureAndAnalyze(context, meal);
  }

  Future<void> _startManualAdd(BuildContext context) async {
    final meal = await _showMealPicker(context);
    if (meal == null || !context.mounted) return;
    await _openFoodSearch(context, meal);
  }

  Future<void> _captureAndAnalyze(BuildContext context, MealType meal) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo == null || !context.mounted) return;

    var progressDialogVisible = true;
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x99000000),
      builder: (context) => const AppLoadingDialog(label: 'Analysing your meal…'),
    );

    try {
      final bytes = await photo.readAsBytes();
      final service = PhotoEstimationService();
      final detected = await service.analyzePhoto(bytes);

      if (detected.isEmpty) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogVisible = false;
        await showAppDialog(
          context: context,
          title: 'No food detected',
          message: "We couldn't identify any food in that photo. Try getting closer or improving the lighting.",
          confirmLabel: 'OK',
        );
        return;
      }

      // Macros arrive with the detection: the backend matches each food in
      // USDA in the same request.
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressDialogVisible = false;

      final entries = await Navigator.push<List<FoodEntry>>(
        context,
        CupertinoPageRoute(builder: (context) => PhotoReviewScreen(items: detected, mealType: meal)),
      );

      if (!context.mounted) return;
      if (entries != null && entries.isNotEmpty) {
        final saveState = ValueNotifier(SaveToastState.loading);
        final overlay = Overlay.of(context);
        late final OverlayEntry saveToastEntry;
        saveToastEntry = OverlayEntry(
          builder: (context) => Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: IgnorePointer(
              child: Center(
                child: ValueListenableBuilder<SaveToastState>(
                  valueListenable: saveState,
                  builder: (context, state, child) => SaveToast(state: state),
                ),
              ),
            ),
          ),
        );
        overlay.insert(saveToastEntry);

        void dismissSaveToast() {
          if (saveToastEntry.mounted) saveToastEntry.remove();
          saveState.dispose();
        }

        try {
          await Future.wait(
            entries.map((entry) => ref.read(foodLogProvider.notifier).addEntry(entry)),
          );
          saveState.value = SaveToastState.success;
          _refreshStreak();
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          dismissSaveToast();
        } catch (_) {
          dismissSaveToast();
          rethrow;
        } finally {
          progressDialogVisible = false;
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      if (progressDialogVisible) Navigator.of(context, rootNavigator: true).pop();

      final message = e is PhotoAnalysisException
          ? e.message
          : "Something went wrong while saving your meal. Please try again.";

      await showAppDialog(
        context: context,
        title: 'Couldn\'t scan meal',
        message: message,
        confirmLabel: 'OK',
      );
    }
  }

  Future<void> _openFoodSearch(BuildContext context, MealType meal) async {
    final entry = await Navigator.push<FoodEntry>(
      context,
      CupertinoPageRoute(builder: (context) => FoodSearchScreen(mealType: meal)),
    );
    if (entry == null) return;
    await ref.read(foodLogProvider.notifier).addEntry(entry);
    _refreshStreak();
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  String get _dateLabel {
    final now = DateTime.now();
    final day = _viewDay;
    if (LogCacheReader.isSameDay(day, now)) return 'Today';
    if (LogCacheReader.isSameDay(day, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[day.month - 1]} ${day.day}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<FoodEntry>>(foodLogProvider, (previous, next) => _refreshStreak());

    final profile = ref.watch(userProfileProvider);
    final foodLog = ref.watch(foodLogProvider);

    final entries = _isToday ? foodLog : _pastEntries;
    final target = profile?.calorieTarget ?? 2000;
    final consumed = entries.totalCalories;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: TrackerColors.background),
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: FrostedGlass(
                    opacity: 0.9,
                    tint: TrackerColors.navFill,
                    blur: 24,
                    borderRadius: BorderRadius.zero,
                    border: AppDecor.hairlineTop,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DashboardHeader(
                            streakDays: _streak,
                            dateLabel: _dateLabel,
                            canGoNext: !_isToday,
                            onPreviousDay: () => _selectDay(
                              _viewDay.subtract(const Duration(days: 1)),
                            ),
                            onNextDay: () =>
                                _selectDay(_viewDay.add(const Duration(days: 1))),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 20, top: 6, bottom: 6),
                          child: AppIconButton(
                            icon: CupertinoIcons.square_arrow_right,
                            size: 38,
                            iconSize: 17,
                            color: TrackerColors.textSecondary,
                            onPressed: () => _logout(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            KeyedSubtree(
                              key: _ringKey,
                              child: _RingCard(
                                consumed: consumed,
                                target: target,
                                isToday: _isToday,
                                loading: _loadingPast,
                              ),
                            ),
                            const SizedBox(height: 14),
                            MacroBreakdownCard(
                              protein: entries.totalProtein,
                              proteinTarget: profile?.proteinTargetG ?? 0,
                              carbs: entries.totalCarbs,
                              carbsTarget: profile?.carbsTargetG ?? 0,
                              fat: entries.totalFat,
                              fatTarget: profile?.fatTargetG ?? 0,
                            ),
                            const SizedBox(height: 22),
                            SectionHeader(
                              label: _isToday ? "Today's meals" : 'Meals',
                              trailing: _isToday
                                  ? Text(
                                      entries.isEmpty
                                          ? 'Nothing yet'
                                          : '${entries.length} item${entries.length == 1 ? '' : 's'}',
                                      style: AppType.caption(
                                        color: TrackerColors.textTertiary,
                                        size: 11,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            ...MealType.values.map(
                              (meal) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: MealSection(
                                  title: meal.name,
                                  entries: entries.forMeal(meal),
                                  onAdd: () => _openFoodSearch(context, meal),
                                  onRemove: (id) =>
                                      ref.read(foodLogProvider.notifier).removeEntry(id),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Center(
                              child: Text(
                                _isToday
                                    ? 'Swipe a food left to delete it'
                                    : 'Viewing a cached day — logging resumes on Today',
                                style: AppType.caption(
                                  color: TrackerColors.textTertiary,
                                  size: 11,
                                ),
                              ),
                            ),
                            SizedBox(height: AppSpacing.tabBarClearance + bottomInset),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isToday)
            Positioned(
              right: 24,
              bottom: bottomInset + 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  KeyedSubtree(
                    key: _addButtonKey,
                    child: AppFab(
                      icon: CupertinoIcons.search,
                      size: 50,
                      iconSize: 21,
                      onPressed: () => _startManualAdd(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  KeyedSubtree(
                    key: _cameraButtonKey,
                    child: AppFab(
                      icon: CupertinoIcons.camera,
                      gradient: TrackerColors.calorieGradient,
                      onPressed: () => _startScan(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RingCard extends StatelessWidget {
  const _RingCard({
    required this.consumed,
    required this.target,
    required this.isToday,
    required this.loading,
  });

  final int consumed;
  final int target;
  final bool isToday;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppCard(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Center(child: SkeletonRing(size: 190, strokeWidth: 16)),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        glow: TrackerColors.accentStart,
        child: Column(
          children: [
            CalorieRing(consumed: consumed, target: target),
            if (!isToday) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.clock, size: 13, color: TrackerColors.textTertiary),
                  const SizedBox(width: 6),
                  Text('Cached day', style: AppType.caption(size: 11)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
