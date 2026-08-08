import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: TrackerColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TrackerColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium))
              : _recipe == null
                  ? Center(
                      child: Text('Recipe not found.',
                          style: Theme.of(context).textTheme.bodyMedium))
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
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          backgroundColor: TrackerColors.background,
          flexibleSpace: FlexibleSpaceBar(
            background: Image.network(recipe.thumbnailUrl, fit: BoxFit.cover),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(recipe.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                [recipe.category, recipe.area].where((s) => s.isNotEmpty).join(' • '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'INGREDIENTS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                      style: Theme.of(context).textTheme.bodyLarge),
                                ),
                                Text(ing.measure,
                                    style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'INSTRUCTIONS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      color: TrackerColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 10),
              Text(recipe.instructions, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }
}