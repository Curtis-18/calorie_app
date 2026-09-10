import 'package:flutter/cupertino.dart';
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

  List<RecipeSummary> _browseResults = [];
  List<RecipeSummary> _searchResults = [];
  bool _loadingBrowse = true;
  bool _searching = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBrowse();
  }

  Future<void> _loadBrowse() async {
    try {
      final recipes = await _service.browseDefault();
      if (!mounted) return;
      setState(() {
        _browseResults = recipes;
        _loadingBrowse = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBrowse = false);
    }
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _hasSearched = false;
        _searchResults = [];
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
        _searchResults = results;
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
      CupertinoPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingSearch = _hasSearched;
    final list = showingSearch ? _searchResults : _browseResults;
    final isLoading = showingSearch ? _searching : _loadingBrowse;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Recipes'),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CupertinoSearchTextField(
            controller: _controller,
            onSubmitted: _search,
            onChanged: (value) {
              if (value.trim().isEmpty && _hasSearched) {
                setState(() {
                  _hasSearched = false;
                  _searchResults = [];
                });
              }
            },
            placeholder: 'Search recipes...',
          ),
          const SizedBox(height: 20),
          if (!showingSearch)
            Text(
              'BROWSE',
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: TrackerColors.textSecondary,
                  ),
            ),
          const SizedBox(height: 10),
          if (isLoading)
            const Center(child: CupertinoActivityIndicator(color: TrackerColors.primary))
          else if (_error != null)
            Text(_error!, style: CupertinoTheme.of(context).textTheme.textStyle)
          else if (list.isEmpty)
            Text(
              showingSearch ? 'No recipes found.' : 'Could not load recipes right now.',
              style: CupertinoTheme.of(context).textTheme.textStyle,
            )
          else
            ...list.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecipeRow(recipe: r, onTap: () => _openRecipe(r.id)),
                )),
        ],
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
            Expanded(child: Text(recipe.name, style: CupertinoTheme.of(context).textTheme.textStyle)),
            const Icon(CupertinoIcons.chevron_right, color: TrackerColors.textSecondary),
          ],
        ),
      ),
    );
  }
}