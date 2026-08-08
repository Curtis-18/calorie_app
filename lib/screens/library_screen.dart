import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import 'recipe_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _service = RecipeService();
  final _controller = TextEditingController();

  RecipeDetail? _featured;
  List<RecipeSummary> _results = [];
  bool _loadingFeatured = true;
  bool _searching = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  Future<void> _loadFeatured() async {
    try {
      final recipe = await _service.getRandom();
      if (!mounted) return;
      setState(() {
        _featured = recipe;
        _loadingFeatured = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFeatured = false);
    }
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _hasSearched = false;
        _results = [];
      });
      return;
    }
    setState(() {
      _hasSearched = true;
      _searching = true;
      _error = null;
    });
    try {
      final results = await _service.search(trimmed);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed, try again.';
        _searching = false;
      });
    }
  }

  void _openRecipe(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TrackerColors.background,
      appBar: AppBar(
        title: const Text('Library'),
        backgroundColor: TrackerColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _controller,
            onSubmitted: _search,
            onChanged: (value) {
              if (value.trim().isEmpty && _hasSearched) {
                setState(() => _hasSearched = false);
              }
            },
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Search recipes...',
              filled: true,
              fillColor: TrackerColors.surface,
              prefixIcon: const Icon(Icons.search, color: TrackerColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!_hasSearched) ...[
            Text(
              'FEATURED',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: TrackerColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            if (_loadingFeatured)
              const Center(child: CircularProgressIndicator(color: TrackerColors.primary))
            else if (_featured != null)
              _FeaturedCard(recipe: _featured!, onTap: () => _openRecipe(_featured!.id)),
          ] else ...[
            if (_searching)
              const Center(child: CircularProgressIndicator(color: TrackerColors.primary))
            else if (_error != null)
              Text(_error!, style: Theme.of(context).textTheme.bodyMedium)
            else if (_results.isEmpty)
              Text('No recipes found.', style: Theme.of(context).textTheme.bodyMedium)
            else
              ..._results.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecipeRow(recipe: r, onTap: () => _openRecipe(r.id)),
                  )),
          ],
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final RecipeDetail recipe;
  final VoidCallback onTap;

  const _FeaturedCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Image.network(
                recipe.thumbnailUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(recipe.name, style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  final RecipeSummary recipe;
  final VoidCallback onTap;

  const _RecipeRow({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(recipe.thumbnailUrl, width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(recipe.name, style: Theme.of(context).textTheme.bodyLarge)),
            const Icon(Icons.chevron_right, color: TrackerColors.textSecondary),
          ],
        ),
      ),
    );
  }
}