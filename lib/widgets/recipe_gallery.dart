import 'package:flutter/cupertino.dart';

import '../models/house_recipe.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';

/// A small square photo, or a quiet placeholder while there is none or it
/// can't load. Used on lists, so it never throws.
class RecipeThumb extends StatelessWidget {
  const RecipeThumb({super.key, required this.url, this.size = 52, this.icon = CupertinoIcons.book});

  final String? url;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
      child: Icon(icon, size: size * 0.4, color: TrackerColors.textTertiary),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: u == null
          ? placeholder
          : Image.network(u, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
    );
  }
}

/// The recipe's cover and slides, swiped one at a time, with dots.
class RecipeGallery extends StatefulWidget {
  const RecipeGallery({super.key, required this.photos, this.height = 210});

  final List<RecipePhoto> photos;
  final double height;

  @override
  State<RecipeGallery> createState() => _RecipeGalleryState();
}

class _RecipeGalleryState extends State<RecipeGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: PageView.builder(
              key: const ValueKey('recipe_gallery'),
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final p = photos[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: TrackerColors.alpha(TrackerColors.textPrimary, 0.06)),
                    Image.network(
                      p.url,
                      key: ValueKey('gallery_photo_${p.position}'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(child: Icon(CupertinoIcons.photo, color: TrackerColors.textTertiary)),
                    ),
                    if (p.caption != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xAA000000)],
                            ),
                          ),
                          child: Text(p.caption!, style: AppType.caption(size: 12, color: const Color(0xFFFFFFFF))),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            key: const ValueKey('gallery_dots'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < photos.length; i++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? TrackerColors.accentEnd : TrackerColors.alpha(TrackerColors.textPrimary, 0.2),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
