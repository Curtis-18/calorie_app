import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/house_recipe.dart';
import '../services/house_recipe_service.dart';
import '../services/user_cache.dart';

class HouseRecipesState {
  const HouseRecipesState({this.recipes = const [], this.loading = true, this.failed = false});

  final List<HouseRecipe> recipes;
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
    final recipes = await _service.list();
    if (!mounted || generation != _generation) return;
    state = recipes == null
        ? HouseRecipesState(recipes: state.recipes, loading: false, failed: true)
        : HouseRecipesState(recipes: recipes, loading: false);
  }

  void add(HouseRecipe recipe) {
    state = HouseRecipesState(recipes: [recipe, ...state.recipes.where((r) => r.id != recipe.id)], loading: false);
  }

  /// Null on success, otherwise a message.
  Future<String?> remove(String id) async {
    final error = await _service.delete(id);
    if (error != null) return error;
    state = HouseRecipesState(recipes: state.recipes.where((r) => r.id != id).toList(), loading: false);
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
