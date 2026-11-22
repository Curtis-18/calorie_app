import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/house_recipe.dart';
import '../models/recipe_goal.dart';
import '../models/recipe_tags.dart';
import '../providers/house_recipes_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/house_recipe_sheet.dart';
import '../widgets/pressable.dart';
import '../widgets/recipe_gallery.dart';
import '../widgets/app_dialog.dart';
import '../widgets/shimmer.dart';
import 'new_recipe_screen.dart';
import '../l10n/app_strings.dart';

/// "Mine": the person's own recipes. Private; log one in a tap.
class MyRecipesView extends ConsumerStatefulWidget {
  const MyRecipesView({super.key});

  @override
  ConsumerState<MyRecipesView> createState() => _MyRecipesViewState();
}

class _MyRecipesViewState extends ConsumerState<MyRecipesView> {
  /// The goal filter. Not saved: it only narrows the list while you look.
  RecipeGoal? _goal;

  /// The quick filters (all of the chosen ones must fit). Not saved either.
  final Set<RecipeTag> _tags = {};

  bool get _filtering => _goal != null || _tags.isNotEmpty;

  bool _fits(HouseRecipe r) => (_goal == null || r.goals.contains(_goal)) && _tags.every(r.tags.contains);

  @override
  void initState() {
    super.initState();
    // Fresh each time the tab is opened; the list on screen stays until then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(houseRecipesProvider.notifier).load();
    });
  }

  Future<void> _open(String id) =>
      openRecipeById(context, ref.read(houseRecipesProvider.notifier), id);

  Future<void> _openCollection(RecipeCollection c) async {
    final picked = await showCupertinoModalPopup<Object>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(c.name),
        message: c.items.isEmpty ? Text(tr('Nothing here yet. Add recipes from a recipe’s Collections button.')) : null,
        actions: [
          for (final i in c.items)
            CupertinoActionSheetAction(
              key: ValueKey('collection_item_${i.id}'),
              onPressed: () => Navigator.pop(context, i),
              child: Text(i.mine ? i.title : tr('{title} (from a friend)', {'title': i.title})),
            ),
          if (!c.isDefault)
            CupertinoActionSheetAction(
              key: const ValueKey('delete_collection'),
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, 'delete'),
              child: Text(tr('Delete this collection')),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text(tr('Close'))),
      ),
    );
    if (!mounted || picked == null) return;
    if (picked is RecipeBrief) {
      await _open(picked.id);
    } else {
      final error = await ref.read(houseRecipesProvider.notifier).deleteCollection(c.id);
      if (error != null && mounted) {
        await showAppDialog(context: context, title: tr("Couldn't delete it"), message: error, confirmLabel: 'OK');
      }
    }
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
        AppButton(key: const ValueKey('new_recipe'), label: tr('New recipe'), icon: CupertinoIcons.add, onPressed: _create),
        const SizedBox(height: AppSpacing.lg),
        if (state.loading && state.recipes.isEmpty)
          const SkeletonRows(count: 3)
        else if (state.failed && state.recipes.isEmpty)
          Column(
            children: [
              AppEmptyState(
                icon: CupertinoIcons.wifi_exclamationmark,
                title: tr("Couldn't load your recipes"),
                message: tr('Check your connection and try again.'),
                accent: TrackerColors.error,
              ),
              CupertinoButton(
                key: const ValueKey('retry_recipes'),
                onPressed: () => ref.read(houseRecipesProvider.notifier).load(),
                child: Text(tr('Try again')),
              ),
            ],
          )
        else if (state.recipes.isEmpty)
          AppEmptyState(
            icon: CupertinoIcons.book,
            title: tr('Your recipes live here'),
            message: tr('Save the dishes you cook often, then log them in one tap. You can also save a meal you’ve already logged from Today.'),
          )
        else ...[
          if (state.highlights.isNotEmpty) ...[
            SectionHeader(label: tr('Highlights')),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 96,
              child: ListView(
                key: const ValueKey('highlights'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final h in state.highlights)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _HighlightTile(brief: h, onTap: () => _open(h.id)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (state.collections.isNotEmpty) ...[
            SectionHeader(label: tr('Collections')),
            const SizedBox(height: AppSpacing.md),
            for (final c in state.collections)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CollectionRow(collection: c, onTap: () => _openCollection(c)),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          SectionHeader(label: tr('All recipes')),
          const SizedBox(height: AppSpacing.md),
          _GoalFilter(selected: _goal, onChanged: (g) => setState(() => _goal = g)),
          const SizedBox(height: AppSpacing.md),
          _TagFilter(
            selected: _tags,
            onToggle: (t) => setState(() => _tags.contains(t) ? _tags.remove(t) : _tags.add(t)),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final r in _filtering ? state.recipes.where(_fits) : state.recipes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _Row(recipe: r, onTap: () => showHouseRecipeSheet(context, r)),
            ),
          if (_filtering && !state.recipes.any(_fits))
            Padding(
              key: const ValueKey('goal_none'),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(tr('None of your recipes match this yet.'), style: AppType.callout(size: 13)),
            ),
        ],
        SizedBox(height: AppSpacing.tabBarClearance + bottomInset),
      ],
    );
  }
}

