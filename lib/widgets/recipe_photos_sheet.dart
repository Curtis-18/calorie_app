import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/house_recipe.dart';
import '../providers/house_recipes_provider.dart';
import '../providers/recipe_photo_picker.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_dialog.dart';
import 'glass.dart';
import 'pressable.dart';
import 'recipe_gallery.dart';
import '../l10n/app_strings.dart';

const maxRecipeSlides = 5;

/// Add, replace or remove a recipe's cover and its (up to five) slides.
/// [onChanged] gets the recipe as the server now has it.
Future<void> showRecipePhotosSheet(BuildContext context, HouseRecipe recipe, {required ValueChanged<HouseRecipe> onChanged}) {
  return showAppSheet<void>(context: context, builder: (_) => RecipePhotosSheet(recipe: recipe, onChanged: onChanged));
}

class RecipePhotosSheet extends ConsumerStatefulWidget {
  const RecipePhotosSheet({super.key, required this.recipe, required this.onChanged});

  final HouseRecipe recipe;
  final ValueChanged<HouseRecipe> onChanged;

  @override
  ConsumerState<RecipePhotosSheet> createState() => _RecipePhotosSheetState();
}

class _RecipePhotosSheetState extends ConsumerState<RecipePhotosSheet> {
  late HouseRecipe _recipe = widget.recipe;
  int? _busy;

  String? _urlAt(int position) {
    for (final p in _recipe.gallery) {
      if (p.position == position) return p.url;
    }
    return null;
  }

  Future<void> _tell(String title, String message) async {
    if (!mounted) return;
    await showAppDialog(context: context, title: title, message: message, confirmLabel: 'OK');
  }

  Future<void> _refresh() async {
    final fresh = await ref.read(houseRecipesProvider.notifier).service.get(_recipe.id);
    if (!mounted) return;
    if (fresh != null) {
      setState(() => _recipe = fresh);
      widget.onChanged(fresh);
    }
    // The lists show covers too.
    await ref.read(houseRecipesProvider.notifier).load();
  }

  Future<void> _slot(int position) async {
    if (_busy != null) return;
    final has = _urlAt(position) != null;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(position == 0 ? tr('Cover photo') : tr('Slide {position}', {'position': position})),
        message: Text(tr('Only you and the friends who can open this recipe will see it.')),
        actions: [
          CupertinoActionSheetAction(key: const ValueKey('photo_camera'), onPressed: () => Navigator.pop(context, 'camera'), child: Text(tr('Take a photo'))),
          CupertinoActionSheetAction(key: const ValueKey('photo_library'), onPressed: () => Navigator.pop(context, 'library'), child: Text(tr('Choose from library'))),
          if (has)
            CupertinoActionSheetAction(key: const ValueKey('photo_remove'), isDestructiveAction: true, onPressed: () => Navigator.pop(context, 'remove'), child: Text(tr('Remove photo'))),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
      ),
    );
    if (choice == null || !mounted) return;
    final service = ref.read(houseRecipesProvider.notifier).service;
    if (choice == 'remove') {
      setState(() => _busy = position);
      final error = await service.deletePhoto(_recipe.id, position);
      if (!mounted) return;
      if (error == null) await _refresh();
      setState(() => _busy = null);
      if (error != null) await _tell(tr("Couldn't remove it"), error);
      return;
    }
    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final photo = await _pick(source);
    if (photo == null || !mounted) return;
    setState(() => _busy = position);
    final error = await service.putPhoto(_recipe.id, position, photo);
    if (!mounted) return;
    if (error == null) {
      HapticFeedback.mediumImpact();
      await _refresh();
    }
    if (!mounted) return;
    setState(() => _busy = null);
    if (error != null) await _tell(tr("Couldn't save that photo"), error);
  }

  Future<Uint8List?> _pick(ImageSource source) async {
    try {
      return await ref.read(recipePhotoPickerProvider)(source);
    } catch (_) {
      await _tell(
        source == ImageSource.camera ? tr("Couldn't open the camera") : tr("Couldn't open your photos"),
        tr('Allow access in Settings, then try again.'),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Photos'), style: AppType.title()),
          const SizedBox(height: 4),
          Text(
            tr('A cover, then up to {maxRecipeSlides} slides: the ingredients, the steps, the finished dish.', {'maxRecipeSlides': maxRecipeSlides}),
            style: AppType.caption(size: 12),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var position = 0; position <= maxRecipeSlides; position++)
                _Slot(
                  key: ValueKey('photo_slot_$position'),
                  label: position == 0 ? tr('Cover') : '$position',
                  url: _urlAt(position),
                  busy: _busy == position,
                  onTap: () => _slot(position),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({super.key, required this.label, required this.url, required this.busy, required this.onTap});

  final String label;
  final String? url;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 92,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  url == null
                      ? Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.button),
                            border: Border.all(color: TrackerColors.border),
                            color: TrackerColors.alpha(TrackerColors.textPrimary, 0.05),
                          ),
                          child: Icon(CupertinoIcons.add, color: TrackerColors.textSecondary),
                        )
                      : RecipeThumb(url: url, size: 92, icon: CupertinoIcons.photo),
                  if (busy) const CupertinoActivityIndicator(),
                ],
              ),
              const SizedBox(height: 4),
              Text(label, style: AppType.caption(size: 11)),
            ],
          ),
        ),
      );
}
