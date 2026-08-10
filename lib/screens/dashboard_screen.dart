import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food_entry.dart';
import '../providers/food_log_provider.dart';
import '../providers/user_provider.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/calorie_ring.dart';
import '../widgets/meal_section.dart';
import 'food_search_screen.dart';
import 'photo_review_screen.dart';
import '../services/photo_estimation.dart';
import '../services/food_search_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showMealPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TrackerColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TrackerColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text('Log a Meal', style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...MealType.values.map((meal) {
              return ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: TrackerColors.primary),
                title: Text(meal.name.toUpperCase(), style: Theme.of(sheetContext).textTheme.bodyLarge),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _captureAndAnalyze(context, ref, meal);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndAnalyze(BuildContext context, WidgetRef ref, MealType meal) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (photo == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: TrackerColors.primary)),
    );

    try {
      final bytes = await photo.readAsBytes();
      final service = PhotoEstimationService();
      final detected = await service.analyzePhoto(bytes);

      // Cross-reference each detected food against USDA to fill in
      // macros, since Gemini only returns name + estimated grams now.
      await FoodSearchService().enrichDetectedFoods(detected);

      if (!context.mounted) return;
      Navigator.pop(context);

      final entries = await Navigator.push<List<FoodEntry>>(
        context,
        MaterialPageRoute(builder: (context) => PhotoReviewScreen(items: detected, mealType: meal)),
      );

      if (entries != null) {
        for (final entry in entries) {
          await ref.read(foodLogProvider.notifier).addEntry(entry);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _openFoodSearch(BuildContext context, WidgetRef ref, MealType meal) async {
    final entry = await Navigator.push<FoodEntry>(
      context,
      MaterialPageRoute(builder: (context) => FoodSearchScreen(mealType: meal)),
    );
    if (entry == null) return;
    await ref.read(foodLogProvider.notifier).addEntry(entry);
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final foodLog = ref.watch(foodLogProvider);

    final target = profile?.calorieTarget ?? 2000;
    final consumed = foodLog.totalCalories;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 70,
            floating: true,
            pinned: true,
            backgroundColor: TrackerColors.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              centerTitle: false,
              title: Text(
                'Welcome Back 👋',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_outlined),
                onPressed: () => _logout(context),
              ),
              const SizedBox(width: 8),
            ],
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMealPicker(context, ref),
        icon: const Icon(Icons.camera_alt),
        label: const Text('SCAN MEAL'),
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _macroPill(BuildContext context, String label, double current, int target, Color color) {
    return Column(
      children: [
        Text(
          '${current.round()}g',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: TrackerColors.textSecondary,
              ),
        ),
      ],
    );
  }
}