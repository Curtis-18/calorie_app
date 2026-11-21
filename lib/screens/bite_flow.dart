import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../providers/friends_provider.dart';
import '../providers/snaps_provider.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/snaps/flame.dart';
import 'bite_camera_screen.dart';
import 'snap_compose_screen.dart';

/// The food camera (plate guide + meal stamp). If the live camera can't start,
/// the system camera takes over so sending a bite never dead-ends.
Future<XFile?> takeBitePhoto(BuildContext context) async {
  final result = await Navigator.of(context).push<BiteCameraResult>(
    CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const BiteCameraScreen()),
  );
  if (result == null) return null; // closed without a photo
  if (result.bytes != null) return XFile.fromData(result.bytes!, mimeType: 'image/jpeg', name: 'bite.jpg');
  // 4:5 like the live camera, and large enough to stay sharp on a big screen.
  return ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1440,
    maxHeight: 1800,
    imageQuality: 90,
  );
}

/// The whole "send a bite" journey, the same from the Bites tile on Home and
/// from the Friends tab: the camera, then a screen to pick who gets it (any
/// number of friends, your story, or both). Returns what was sent, or null if
/// the person backed out at any point. [to] ticks a friend already; [story]
/// ticks your story. [pickPhoto] replaces the camera; for tests.
Future<ComposeResult?> runBiteFlow(
  BuildContext context, {
  String? to,
  bool story = false,
  Future<XFile?> Function()? pickPhoto,
}) async {
  final XFile? photo;
  try {
    photo = await (pickPhoto ?? () => takeBitePhoto(context))();
  } catch (_) {
    if (!context.mounted) return null;
    await showAppDialog(
      context: context,
      title: tr("Couldn't open the camera"),
      message: tr('Allow camera access in Settings to send bites.'),
    );
    return null;
  }
  if (photo == null || !context.mounted) return null;
  final bytes = await photo.readAsBytes();
  if (!context.mounted) return null;
  return Navigator.of(context).push<ComposeResult>(
    CupertinoPageRoute(builder: (_) => SnapComposeScreen(image: bytes, preselect: to, toStory: story)),
  );
}

/// After a bite went out: refresh what changed, then a streak celebration if a
/// flame was lit, otherwise one line saying where it went through [say].
Future<void> afterBiteShared(
  BuildContext context,
  WidgetRef ref,
  ComposeResult shared, {
  required void Function(String message) say,
}) async {
  if (shared.outcomes.isNotEmpty) ref.read(friendsProvider.notifier).load();
  if (shared.addedToStory) ref.read(storiesProvider.notifier).load();
  final lit = shared.outcomes.where((r) => r.completedToday).toList();
  if (lit.isNotEmpty && context.mounted) {
    final best = lit.reduce((a, b) => a.streak >= b.streak ? a : b);
    await showStreakCelebration(context, username: best.username, streak: best.streak);
  } else {
    say(shareSummary(shared));
  }
}

/// A short floating confirmation near the top of the screen, gone by itself.
void showBiteToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _BiteToast(message: message, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _BiteToast extends StatefulWidget {
  const _BiteToast({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_BiteToast> createState() => _BiteToastState();
}

class _BiteToastState extends State<_BiteToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.medium);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 2800), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: AppMotion.spring, reverseCurve: Curves.easeIn);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(curve),
            child: Center(
              child: FrostedGlass(
                blur: 20,
                opacity: 0.94,
                tint: TrackerColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: TrackerColors.alpha(TrackerColors.success, 0.35)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.paperplane_fill, size: 15, color: TrackerColors.success),
                      const SizedBox(width: 8),
                      Flexible(
                        child: DefaultTextStyle(
                          style: AppType.body(size: 14),
                          child: Text(widget.message, key: const ValueKey('bite_toast_text')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
