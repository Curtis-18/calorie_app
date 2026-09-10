import 'package:flutter/cupertino.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';

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
      child: _loading
        ? const Center(child: CupertinoActivityIndicator(color: TrackerColors.primary))
          : _error != null
          ? Center(child: Text(_error!, style: CupertinoTheme.of(context).textTheme.textStyle))
              : _recipe == null
                  ? Center(
                      child: Text('Recipe not found.',
                style: CupertinoTheme.of(context).textTheme.textStyle))
                  : _RecipeContent(recipe: _recipe!),
    );
  }
}

class _RecipeContent extends StatelessWidget {
  final RecipeDetail recipe;

  const _RecipeContent({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: Text(recipe.name),
          backgroundColor: CupertinoColors.systemGroupedBackground,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(recipe.name, style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle),
              const SizedBox(height: 4),
              Text(
                [recipe.category, recipe.area].where((s) => s.isNotEmpty).join(' • '),
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
              const SizedBox(height: 20),
              Text(
                'INGREDIENTS',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      color: TrackerColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  children: recipe.ingredients
                      .map((ing) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(ing.name,
                                      style: CupertinoTheme.of(context).textTheme.textStyle),
                                ),
                                Text(ing.measure,
                                    style: CupertinoTheme.of(context).textTheme.textStyle),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'INSTRUCTIONS',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      color: TrackerColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 10),
              Text(recipe.instructions, style: CupertinoTheme.of(context).textTheme.textStyle),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }
}