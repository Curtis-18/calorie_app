import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/snaps.dart';
import '../models/stories.dart';
import '../providers/snaps_provider.dart';
import '../services/snaps_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import 'friends_screen.dart' show FriendAvatar;

/// One photo as the viewer plays it, whoever it belongs to.
class StoryItem {
  const StoryItem({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.createdAt,
    this.reaction,
    this.viewers = const [],
  });

  final String id;
  final String? imageUrl;
  final String? caption;
  final DateTime createdAt;
  final String? reaction;

  /// Only on your own photos: the friends who have seen it.
  final List<StoryViewer> viewers;
}

/// One person's story: the photos play in order, then the next person's.
class StoryReel {
  const StoryReel({
    required this.username,
    required this.items,
    this.avatarUrl,
    this.startAt = 0,
    this.isMine = false,
  });

  final String username;
  final String? avatarUrl;
  final List<StoryItem> items;
  final int startAt;
  final bool isMine;

  factory StoryReel.friend(FriendStories g) => StoryReel(
        username: g.username,
        avatarUrl: g.avatarUrl,
        startAt: g.firstUnseen,
        items: [
          for (final s in g.stories)
            StoryItem(id: s.id, imageUrl: s.imageUrl, caption: s.caption, createdAt: s.createdAt, reaction: s.reaction),
        ],
      );

  factory StoryReel.mine(List<MyStory> stories, {required String username, String? avatarUrl}) => StoryReel(
        username: username,
        avatarUrl: avatarUrl,
        isMine: true,
        items: [
          for (final s in stories)
            StoryItem(id: s.id, imageUrl: s.imageUrl, caption: s.caption, createdAt: s.createdAt, viewers: s.viewers),
        ],
      );
}

/// What the viewer hands back when it closes because the person asked to
/// add another photo to their own story.
const storyViewerAdd = 'add';

