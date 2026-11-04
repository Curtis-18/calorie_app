import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/snaps.dart';
import '../providers/snaps_provider.dart';
import '../services/snaps_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../widgets/app_dialog.dart';
import '../widgets/pressable.dart';

/// Full-screen viewer for today's snaps from friends. Tap to move on, swipe
/// down to close, react with an emoji, or report from the corner menu.
class SnapViewerScreen extends ConsumerStatefulWidget {
  const SnapViewerScreen({super.key, required this.snaps, this.startAt = 0});

  final List<InboxSnap> snaps;
  final int startAt;

  @override
  ConsumerState<SnapViewerScreen> createState() => _SnapViewerScreenState();
}

class _SnapViewerScreenState extends ConsumerState<SnapViewerScreen> {
  late int _index = widget.startAt.clamp(0, widget.snaps.length - 1);
  String? _burst; // the emoji currently floating up
  int _burstKey = 0;

  InboxSnap get _snap {
    // Prefer the live copy so a reaction shows straight away.
    final live = ref.read(snapInboxProvider).valueOrNull;
    final base = widget.snaps[_index];
    return live?.firstWhere((s) => s.id == base.id, orElse: () => base) ?? base;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen());
  }

  void _markSeen() {
    if (!mounted) return;
    ref.read(snapInboxProvider.notifier).markViewed(widget.snaps[_index]);
  }

  void _next() {
    if (_index >= widget.snaps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _burst = null;
    });
    _markSeen();
  }

  Future<void> _react(String emoji) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _burst = emoji;
      _burstKey++;
    });
    try {
      await ref.read(snapInboxProvider.notifier).react(_snap, emoji);
    } on SnapsException catch (e) {
      if (mounted) await showAppDialog(context: context, title: 'Something went wrong', message: e.message);
    }
  }

  Future<void> _menu() async {
    final snap = _snap;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('@${snap.senderUsername}'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'report'),
            child: const Text('Report this snap'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
    if (choice != 'report' || !mounted) return;
    try {
      await ref.read(snapInboxProvider.notifier).report(snap);
      if (!mounted) return;
      await showAppDialog(
        context: context,
        title: 'Thanks for telling us',
        message: "We'll take a look. You can also block @${snap.senderUsername} from the Friends tab.",
      );
    } on SnapsException catch (e) {
      if (mounted) await showAppDialog(context: context, title: 'Something went wrong', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    final total = widget.snaps.length;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).pop();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.medium,
              child: KeyedSubtree(
                key: ValueKey(snap.id),
                child: snap.imageUrl == null
                    ? const Center(
                        child: Text("This snap couldn't be loaded.", style: TextStyle(color: Color(0xFFFFFFFF))),
                      )
                    : Image.network(
                        snap.imageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : const Center(child: CupertinoActivityIndicator(radius: 14)),
                        errorBuilder: (_, _, _) => const Center(
                          child: Text("This snap couldn't be loaded.", style: TextStyle(color: Color(0xFFFFFFFF))),
                        ),
                      ),
              ),
            ),
            // Progress bars
            Positioned(
              top: top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _index ? const Color(0xFFFFFFFF) : const Color(0x55FFFFFF),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: top + 20,
              left: 16,
              right: 8,
              child: Row(
                children: [
                  Text(
                    '@${snap.senderUsername}',
                    style: AppType.headline(color: const Color(0xFFFFFFFF)),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: _menu,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(CupertinoIcons.ellipsis, color: Color(0xFFFFFFFF)),
                    ),
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
                  if (snap.caption != null && snap.caption!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        snap.caption!,
                        textAlign: TextAlign.center,
                        style: AppType.body(color: const Color(0xFFFFFFFF)),
                      ),
                    ),
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
                              color: snap.reaction == e ? const Color(0x55FFFFFF) : const Color(0x33FFFFFF),
                              border: Border.all(
                                color: snap.reaction == e ? const Color(0xFFFFFFFF) : const Color(0x00000000),
                              ),
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
