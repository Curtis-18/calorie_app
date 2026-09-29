import 'package:flutter/cupertino.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/shimmer.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _service = RecipeService();
  RecipeDetail? _recipe;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final recipe = await _service.lookupById(widget.recipeId);
      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load recipe.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: TrackerColors.background),
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: const [
                  SkeletonCard(height: 120),
                  SizedBox(height: AppSpacing.lg),
                  SkeletonCard(height: 240),
                ],
              )
            : _error != null
                ? AppEmptyState(
                    icon: CupertinoIcons.wifi_exclamationmark,
                    title: 'Something went wrong',
                    message: _error,
                    accent: TrackerColors.error,
                  )
                : _recipe == null
                    ? const AppEmptyState(
                        icon: CupertinoIcons.book,
                        title: 'Recipe not found',
                        message: 'This recipe may no longer be available.',
                        accent: TrackerColors.textSecondary,
                      )
                    : _RecipeContent(recipe: _recipe!),
      ),
    );
  }
}

class _RecipeContent extends StatelessWidget {
  final RecipeDetail recipe;

  const _RecipeContent({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(recipe.name),
          backgroundColor: TrackerColors.navFill,
          border: AppDecor.hairlineTop,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              FrostedGlass(
                opacity: 0.07,
                borderRadius: AppRadii.buttonAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.tag_fill,
                        size: 13,
                        color: TrackerColors.accentEnd,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [recipe.category, recipe.area]
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          style: AppType.caption(color: TrackerColors.textSecondary, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(label: 'Ingredients'),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  children: recipe.ingredients
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: TrackerColors.alpha(TrackerColors.accentStart, 0.9),
                                  borderRadius: BorderRadius.circular(AppRadii.pill),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(entry.value.name, style: AppType.body(size: 14)),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                entry.value.measure,
                                style: AppType.caption(
                                  color: TrackerColors.textSecondary,
                                  size: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(label: 'Instructions'),
              const SizedBox(height: AppSpacing.md),
              Text(
                recipe.instructions,
                style: AppType.body(size: 15, color: TrackerColors.textSecondary),
              ),
              SizedBox(height: 40 + bottomInset),
            ]),
          ),
        ),
      ],
    );
  }
}
