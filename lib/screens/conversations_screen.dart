import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/messages.dart';
import '../providers/messages_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';
import 'chat_screen.dart';
import 'friends_screen.dart' show FriendAvatar;

/// Every conversation, newest first, with the ones waiting for you marked.
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(conversationsProvider.notifier).load();
    });
  }

  Future<void> _open(Conversation c) async {
    await openChat(context, userId: c.userId, username: c.username, avatarUrl: c.avatarUrl);
    if (mounted) ref.read(conversationsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      child: Column(
        children: [
          FrostedGlass(
            opacity: 0.9,
            tint: TrackerColors.navFill,
            blur: 24,
            borderRadius: BorderRadius.zero,
            border: Border(bottom: BorderSide(color: TrackerColors.border, width: 1)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 10),
                child: Row(
                  children: [
                    CupertinoButton(
                      key: const ValueKey('messages_back'),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Icon(CupertinoIcons.chevron_left, color: TrackerColors.textPrimary, size: 22),
                    ),
                    Text('Messages', style: AppType.headline()),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: () => ref.read(conversationsProvider.notifier).load()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 12, AppSpacing.gutter, 40),
                  sliver: SliverList(delegate: SliverChildListDelegate(_rows(state))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(AsyncValue<ConversationsData> state) {
    final data = state.valueOrNull;
    if (data == null) {
      if (state.hasError) {
        return [
          AppEmptyState(
            icon: CupertinoIcons.wifi_exclamationmark,
            title: "Couldn't load your messages",
            message: 'Pull down to try again.',
            accent: TrackerColors.error,
          ),
        ];
      }
      return const [SkeletonRows(count: 4)];
    }
    if (data.conversations.isEmpty) {
      return [
        const SizedBox(height: 40),
        AppEmptyState(
          icon: CupertinoIcons.chat_bubble_text,
          title: 'No messages yet',
          message: 'Tap the message button next to a friend to start a conversation.',
        ),
      ];
    }
    final now = DateTime.now();
    return [
      for (final c in data.conversations) _ConversationRow(conversation: c, now: now, onTap: () => _open(c)),
    ];
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.now, required this.onTap});

  final Conversation conversation;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unread > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Pressable(
        key: ValueKey('conversation_${c.userId}'),
        onTap: onTap,
        borderRadius: AppRadii.buttonAll,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: AppDecor.card(borderRadius: AppRadii.buttonAll),
          child: Row(
            children: [
              FriendAvatar(username: c.username, imageUrl: c.avatarUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${c.username}', style: AppType.body(size: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      c.lastMine ? 'You: ${c.lastBody}' : c.lastBody,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption(
                        color: unread ? TrackerColors.textPrimary : TrackerColors.textTertiary,
                        size: 12.5,
                      ).copyWith(fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversationTimeLabel(c.lastAt, now),
                    style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
                  ),
                  const SizedBox(height: 4),
                  if (unread) UnreadCount(count: c.unread, key: ValueKey('unread_${c.userId}')) else const SizedBox(height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill with how many messages are waiting.
class UnreadCount extends StatelessWidget {
  const UnreadCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count unread',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: TrackerColors.calorieGradient, borderRadius: BorderRadius.circular(9)),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: AppType.caption(color: TrackerColors.onAccent, size: 10.5).copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
