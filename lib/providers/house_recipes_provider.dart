import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/house_recipe.dart';
import '../services/house_recipe_service.dart';
import '../services/user_cache.dart';
import '../l10n/app_strings.dart';

class HouseRecipesState {
  const HouseRecipesState({
    this.recipes = const [],
    this.collections = const [],
    this.highlights = const [],
    this.loading = true,
    this.failed = false,
  });

  final List<HouseRecipe> recipes;
  final List<RecipeCollection> collections;
  final List<RecipeBrief> highlights;
  final bool loading;

  /// The last load didn't work (offline, or the server said no).
  final bool failed;
}

/// The signed-in person's recipes, cleared when they sign out so the next
/// person never sees them.
class HouseRecipesNotifier extends StateNotifier<HouseRecipesState> {
  HouseRecipesNotifier({
    HouseRecipeService? service,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
  })  : _service = service ?? HouseRecipeService(),
        super(const HouseRecipesState()) {
    // Tolerates a Supabase that isn't started (a screen under test).
    try {
      _subscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
      _onUser((currentUserId ?? UserCache.currentUserId)());
    } catch (_) {
      state = const HouseRecipesState(loading: false);
    }
  }

  final HouseRecipeService _service;
  StreamSubscription<String?>? _subscription;
  String? _userId;
  int _generation = 0;

  HouseRecipeService get service => _service;

  void _onUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    state = const HouseRecipesState();
    if (userId != null) load();
  }

  Future<void> load() async {
    final generation = _generation;
    if (_userId == null) return;
    final results = await Future.wait([_service.list(), _service.collections(), _service.highlights()]);
    if (!mounted || generation != _generation) return;
    final recipes = results[0] as List<HouseRecipe>?;
    final collections = results[1] as List<RecipeCollection>?;
    final highlights = results[2] as List<RecipeBrief>?;
    // Collections and Highlights are extras: if only they fail, keep what we
    // had and don't call the whole page failed.
    state = HouseRecipesState(
      recipes: recipes ?? state.recipes,
      collections: collections ?? state.collections,
      highlights: highlights ?? state.highlights,
      loading: false,
      failed: recipes == null,
    );
  }

  HouseRecipesState _with({List<HouseRecipe>? recipes, List<RecipeCollection>? collections, List<RecipeBrief>? highlights}) =>
      HouseRecipesState(
        recipes: recipes ?? state.recipes,
        collections: collections ?? state.collections,
        highlights: highlights ?? state.highlights,
        loading: false,
      );

  void add(HouseRecipe recipe) {
    state = _with(recipes: [recipe, ...state.recipes.where((r) => r.id != recipe.id)]);
  }

  static const maxHighlights = 6;

  bool isPinned(String recipeId) => state.highlights.any((h) => h.id == recipeId);

  /// Pin or unpin one of my recipes. Null on success, otherwise a message.
  Future<String?> togglePin(HouseRecipe recipe) async {
    final pinned = isPinned(recipe.id);
    if (!pinned && state.highlights.length >= maxHighlights) {
      return tr('You can pin up to {maxHighlights} recipes. Unpin one first.', {'maxHighlights': maxHighlights});
    }
    final next = pinned
        ? state.highlights.where((h) => h.id != recipe.id).toList()
        : [
            ...state.highlights,
            RecipeBrief(id: recipe.id, title: recipe.title, calories: recipe.calories, estimated: recipe.estimated, mine: true),
          ];
    final error = await _service.setHighlights([for (final h in next) h.id]);
    if (error != null) return error;
    state = _with(highlights: next);
    return null;
  }

  /// Make a collection; [id] is chosen by the caller so a retry can't duplicate it.
  Future<String?> createCollection(String id, String name) async {
    final error = await _service.createCollection(id, name);
    if (error != null) return error;
    state = _with(collections: [...state.collections, RecipeCollection(id: id, name: name.trim(), isDefault: false)]);
    return null;
  }

  Future<String?> deleteCollection(String id) async {
    final error = await _service.deleteCollection(id);
    if (error != null) return error;
    state = _with(collections: state.collections.where((c) => c.id != id).toList());
    return null;
  }

  /// Put a recipe in (or take it out of) a collection, then refresh so the
  /// lists agree with the server.
  Future<String?> setInCollection(RecipeCollection collection, String recipeId, {required bool inside}) async {
    final error = inside
        ? await _service.addToCollection(collection.id, recipeId)
        : await _service.removeFromCollection(collection.id, recipeId);
    if (error != null) return error;
    await load();
    return null;
  }

  Future<String?> saveRecipe(String recipeId) async {
    final error = await _service.save(recipeId);
    if (error == null) await load();
    return error;
  }

  /// Null on success, otherwise a message.
  Future<String?> remove(String id) async {
    final error = await _service.delete(id);
    if (error != null) return error;
    state = _with(
      recipes: state.recipes.where((r) => r.id != id).toList(),
      highlights: state.highlights.where((h) => h.id != id).toList(),
      collections: [for (final c in state.collections) RecipeCollection(id: c.id, name: c.name, isDefault: c.isDefault, items: c.items.where((i) => i.id != id).toList())],
    );
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final houseRecipesProvider = StateNotifierProvider<HouseRecipesNotifier, HouseRecipesState>(
  (ref) => HouseRecipesNotifier(),
);
