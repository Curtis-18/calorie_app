import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../models/mood.dart';
import '../models/recipe.dart';
import '../services/mood_picks.dart';
import '../services/recipe_service.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';
import 'pressable.dart';
import 'shimmer.dart';

/// "How are you feeling?" on the Recipes page: pick one, get meal ideas.
///
/// The choice lives only in this widget. It is not saved, not sent to the
/// server and not shared; leaving the page forgets it.
class MoodPicker extends StatefulWidget {
  const MoodPicker({super.key, required this.service, required this.pool, required this.onOpen});

  final RecipeService service;

  /// The recipes already on screen (judged by their names too).
  final List<RecipeSummary> pool;
  final void Function(String recipeId) onOpen;

  @override
  State<MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends State<MoodPicker> {
  Mood? _mood;
  bool _loading = false;
  bool _failed = false;
  List<MoodPick<RecipeSummary>> _picks = const [];
  int _request = 0; // a slow answer for an earlier choice must not overwrite a later one

  Future<void> _choose(Mood mood) async {
    if (_mood == mood) {
      setState(() {
        _mood = null;
        _picks = const [];
        _failed = false;
        _loading = false;
        _request++;
      });
      return;
    }
    final request = ++_request;
    setState(() {
      _mood = mood;
      _loading = true;
      _failed = false;
      _picks = const [];
    });

    final features = featuresToFetch(mood);
    final found = <FoodFeature, List<RecipeSummary>>{};
    var sweetIds = <String>{};
    var asked = 0;
    var answered = 0;
    await Future.wait([
      () async {
        try {
          sweetIds = await widget.service.dessertIds();
        } catch (_) {/* without it the names still catch most sweet dishes */}
      }(),
      for (final feature in features)
        for (final ingredient in featureIngredients[feature]!)
          () async {
            asked++;
            try {
              final recipes = await widget.service.filterByIngredient(ingredient);
              answered++;
              (found[feature] ??= []).addAll(recipes);
            } catch (_) {/* one ingredient failing must not blank the rest */}
          }(),
    ]);
    if (!mounted || request != _request) return;

    final day = DateTime.now().difference(DateTime(2026)).inDays + 1;
    final picks = rankForMood(mood, fromIngredient: found, pool: widget.pool, sweetIds: sweetIds, seed: day);
    setState(() {
      _loading = false;
      _picks = picks;
      // Nothing came back at all (offline) is an error; an empty list is not.
      _failed = asked > 0 && answered == 0 && picks.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mood = _mood;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(label: tr('How are you feeling?')),
        const SizedBox(height: AppSpacing.sm),
        Text(
          tr('Pick one for meal ideas. Nothing is saved.'),
          style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in Mood.values)
              _MoodChip(key: ValueKey('mood_${m.name}'), mood: m, selected: m == mood, onTap: () => _choose(m)),
          ],
        ),
        if (mood != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(mood.blurb, key: const ValueKey('mood_blurb'), style: AppType.body(size: 14)),
              ),
              Pressable(
                key: const ValueKey('mood_clear'),
                onTap: () => _choose(mood),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(tr('Clear'), style: AppType.caption(color: TrackerColors.accentStartText, size: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_loading)
            const SkeletonRows(count: 3)
          else if (_failed)
            Text(tr('Could not load ideas. Try again.'), key: const ValueKey('mood_failed'), style: AppType.caption(size: 13))
          else if (_picks.isEmpty)
            Text(tr('No matches right now. Try another feeling.'), key: const ValueKey('mood_empty'), style: AppType.caption(size: 13))
          else
            for (final pick in _picks)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _PickRow(pick: pick, onTap: () => widget.onOpen(pick.recipe.id)),
              ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr('General ideas, not medical advice.'),
            style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
          ),
          if (mood == Mood.low) ...[
            const SizedBox(height: 4),
            Text(
              tr('If a low mood lasts, it can help to talk to someone you trust or a doctor.'),
              key: const ValueKey('mood_care'),
              style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({super.key, required this.mood, required this.selected, required this.onTap});

  final Mood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptics: true,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? TrackerColors.alpha(TrackerColors.accentStart, 0.18)
              : TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: selected ? TrackerColors.accentStart : TrackerColors.border,
          ),
        ),
        child: Text(
          '${mood.emoji}  ${mood.label}',
          style: AppType.body(size: 14).copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.pick, required this.onTap});

  final MoodPick<RecipeSummary> pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recipe = pick.recipe;
    return Pressable(
      key: ValueKey('mood_pick_${recipe.id}'),
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
              child: Image.network(
                recipe.thumbnailUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 56,
                  height: 56,
                  color: TrackerColors.surfaceElevated,
                  alignment: Alignment.center,
                  child: Icon(CupertinoIcons.photo, size: 18, color: TrackerColors.textTertiary),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body(size: 14)),
                  if (pick.reasons.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pick.reasons.map((f) => f.reason!).join(' · '),
                      key: ValueKey('mood_reasons_${recipe.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption(color: TrackerColors.accentStartText, size: 11),
                    ),
                  ],
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
