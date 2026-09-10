import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food_entry.dart';
import '../providers/food_log_provider.dart';
import '../providers/user_provider.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/meal_section.dart';
import '../widgets/save_toast.dart';
import 'auth_gate.dart';
import 'food_search_screen.dart';
import 'photo_review_screen.dart';
import '../services/photo_estimation.dart';
import '../services/food_search_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showMealPicker(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Log a Meal'),
        actions: [
          ...MealType.values.map((meal) => CupertinoActionSheetAction(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(sheetContext);
              _captureAndAnalyze(context, ref, meal);
            },
            child: Text(meal.name.toUpperCase()),
          )),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _captureAndAnalyze(BuildContext context, WidgetRef ref, MealType meal) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo == null || !context.mounted) return;

    var progressDialogVisible = true;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator(color: TrackerColors.primary)),
    );

    try {
      final bytes = await photo.readAsBytes();
      final service = PhotoEstimationService();
      final detected = await service.analyzePhoto(bytes);

      if (detected.isEmpty) {
        if (!context.mounted) return;
        Navigator.pop(context);
        progressDialogVisible = false;
        showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('No food detected'),
            content: const Text(
              "We couldn't identify any food in that photo. Try getting closer or improving the lighting.",
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Cross-reference each detected food against USDA to fill in
      // macros, since Gemini only returns name + estimated grams now.
      await FoodSearchService().enrichDetectedFoods(detected);

      if (!context.mounted) return;
      Navigator.pop(context);
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
      if (progressDialogVisible) Navigator.pop(context);

      final message = e is PhotoAnalysisException
          ? e.message
          : "Something went wrong while saving your meal. Please try again.";

      showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Couldn\'t scan meal'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _openFoodSearch(BuildContext context, WidgetRef ref, MealType meal) async {
    final entry = await Navigator.push<FoodEntry>(
      context,
      CupertinoPageRoute(builder: (context) => FoodSearchScreen(mealType: meal)),
    );
    if (entry == null) return;
    await ref.read(foodLogProvider.notifier).addEntry(entry);
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final foodLog = ref.watch(foodLogProvider);

    final target = profile?.calorieTarget ?? 2000;
    final consumed = foodLog.totalCalories;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Welcome Back'),
            backgroundColor: CupertinoColors.systemGroupedBackground,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _logout(context),
              child: const Icon(CupertinoIcons.square_arrow_right),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: CalorieRing(consumed: consumed, target: target, width: 200),
                  ),
                ),
                const SizedBox(height: 14),

                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macroPill(context, 'Carbs', foodLog.totalCarbs, profile?.carbsTargetG ?? 0, TrackerColors.macroCarbs),
                      _macroPill(context, 'Protein', foodLog.totalProtein, profile?.proteinTargetG ?? 0, TrackerColors.macroProtein),
                      _macroPill(context, 'Fat', foodLog.totalFat, profile?.fatTargetG ?? 0, TrackerColors.macroFat),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  'TODAY\'S MEALS',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: TrackerColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 10),

                ...MealType.values.map((meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MealSection(
                        title: meal.name.toUpperCase(),
                        entries: foodLog.forMeal(meal),
                        onAdd: () => _openFoodSearch(context, ref, meal),
                        onRemove: (id) => ref.read(foodLogProvider.notifier).removeEntry(id),
                      ),
                    )),
                const SizedBox(height: 80),
              ]),
            ),
          ),
            ],
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: CupertinoButton.filled(
              onPressed: () => _showMealPicker(context, ref),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Icon(CupertinoIcons.camera), SizedBox(width: 8), Text('Scan meal')],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroPill(BuildContext context, String label, double current, int target, Color color) {
    return Column(
      children: [
        Text(
          '${current.round()}g',
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 10,
                color: TrackerColors.textSecondary,
              ),
        ),
      ],
    );
  }
}