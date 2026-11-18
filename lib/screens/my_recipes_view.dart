import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/house_recipe.dart';
import '../providers/house_recipes_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/house_recipe_sheet.dart';
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';
import 'new_recipe_screen.dart';

/// "Mine": the person's own recipes. Private; log one in a tap.
class MyRecipesView extends ConsumerStatefulWidget {
  const MyRecipesView({super.key});

  @override
  ConsumerState<MyRecipesView> createState() => _MyRecipesViewState();
}

class _MyRecipesViewState extends ConsumerState<MyRecipesView> {
  @override
  void initState() {
    super.initState();
    // Fresh each time the tab is opened; the list on screen stays until then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(houseRecipesProvider.notifier).load();
    });
  }

  void _create() {
    Navigator.push(context, CupertinoPageRoute<void>(builder: (_) => const NewRecipeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(houseRecipesProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      key: const ValueKey('my_recipes'),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      children: [
        AppButton(key: const ValueKey('new_recipe'), label: 'New recipe', icon: CupertinoIcons.add, onPressed: _create),
        const SizedBox(height: AppSpacing.lg),
        if (state.loading && state.recipes.isEmpty)
          const SkeletonRows(count: 3)
        else if (state.failed && state.recipes.isEmpty)
          Column(
            children: [
              AppEmptyState(
                icon: CupertinoIcons.wifi_exclamationmark,
                title: "Couldn't load your recipes",
                message: 'Check your connection and try again.',
                accent: TrackerColors.error,
              ),
              CupertinoButton(
                key: const ValueKey('retry_recipes'),
                onPressed: () => ref.read(houseRecipesProvider.notifier).load(),
                child: const Text('Try again'),
              ),
            ],
          )
        else if (state.recipes.isEmpty)
          const AppEmptyState(
            icon: CupertinoIcons.book,
            title: 'Your recipes live here',
            message: 'Save the dishes you cook often, then log them in one tap. '
                'You can also save a meal you’ve already logged from Today.',
          )
        else
          for (final r in state.recipes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _Row(recipe: r, onTap: () => showHouseRecipeSheet(context, r)),
            ),
        SizedBox(height: AppSpacing.tabBarClearance + bottomInset),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.recipe, required this.onTap});

  final HouseRecipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: ValueKey('house_${recipe.id}'),
      onTap: onTap,
      haptics: true,
      borderRadius: AppRadii.containerAll,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        borderRadius: AppRadii.containerAll,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15)),
                  const SizedBox(height: 4),
                  Text(
                    '${recipe.calories} kcal per serving${recipe.estimated ? ' · estimated' : ''}',
                    style: AppType.caption(size: 12),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 15, color: TrackerColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
