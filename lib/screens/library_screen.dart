import 'package:flutter/cupertino.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      child: DecoratedBox(
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Recipes', style: AppType.title()),
                          const Spacer(),
                          if (isLoading)
                            const SkeletonBox(width: 64, height: 12),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
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
                        placeholder: 'Search recipes…',
                        backgroundColor: TrackerColors.alpha(TrackerColors.textPrimary, 0.07),
                        borderRadius: AppRadii.buttonAll,
                        itemColor: TrackerColors.textSecondary,
                        style: AppType.body(size: 15),
                        placeholderStyle: AppType.body(size: 15, color: TrackerColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                children: [
                  if (!showingSearch) ...[
                    SectionHeader(
                      label: 'Browse',
                      trailing: isLoading || list.isEmpty
                          ? null
                          : Text(
                              '${list.length} recipes',
                              style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (isLoading)
                    const SkeletonRows(count: 6)
                  else if (_error != null)
                    AppEmptyState(
                      icon: CupertinoIcons.wifi_exclamationmark,
                      title: 'Something went wrong',
                      message: _error,
                      accent: TrackerColors.error,
                    )
                  else if (list.isEmpty)
                    AppEmptyState(
                      icon: showingSearch ? CupertinoIcons.search : CupertinoIcons.book,
                      title: showingSearch ? 'No recipes found' : 'Could not load recipes',
                      message: showingSearch
                          ? 'Try a different search term.'
                          : 'Pull to try again once you are back online.',
                    )
                  else
                    ...list.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _RecipeRow(
                          recipe: entry.value,
                          onTap: () => _openRecipe(entry.value.id),
                        ),
                      ),
                    ),
                  SizedBox(height: AppSpacing.tabBarClearance + bottomInset),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.recipe, required this.onTap});

  final RecipeSummary recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptics: true,
      borderRadius: AppRadii.containerAll,
      child: AppCard(
        padding: const EdgeInsets.all(10),
        borderRadius: AppRadii.containerAll,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.button),
              child: Stack(
                children: [
                  Image.network(
                    recipe.thumbnailUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      width: 64,
                      height: 64,
                      color: TrackerColors.surfaceElevated,
                      alignment: Alignment.center,
                      child: const Icon(
                        CupertinoIcons.photo,
                        size: 18,
                        color: TrackerColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(size: 14),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.clock,
                        size: 12,
                        color: TrackerColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text('Tap to cook', style: AppType.caption(size: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(CupertinoIcons.chevron_right, size: 15, color: TrackerColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
