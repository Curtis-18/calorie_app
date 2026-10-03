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
import '../services/food_search_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/glass.dart';
import '../widgets/macro_breakdown.dart';
import '../widgets/meal_section.dart';
import '../widgets/save_toast.dart';
import '../widgets/shimmer.dart';
import 'auth_gate.dart';
import 'food_search_screen.dart';
import 'photo_review_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime _selectedDay = DateTime.now();
  List<FoodEntry> _pastEntries = const [];
  bool _loadingPast = false;
  int _streak = 0;

  bool get _isToday => LogCacheReader.isSameDay(_selectedDay, DateTime.now());

  @override
  void initState() {
    super.initState();
    _refreshStreak();
  }

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
        _selectedDay = day;
        _pastEntries = const [];
      });
      return;
    }

    setState(() {
      _selectedDay = day;
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

      // Cross-reference each detected food against USDA to fill in
      // macros, since Gemini only returns name + estimated grams now.
      await FoodSearchService().enrichDetectedFoods(detected);

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
    if (LogCacheReader.isSameDay(_selectedDay, now)) return 'Today';
    if (LogCacheReader.isSameDay(_selectedDay, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[_selectedDay.month - 1]} ${_selectedDay.day}';
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
                              _selectedDay.subtract(const Duration(days: 1)),
                            ),
                            onNextDay: () =>
                                _selectDay(_selectedDay.add(const Duration(days: 1))),
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
                            _RingCard(
                              consumed: consumed,
                              target: target,
                              isToday: _isToday,
                              loading: _loadingPast,
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
                  AppFab(
                    icon: CupertinoIcons.search,
                    size: 50,
                    iconSize: 21,
                    onPressed: () => _startManualAdd(context),
                  ),
                  const SizedBox(width: 12),
                  AppFab(
                    icon: CupertinoIcons.add,
                    gradient: TrackerColors.calorieGradient,
                    onPressed: () => _startScan(context),
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