/// All, then one chip per goal. A recipe is matched from its own calories and
/// protein; the rule is spelled out under the chips while one is on.
class _GoalFilter extends StatelessWidget {
  const _GoalFilter({required this.selected, required this.onChanged});

  final RecipeGoal? selected;
  final ValueChanged<RecipeGoal?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GoalChip(key: const ValueKey('goal_all'), label: tr('All'), selected: selected == null, onTap: () => onChanged(null)),
            for (final g in RecipeGoal.values)
              _GoalChip(key: ValueKey('goal_${g.name}'), label: g.label, selected: selected == g, onTap: () => onChanged(selected == g ? null : g)),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Text(selected!.rule, key: const ValueKey('goal_rule'), style: AppType.caption(size: 12)),
          const SizedBox(height: 2),
          Text(tr('Matched from each recipe’s calories and protein. A guide, not advice.'), style: AppType.caption(size: 11, color: TrackerColors.textTertiary)),
        ],
      ],
    );
  }
}

/// High protein, Low carb, Under 600 kcal: any mix, and with a goal above too.
/// The rule for each chosen chip is spelled out under the row.
class _TagFilter extends StatelessWidget {
  const _TagFilter({required this.selected, required this.onToggle});

  final Set<RecipeTag> selected;
  final ValueChanged<RecipeTag> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in RecipeTag.values)
              _GoalChip(key: ValueKey('tag_${t.name}'), label: t.label, selected: selected.contains(t), onTap: () => onToggle(t)),
          ],
        ),
        for (final t in RecipeTag.values)
          if (selected.contains(t)) ...[
            const SizedBox(height: 6),
            Text(t.rule, key: ValueKey('tag_rule_${t.name}'), style: AppType.caption(size: 12)),
          ],
      ],
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptics: true,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.18) : TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: selected ? TrackerColors.accentStart : TrackerColors.border),
        ),
        child: Text(label, style: AppType.body(size: 14).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
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
            if (recipe.coverUrl != null) ...[
              RecipeThumb(key: ValueKey('cover_${recipe.id}'), url: recipe.coverUrl, size: 48),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15)),
                  const SizedBox(height: 4),
                  Text(
                    recipe.estimated ? tr('{n} kcal per serving · estimated', {'n': recipe.calories}) : tr('{n} kcal per serving', {'n': recipe.calories}),
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

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.brief, required this.onTap});

  final RecipeBrief brief;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        key: ValueKey('highlight_${brief.id}'),
        onTap: onTap,
        haptics: true,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: TrackerColors.alpha(TrackerColors.accentEnd, 0.1),
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(color: TrackerColors.alpha(TrackerColors.accentEnd, 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (brief.coverUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: RecipeThumb(key: ValueKey('highlight_cover_${brief.id}'), url: brief.coverUrl, size: 28),
                )
              else
                Icon(CupertinoIcons.pin_fill, size: 12, color: TrackerColors.accentEnd),
              const SizedBox(height: 4),
              Text(brief.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body(size: 13)),
              Text('${brief.calories} kcal', style: AppType.caption(size: 11)),
            ],
          ),
        ),
      );
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({required this.collection, required this.onTap});

  final RecipeCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        key: ValueKey('collection_row_${collection.id}'),
        onTap: onTap,
        haptics: true,
        borderRadius: AppRadii.containerAll,
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          borderRadius: AppRadii.containerAll,
          child: Row(
            children: [
              Icon(collection.isDefault ? CupertinoIcons.bookmark : CupertinoIcons.folder, size: 18, color: TrackerColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(child: Text(collection.name, style: AppType.body(size: 15))),
              Text('${collection.items.length}', style: AppType.caption(size: 12)),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right, size: 14, color: TrackerColors.textTertiary),
            ],
          ),
        ),
      );
}
