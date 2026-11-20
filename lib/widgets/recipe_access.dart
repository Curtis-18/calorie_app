import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/house_recipe.dart';
import '../providers/house_recipes_provider.dart';
import '../screens/friends_screen.dart' show FriendAvatar;
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_dialog.dart';
import 'glass.dart';
import 'house_recipe_sheet.dart' show openRecipeById;
import 'pressable.dart';
import 'recipe_gallery.dart';

/// Who has been sent one of my recipes, with a way to take access back.
Future<void> showSharedWithSheet(BuildContext context, HouseRecipe recipe) =>
    showAppSheet<void>(context: context, builder: (_) => SharedWithSheet(recipe: recipe));

class SharedWithSheet extends ConsumerStatefulWidget {
  const SharedWithSheet({super.key, required this.recipe});

  final HouseRecipe recipe;

  @override
  ConsumerState<SharedWithSheet> createState() => _SharedWithSheetState();
}

class _SharedWithSheetState extends ConsumerState<SharedWithSheet> {
  List<RecipeSharee>? _people;
  bool _failed = false;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final people = await ref.read(houseRecipesProvider.notifier).service.sharedWith(widget.recipe.id);
    if (!mounted) return;
    setState(() {
      _people = people;
      _failed = people == null;
    });
  }

  Future<void> _takeBack(RecipeSharee person) async {
    final ok = await showAppDialog(
      context: context,
      title: 'Take it back from @${person.username}?',
      message: "They'll no longer be able to open it. The message stays in chat.",
      confirmLabel: 'Take back',
      cancelLabel: 'Cancel',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = person.friendId);
    final error = await ref.read(houseRecipesProvider.notifier).service.unshare(widget.recipe.id, person.friendId);
    if (!mounted) return;
    setState(() {
      _busy = null;
      if (error == null) _people = _people?.where((p) => p.friendId != person.friendId).toList();
    });
    if (error != null) await showAppDialog(context: context, title: "Couldn't take it back", message: error, confirmLabel: 'OK');
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shared with', style: AppType.title()),
          const SizedBox(height: 10),
          if (_failed)
            Text("Couldn't load this. Check your connection and try again.", key: const ValueKey('shared_failed'), style: AppType.body(size: 14, color: TrackerColors.textSecondary))
          else if (people == null)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CupertinoActivityIndicator()))
          else if (people.isEmpty)
            Text(
              widget.recipe.sharedWithFriends
                  ? 'You haven’t sent it to anyone. All your friends can open it, because it is set to friends.'
                  : 'You haven’t sent it to anyone.',
              key: const ValueKey('shared_empty'),
              style: AppType.body(size: 14, color: TrackerColors.textSecondary),
            )
          else
            for (final p in people)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  key: ValueKey('shared_${p.friendId}'),
                  children: [
                    FriendAvatar(username: p.username, imageUrl: p.avatarUrl, size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Text('@${p.username}', style: AppType.body(size: 15))),
                    CupertinoButton(
                      key: ValueKey('take_back_${p.friendId}'),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(32, 32),
                      onPressed: _busy == null ? () => _takeBack(p) : null,
                      child: Text('Take back', style: AppType.caption(size: 13, color: TrackerColors.error)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// The recipes a friend has pinned and lets me open.
Future<void> showFriendRecipes(BuildContext context, {required String friendId, required String username}) =>
    showAppSheet<void>(context: context, builder: (_) => FriendRecipesSheet(friendId: friendId, username: username));

class FriendRecipesSheet extends ConsumerStatefulWidget {
  const FriendRecipesSheet({super.key, required this.friendId, required this.username});

  final String friendId;
  final String username;

  @override
  ConsumerState<FriendRecipesSheet> createState() => _FriendRecipesSheetState();
}

class _FriendRecipesSheetState extends ConsumerState<FriendRecipesSheet> {
  List<RecipeBrief>? _recipes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ref.read(houseRecipesProvider.notifier).service.friendHighlights(widget.friendId);
    if (!mounted) return;
    setState(() {
      _recipes = list;
      _failed = list == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('@${widget.username}’s recipes', style: AppType.title()),
          const SizedBox(height: 10),
          if (_failed)
            Text("Couldn't load this. Check your connection and try again.", key: const ValueKey('friend_recipes_failed'), style: AppType.body(size: 14, color: TrackerColors.textSecondary))
          else if (recipes == null)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CupertinoActivityIndicator()))
          else if (recipes.isEmpty)
            Text(
              '@${widget.username} hasn’t pinned any recipes for friends yet.',
              key: const ValueKey('friend_recipes_empty'),
              style: AppType.body(size: 14, color: TrackerColors.textSecondary),
            )
          else
            for (final r in recipes)
              Pressable(
                key: ValueKey('friend_recipe_${r.id}'),
                onTap: () => openRecipeById(context, ref.read(houseRecipesProvider.notifier), r.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      RecipeThumb(url: r.coverUrl, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15)),
                            Text('${r.calories} kcal per serving${r.estimated ? ' · estimated' : ''}', style: AppType.caption(size: 12)),
                          ],
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right, size: 14, color: TrackerColors.textTertiary),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
