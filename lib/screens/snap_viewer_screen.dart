import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quick_replies.dart';
import '../models/snaps.dart';
import '../providers/messages_provider.dart';
import '../providers/snaps_provider.dart';
import '../services/messages_service.dart';
import '../services/snaps_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../widgets/app_dialog.dart';
import '../widgets/snaps/photo_caption.dart';
import 'bite_flow.dart';
import '../widgets/pressable.dart';
import '../l10n/app_strings.dart';

/// Full-screen viewer for today's snaps from friends. Tap to move on, swipe
/// down to close, react with an emoji, or report from the corner menu.
class SnapViewerScreen extends ConsumerStatefulWidget {
  const SnapViewerScreen({super.key, required this.snaps, this.startAt = 0, this.pickPhoto});

  final List<InboxSnap> snaps;
  final int startAt;

  /// Replaces the camera for "Bite back"; for tests.
  final Future<XFile?> Function()? pickPhoto;

  @override
  ConsumerState<SnapViewerScreen> createState() => _SnapViewerScreenState();
}

class _SnapViewerScreenState extends ConsumerState<SnapViewerScreen> {
  late int _index = widget.startAt.clamp(0, widget.snaps.length - 1);
  String? _burst; // the emoji currently floating up
  int _burstKey = 0;

  // Quick replies already sent for a bite ("<snap id>/<reply id>"), and the id
  // each one went out with, so a tap while one is in flight or a retry after a
  // failure can never send it twice.
  final _sentReplies = <String>{};
  final _replyIds = <String, String>{};

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
      if (mounted) await showAppDialog(context: context, title: tr('Something went wrong'), message: e.message);
    }
  }

  /// A one-tap reply, sent to the friend as an ordinary chat message.
  Future<void> _quickReply(QuickReply reply) async {
    final snap = _snap;
    final key = '${snap.id}/${reply.id}';
    if (_sentReplies.contains(key)) return;
    HapticFeedback.selectionClick();
    setState(() => _sentReplies.add(key));
    final id = _replyIds.putIfAbsent(key, newMessageId);
    try {
      await ref.read(conversationsProvider.notifier).service.send(snap.senderId, id: id, body: reply.text);
      ref.read(conversationsProvider.notifier).load();
      if (mounted) showBiteToast(context, tr('Sent to {name}', {'name': snap.senderUsername}));
    } on MessagesException catch (e) {
      if (!mounted) return;
      setState(() => _sentReplies.remove(key));
      await showAppDialog(context: context, title: tr('Something went wrong'), message: e.message);
    }
  }

  /// One tap from a bite you were sent to the camera, already addressed to the
  /// person who sent it (the shortest way to keep a pair streak going).
  Future<void> _biteBack() async {
    final snap = _snap;
    final shared = await runBiteFlow(context, to: snap.senderId, pickPhoto: widget.pickPhoto);
    if (shared == null || !mounted) return;
    await afterBiteShared(context, ref, shared, say: (text) => showBiteToast(context, text));
  }

  Future<void> _menu() async {
    final snap = _snap;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(snap.senderUsername),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'report'),
            child: Text(tr('Report this bite')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
      ),
    );
    if (choice != 'report' || !mounted) return;
    try {
      await ref.read(snapInboxProvider.notifier).report(snap);
      if (!mounted) return;
      await showAppDialog(
        context: context,
        title: tr('Thanks for telling us'),
        message: tr("We'll take a look. You can also block {v1} from the Friends tab.", {'v1': snap.senderUsername}),
      );
    } on SnapsException catch (e) {
      if (mounted) await showAppDialog(context: context, title: tr('Something went wrong'), message: e.message);
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
                    ? Center(
                        child: Text(tr("This bite couldn't be loaded."), style: TextStyle(color: Color(0xFFFFFFFF))),
                      )
                    : Image.network(
                        snap.imageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : const Center(child: CupertinoActivityIndicator(radius: 14)),
                        errorBuilder: (_, _, _) => Center(
                          child: Text(tr("This bite couldn't be loaded."), style: TextStyle(color: Color(0xFFFFFFFF))),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snap.senderUsername,
                        style: AppType.headline(color: const Color(0xFFFFFFFF)),
                      ),
                      Text(
                        biteSentLabel(snap.createdAt),
                        key: const ValueKey('bite_sent_time'),
                        style: AppType.caption(color: const Color(0xCCFFFFFF), size: 12),
                      ),
                    ],
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
            positionedCaption(context, snap.caption),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom + 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Pressable(
                      key: const ValueKey('bite_back'),
                      onTap: _biteBack,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0x66FFFFFF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.camera_fill, size: 16, color: Color(0xFFFFFFFF)),
                            const SizedBox(width: 8),
                            Text(
                              tr('Bite back'),
                              style: AppType.body(color: const Color(0xFFFFFFFF)).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in quickReplies)
                          Pressable(
                            key: ValueKey('quick_${r.id}'),
                            onTap: () => _quickReply(r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _sentReplies.contains('${snap.id}/${r.id}') ? const Color(0x55FFFFFF) : const Color(0x33FFFFFF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _sentReplies.contains('${snap.id}/${r.id}') ? const Color(0xFFFFFFFF) : const Color(0x44FFFFFF),
                                ),
                              ),
                              child: Text(
                                r.text,
                                style: AppType.body(size: 13.5, color: const Color(0xFFFFFFFF)).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
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