/// Full-screen stories, the way people know them: each photo plays for a few
/// seconds, tap the right side to skip on and the left to go back, hold to
/// pause, swipe down to close.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.reels, this.startReel = 0});

  final List<StoryReel> reels;
  final int startReel;

  static const perStory = Duration(seconds: 5);

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _timer = AnimationController(vsync: this, duration: StoryViewerScreen.perStory)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });

  // Own copy, so a deleted photo can drop out while the viewer is open.
  late final List<List<StoryItem>> _items = [for (final r in widget.reels) List.of(r.items)];
  late int _reel = widget.startReel.clamp(0, widget.reels.length - 1);
  late int _index = widget.reels[_reel].startAt.clamp(0, _items[_reel].length - 1);
  final _reactions = <String, String>{};

  /// The photo whose countdown has started (it waits for the picture to load).
  String? _running;
  bool _held = false;
  String? _burst;
  int _burstKey = 0;

  StoryReel get _owner => widget.reels[_reel];
  StoryItem get _story => _items[_reel][_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  /// A new photo is on screen: note it as seen and wait for it to load.
  void _show() {
    if (!mounted) return;
    _timer
      ..stop()
      ..value = 0;
    _running = null;
    final story = _story;
    if (!_owner.isMine) ref.read(storiesProvider.notifier).markViewed(story.id);
    if (story.imageUrl == null) _start(story.id);
  }

  /// Start the countdown once [id]'s picture is showing (or has failed).
  void _start(String id) {
    if (!mounted || _running == id || _story.id != id) return;
    _running = id;
    if (!_held) _timer.forward(from: 0);
  }

  void _pause() {
    _held = true;
    _timer.stop();
  }

  void _resume() {
    _held = false;
    if (mounted && _running == _story.id) _timer.forward();
  }

  void _go(int reel, int index) {
    setState(() {
      _reel = reel;
      _index = index;
      _burst = null;
    });
    _show();
  }

  void _next() {
    if (_index < _items[_reel].length - 1) return _go(_reel, _index + 1);
    if (_reel < widget.reels.length - 1) {
      final next = _reel + 1;
      return _go(next, widget.reels[next].startAt.clamp(0, _items[next].length - 1));
    }
    Navigator.of(context).maybePop();
  }

  void _previous() {
    if (_index > 0) return _go(_reel, _index - 1);
    if (_reel > 0) return _go(_reel - 1, 0);
    _go(_reel, 0); // the very first photo: play it again
  }

  /// Run something that covers the story (a menu, a sheet) with the countdown held.
  Future<T> _whilePaused<T>(Future<T> Function() action) async {
    _pause();
    try {
      return await action();
    } finally {
      _resume();
    }
  }

  Future<void> _react(String emoji) async {
    final story = _story;
    HapticFeedback.mediumImpact();
    setState(() {
      _reactions[story.id] = emoji;
      _burst = emoji;
      _burstKey++;
    });
    try {
      await ref.read(storiesProvider.notifier).react(story.id, emoji);
    } on SnapsException catch (e) {
      if (mounted) await _whilePaused(() => showAppDialog(context: context, title: 'Something went wrong', message: e.message));
    }
  }

  Future<void> _menu() => _whilePaused(() async {
        final story = _story;
        final owner = _owner;
        final choice = await showCupertinoModalPopup<String>(
          context: context,
          builder: (context) => CupertinoActionSheet(
            title: Text(owner.isMine ? 'Your story' : '@${owner.username}'),
            actions: [
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, owner.isMine ? 'delete' : 'report'),
                child: Text(owner.isMine ? 'Delete this photo' : 'Report this story'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ),
        );
        if (choice == null || !mounted) return;
        final notifier = ref.read(storiesProvider.notifier);
        try {
          if (choice == 'report') {
            await notifier.report(story.id);
            if (!mounted) return;
            await showAppDialog(
              context: context,
              title: 'Thanks for telling us',
              message: "We'll take a look. You can also block @${owner.username} from the Friends tab.",
            );
          } else {
            await notifier.delete(story.id);
            if (!mounted) return;
            _removeCurrent();
          }
        } on SnapsException catch (e) {
          if (mounted) await showAppDialog(context: context, title: 'Something went wrong', message: e.message);
        }
      });

  void _removeCurrent() {
    final items = _items[_reel];
    if (items.length == 1) {
      // The last one: leave it in place while the screen closes.
      Navigator.of(context).maybePop();
      return;
    }
    items.removeAt(_index);
    _go(_reel, _index.clamp(0, items.length - 1));
  }

  Future<void> _seenBy() => _whilePaused(() => showAppSheet<void>(
        context: context,
        builder: (_) => AppSheet(child: _ViewersList(viewers: _story.viewers)),
      ));

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final owner = _owner;
    final items = _items[_reel];
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final reaction = _reactions[story.id] ?? story.reaction;
    const white = Color(0xFFFFFFFF);
    Widget missing() => const Center(child: Text("This photo couldn't be loaded.", style: TextStyle(color: white)));

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => d.globalPosition.dx < width / 3 ? _previous() : _next(),
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).maybePop();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(
              key: ValueKey(story.id),
              child: story.imageUrl == null
                  ? missing()
                  : Image.network(
                      story.imageUrl!,
                      fit: BoxFit.contain,
                      frameBuilder: (context, child, frame, _) {
                        if (frame == null) return const Center(child: CupertinoActivityIndicator(radius: 14, color: white));
                        WidgetsBinding.instance.addPostFrameCallback((_) => _start(story.id));
                        return child;
                      },
                      errorBuilder: (_, _, _) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _start(story.id));
                        return missing();
                      },
                    ),
            ),
            // One bar per photo; the current one fills as it plays.
            Positioned(
              top: top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: const Color(0x55FFFFFF), borderRadius: BorderRadius.circular(2)),
                        child: i > _index
                            ? null
                            : AnimatedBuilder(
                                animation: _timer,
                                builder: (_, _) => FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: i < _index ? 1 : _timer.value,
                                  child: const ColoredBox(color: white),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: top + 20,
              left: 16,
              right: 4,
              child: Row(
                children: [
                  FriendAvatar(username: owner.username, size: 36, imageUrl: owner.avatarUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          owner.isMine ? 'Your story' : '@${owner.username}',
                          key: const ValueKey('story_owner'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.headline(color: white),
                        ),
                        Text(
                          biteSentLabel(story.createdAt),
                          style: AppType.caption(color: const Color(0xCCFFFFFF), size: 12),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    key: const ValueKey('story_menu'),
                    onTap: _menu,
                    child: const SizedBox(width: 44, height: 44, child: Icon(CupertinoIcons.ellipsis, color: white)),
                  ),
                  Pressable(
                    key: const ValueKey('story_close'),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(width: 44, height: 44, child: Icon(CupertinoIcons.xmark, color: white)),
                  ),
                ],
              ),
            ),
            if (_burst != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_burstKey),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1100),
                    builder: (context, t, _) => Opacity(
                      opacity: (1 - t).clamp(0, 1),
                      child: Align(
                        alignment: Alignment(0, 0.6 - 1.2 * Curves.easeOut.transform(t)),
                        child: Transform.scale(
                          scale: 0.6 + 1.6 * AppMotion.spring.transform((t * 1.6).clamp(0, 1)),
                          child: Text(_burst!, style: const TextStyle(fontSize: 72, decoration: TextDecoration.none)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (story.caption != null && story.caption!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(14)),
                      child: Text(story.caption!, textAlign: TextAlign.center, style: AppType.body(color: white)),
                    ),
                  if (owner.isMine)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _DarkPill(
                          key: const ValueKey('story_seen_by'),
                          icon: CupertinoIcons.eye_fill,
                          label: story.viewers.isEmpty ? 'No views yet' : 'Seen by ${story.viewers.length}',
                          onTap: _seenBy,
                        ),
                        _DarkPill(
                          key: const ValueKey('story_add'),
                          icon: CupertinoIcons.camera_fill,
                          label: 'Add to story',
                          onTap: () => Navigator.of(context).pop(storyViewerAdd),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final e in snapReactions)
                          Pressable(
                            onTap: () => _react(e),
                            child: AnimatedContainer(
                              duration: AppMotion.quick,
                              width: 52,
                              height: 52,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: reaction == e ? const Color(0x55FFFFFF) : const Color(0x33FFFFFF),
                                border: Border.all(color: reaction == e ? white : const Color(0x00000000)),
                              ),
                              child: Text(e, style: const TextStyle(fontSize: 26, decoration: TextDecoration.none)),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: white),
            const SizedBox(width: 7),
            Text(label, style: AppType.caption(color: white, size: 13).copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ViewersList extends StatelessWidget {
  const _ViewersList({required this.viewers});

  final List<StoryViewer> viewers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seen by', style: AppType.title()),
          const SizedBox(height: AppSpacing.md),
          if (viewers.isEmpty)
            Text(
              'Nobody has looked yet. Your friends can see this for 24 hours.',
              style: AppType.body(color: TrackerColors.textSecondary),
            )
          else
            for (final v in viewers)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    FriendAvatar(username: v.username, size: 38, imageUrl: v.avatarUrl),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('@${v.username}', style: AppType.body(size: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (v.reaction != null) Text(v.reaction!, style: const TextStyle(fontSize: 22)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
