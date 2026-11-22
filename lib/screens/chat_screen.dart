import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/messages.dart';
import '../providers/messages_provider.dart';
import '../providers/house_recipes_provider.dart';
import '../services/messages_service.dart';
import '../widgets/house_recipe_sheet.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import 'friends_screen.dart' show FriendAvatar;
import '../l10n/app_strings.dart';

/// Open the conversation with a friend, over the tab bar.
Future<void> openChat(
  BuildContext context, {
  required String userId,
  required String username,
  String? avatarUrl,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(
      builder: (_) => ChatScreen(userId: userId, username: username, avatarUrl: avatarUrl),
    ),
  );
}

/// A conversation with one friend. New messages arrive by asking the server
/// every few seconds while the screen is open.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.pollEvery = const Duration(seconds: 6),
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final Duration pollEvery;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  /// The message the next one will quote ("Reply" in a message's menu).
  ChatMessage? _replyingTo;

  /// Oldest first. Messages still on their way, or that failed, sit at the end.
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _refreshing = false;
  String? _loadError;
  String? _notice;
  Timer? _poll;
  Timer? _noticeTimer;
  late final AppLifecycleListener _lifecycle;

  MessagesService get _service => ref.read(conversationsProvider.notifier).service;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(widget.pollEvery, (_) => _refresh());
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _noticeTimer?.cancel();
    _lifecycle.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // --- loading -------------------------------------------------------------

  Future<void> _load() async {
    try {
      final thread = await _service.thread(widget.userId);
      if (!mounted) return;
      setState(() {
        _messages = thread.messages;
        _hasMore = thread.hasMore;
        _loading = false;
        _loadError = null;
      });
      _markRead();
    } on MessagesException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    }
  }

  void _markRead() {
    if (_messages.any((m) => !m.mine)) ref.read(conversationsProvider.notifier).markRead(widget.userId);
  }

  /// What the server says, plus what is still older than its page, plus what
  /// hasn't reached it yet.
  List<ChatMessage> _merge(List<ChatMessage> server) {
    final ids = {for (final m in server) m.id};
    final oldest = server.isEmpty ? null : server.first.createdAt;
    return [
      if (oldest != null)
        for (final m in _messages)
          if (m.state == SendState.sent && m.createdAt.isBefore(oldest) && !ids.contains(m.id)) m,
      ...server,
      for (final m in _messages)
        if (m.state != SendState.sent && !ids.contains(m.id)) m,
    ];
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing || _loading) return;
    if (_loadError != null && _messages.isEmpty) return _load();
    _refreshing = true;
    try {
      final thread = await _service.thread(widget.userId);
      if (!mounted) return;
      final known = {for (final m in _messages) m.id};
      final arrived = thread.messages.any((m) => !m.mine && !known.contains(m.id));
      final nearBottom = !_scroll.hasClients || _scroll.offset < 160;
      setState(() {
        _messages = _merge(thread.messages);
        if (_messages.every((m) => m.state == SendState.sent)) _hasMore = thread.hasMore || _hasMore;
        _loadError = null;
      });
      if (arrived) {
        _markRead();
        if (nearBottom) _toBottom();
      }
    } on MessagesException catch (e) {
      // Not friends any more: say so. Anything else is a hiccup; try again next time.
      if (mounted && e.statusCode == 403) setState(() => _loadError = e.message);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadEarlier() async {
    if (_loadingMore) return;
    final oldest = _messages.where((m) => m.state == SendState.sent).firstOrNull;
    if (oldest == null) return;
    setState(() => _loadingMore = true);
    try {
      final thread = await _service.thread(widget.userId, before: oldest.createdAt);
      if (!mounted) return;
      final ids = {for (final m in _messages) m.id};
      setState(() {
        _messages = [...thread.messages.where((m) => !ids.contains(m.id)), ..._messages];
        _hasMore = thread.hasMore;
      });
    } on MessagesException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  // --- sending -------------------------------------------------------------

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
      }
    });
  }

  void _say(String text) {
    if (!mounted) return;
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _replace(String id, ChatMessage Function(ChatMessage) change) {
    if (!mounted) return;
    setState(() => _messages = [for (final m in _messages) m.id == id ? change(m) : m]);
  }

  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty || text.length > maxMessageChars) return;
    _input.clear();
    final replied = _replyingTo;
    final message = ChatMessage(
      id: newMessageId(),
      mine: true,
      body: text,
      createdAt: DateTime.now(),
      state: SendState.sending,
      quote: replied == null
          ? null
          : MessageQuote(id: replied.id, mine: replied.mine, body: MessageQuote.shorten(replied.body)),
      replyToId: replied?.id,
    );
    setState(() {
      _messages = [..._messages, message];
      _replyingTo = null;
    });
    _toBottom();
    await _deliver(message);
  }

  /// Send, or send again. The same id each time, so a retry can't double up.
  Future<void> _deliver(ChatMessage message) async {
    _replace(message.id, (m) => m.copyWith(state: SendState.sending, clearError: true));
    try {
      final saved = await _service.send(widget.userId, id: message.id, body: message.body, replyTo: message.replyToId);
      _replace(message.id, (_) => saved);
      if (mounted) ref.read(conversationsProvider.notifier).load();
    } on MessagesException catch (e) {
      if (e.statusCode == 404 && message.replyToId != null) {
        // The quoted message was unsent meanwhile. Trying again sends the text
        // without the quote, and the line below says so.
        _replace(
          message.id,
          (m) => m.copyWith(
            state: SendState.failed,
            error: tr('The message you replied to was deleted, so it will be sent without the quote'),
            clearQuote: true,
          ),
        );
        return;
      }
      _replace(message.id, (m) => m.copyWith(state: SendState.failed, error: e.message));
    }
  }

  // --- a message's menu ----------------------------------------------------

  Future<void> _menu(ChatMessage message) async {
    if (message.state != SendState.sent) return;
    HapticFeedback.selectionClick();
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheet, 'reply'), child: Text(tr('Reply'))),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheet, 'copy'), child: Text(tr('Copy'))),
          if (message.mine)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(sheet, 'delete'),
              child: Text(tr('Delete for everyone')),
            )
          else
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(sheet, 'report'),
              child: Text(tr('Report message')),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheet), child: Text(tr('Cancel'))),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'reply':
        setState(() => _replyingTo = message);
        _focus.requestFocus();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body));
      case 'delete':
        await _unsend(message);
      case 'report':
        await _report(message);
    }
  }

  Future<void> _unsend(ChatMessage message) async {
    final before = _messages;
    setState(() {
      _messages = [for (final m in _messages) if (m.id != message.id) m];
      if (_replyingTo?.id == message.id) _replyingTo = null;
    });
    try {
      await _service.unsend(message.id);
      if (mounted) ref.read(conversationsProvider.notifier).load();
    } on MessagesException catch (e) {
      if (!mounted) return;
      setState(() => _messages = before);
      _say(e.message);
    }
  }

  Future<void> _report(ChatMessage message) async {
    final sure = await showAppDialog(
      context: context,
      title: tr('Report this message?'),
      message: tr('Our team will read it. You can also block {v1} from your friends list.', {'v1': widget.username}),
      confirmLabel: tr('Report'),
      cancelLabel: tr('Cancel'),
      destructive: true,
    );
    if (sure != true || !mounted) return;
    try {
      await _service.report(message.id);
      _say(tr("Thanks. We'll take a look."));
    } on MessagesException catch (e) {
      _say(e.message);
    }
  }

  // --- screen --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      child: Column(
        children: [
          _Header(username: widget.username, avatarUrl: widget.avatarUrl),
          Expanded(child: _body()),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_notice!, key: const ValueKey('chat_notice'), style: AppType.caption(size: 12.5)),
            ),
          if (_loadError != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: AppType.caption(color: TrackerColors.warning, size: 12.5),
              ),
            ),
          _Composer(
            controller: _input,
            focusNode: _focus,
            username: widget.username,
            replyingTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
            onChanged: () => setState(() {}),
            onSend: _submit,
            // Not friends any more (403): there is nobody to write to.
            disabled: _loadError != null && _messages.isEmpty,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_loadError != null && _messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: AppEmptyState(
          icon: CupertinoIcons.chat_bubble_2,
          title: tr("Couldn't open this conversation"),
          message: _loadError,
          accent: TrackerColors.error,
        ),
      );
    }
    if (_messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: AppEmptyState(
          icon: CupertinoIcons.chat_bubble_text,
          title: tr('Say hi to {v1}', {'v1': widget.username}),
          message: tr('Messages stay between the two of you.'),
        ),
      );
    }

    final n = _messages.length;
    final lastMine = _messages.lastWhere((m) => m.mine, orElse: () => _messages.last);
    final now = DateTime.now();
    return ListView.builder(
      key: const ValueKey('chat_list'),
      controller: _scroll,
      reverse: true, // the newest message sits at the bottom, by the keyboard
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: n + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == n) {
          return Center(
            child: CupertinoButton(
              key: const ValueKey('chat_earlier'),
              onPressed: _loadingMore ? null : _loadEarlier,
              child: Text(_loadingMore ? tr('Loading…') : tr('Earlier messages'), style: AppType.caption(size: 13)),
            ),
          );
        }
        final index = n - 1 - i;
        final message = _messages[index];
        final previous = index > 0 ? _messages[index - 1] : null;
        final gap = previous == null ||
            message.createdAt.difference(previous.createdAt) > const Duration(minutes: 30) ||
            message.createdAt.day != previous.createdAt.day;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (gap)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    chatTimeLabel(message.createdAt, now),
                    style: AppType.caption(color: TrackerColors.textTertiary, size: 11.5),
                  ),
                ),
              ),
            _Bubble(
              message: message,
              otherName: widget.username,
              isLastMine: identical(message, lastMine),
              onLongPress: () => _menu(message),
              onRetry: () => _deliver(message),
              onOpenRecipe: (id) => openRecipeById(context, ref.read(houseRecipesProvider.notifier), id),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.username, this.avatarUrl});

  final String username;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      opacity: 0.9,
      tint: TrackerColors.navFill,
      blur: 24,
      borderRadius: BorderRadius.zero,
      border: Border(bottom: BorderSide(color: TrackerColors.border, width: 1)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
          child: Row(
            children: [
              CupertinoButton(
                key: const ValueKey('chat_back'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                child: Icon(CupertinoIcons.chevron_left, color: TrackerColors.textPrimary, size: 22),
              ),
              FriendAvatar(username: username, size: 36, imageUrl: avatarUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(username, style: AppType.headline(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.otherName,
    required this.isLastMine,
    required this.onLongPress,
    required this.onRetry,
    required this.onOpenRecipe,
  });

  final ChatMessage message;
  final String otherName;
  final bool isLastMine;
  final VoidCallback onLongPress;
  final VoidCallback onRetry;
  final void Function(String recipeId) onOpenRecipe;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final failed = message.state == SendState.failed;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(mine ? 20 : 6),
      bottomRight: Radius.circular(mine ? 6 : 20),
    );
    final status = switch (message.state) {
      SendState.sending => tr('Sending…'),
      SendState.failed => tr('{error}. Tap to try again.', {'error': message.error ?? tr('Not sent')}),
      SendState.sent => !isLastMine
          ? null
          : message.readAt != null
              ? tr('Seen')
              : tr('Sent'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: GestureDetector(
              key: ValueKey('msg_${message.id}'),
              behavior: HitTestBehavior.opaque,
              onLongPress: onLongPress,
              onTap: failed ? onRetry : null,
              child: Opacity(
                opacity: message.state == SendState.sending ? 0.6 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: mine ? TrackerColors.calorieGradient : null,
                    color: mine ? null : TrackerColors.surface,
                    borderRadius: radius,
                    border: mine || !TrackerColors.isDark ? null : Border.all(color: TrackerColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.quote != null)
                        _QuoteBlock(
                          key: ValueKey('quote_${message.id}'),
                          quote: message.quote!,
                          mine: mine,
                          otherName: otherName,
                        ),
                      if (message.attachment == null)
                        Text(
                          message.body,
                          style: AppType.body(
                            size: 15.5,
                            color: mine ? TrackerColors.onAccent : TrackerColors.textPrimary,
                          ),
                        )
                      else
                        _RecipeCard(
                          key: ValueKey('recipe_card_${message.id}'),
                          card: message.attachment!,
                          mine: mine,
                          onOpen: () => onOpenRecipe(message.attachment!.recipeId),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
              child: Text(
                status,
                style: AppType.caption(
                  color: failed ? TrackerColors.error : TrackerColors.textTertiary,
                  size: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.replyingTo,
    required this.onCancelReply,
    required this.username,
    required this.onChanged,
    required this.onSend,
    this.disabled = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatMessage? replyingTo;
  final VoidCallback onCancelReply;
  final String username;
  final VoidCallback onChanged;
  final VoidCallback onSend;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final length = controller.text.trim().length;
    final canSend = !disabled && length > 0 && length <= maxMessageChars;
    return Container(
      decoration: BoxDecoration(
        color: TrackerColors.navFill,
        border: AppDecor.hairlineTop,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (replyingTo != null)
                _ReplyBar(message: replyingTo!, username: username, onCancel: onCancelReply),
              if (controller.text.length >= maxMessageChars - 100)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Text(
                    '${controller.text.length}/$maxMessageChars',
                    textAlign: TextAlign.end,
                    style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      key: const ValueKey('chat_input'),
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !disabled,
                      placeholder: tr('Message {username}', {'username': username}),
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [LengthLimitingTextInputFormatter(maxMessageChars)],
                      onChanged: (_) => onChanged(),
                      style: AppType.body(size: 15.5, color: TrackerColors.textPrimary),
                      placeholderStyle: AppType.body(size: 15.5, color: TrackerColors.textTertiary),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: TrackerColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: TrackerColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: tr('Send message'),
                    child: Pressable(
                      key: const ValueKey('chat_send'),
                      onTap: canSend ? onSend : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: canSend ? TrackerColors.calorieGradient : null,
                          color: canSend ? null : TrackerColors.surface,
                          border: canSend ? null : Border.all(color: TrackerColors.border),
                        ),
                        child: Icon(
                          CupertinoIcons.arrow_up,
                          size: 19,
                          color: canSend ? TrackerColors.onAccent : TrackerColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A recipe a friend sent (or I sent): its name and calories, and a tap to open.
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({super.key, required this.card, required this.mine, required this.onOpen});

  final MessageAttachment card;
  final bool mine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ink = mine ? TrackerColors.onAccent : TrackerColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.book_fill, size: 20, color: ink),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Recipe'), style: AppType.caption(size: 11, color: ink.withValues(alpha: 0.75))),
                Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15.5, color: ink)),
                Text(tr('{n} kcal per serving · tap to open', {'n': card.calories}), style: AppType.caption(size: 11.5, color: ink.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The quoted message at the top of a reply's bubble.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({super.key, required this.quote, required this.mine, required this.otherName});

  final MessageQuote quote;
  final bool mine;
  final String otherName;

  @override
  Widget build(BuildContext context) {
    final ink = mine ? TrackerColors.onAccent : TrackerColors.textPrimary;
    final who = quote.mine == true ? tr('You') : otherName;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: ink.withValues(alpha: 0.6), width: 3)),
      ),
      child: quote.deleted
          ? Text(
              tr('Original message deleted'),
              style: AppType.caption(size: 12.5, color: ink.withValues(alpha: 0.75)).copyWith(fontStyle: FontStyle.italic),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(who, style: AppType.caption(size: 11.5, color: ink.withValues(alpha: 0.8))),
                Text(
                  quote.body ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 13.5, color: ink.withValues(alpha: 0.9)),
                ),
              ],
            ),
    );
  }
}

/// Above the input while a reply is being written: who and what is quoted, and a way to drop it.
class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.message, required this.username, required this.onCancel});

  final ChatMessage message;
  final String username;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final name = message.mine ? tr('You') : username;
    return Container(
      key: const ValueKey('reply_bar'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
      decoration: BoxDecoration(
        color: TrackerColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: TrackerColors.textSecondary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Replying to {name}', {'name': name}), style: AppType.caption(size: 11.5, color: TrackerColors.textTertiary)),
                Text(
                  MessageQuote.shorten(message.body),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 13.5, color: TrackerColors.textPrimary),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: tr('Cancel reply'),
            child: CupertinoButton(
              key: const ValueKey('reply_cancel'),
              padding: const EdgeInsets.all(8),
              minimumSize: Size.zero,
              onPressed: onCancel,
              child: Icon(CupertinoIcons.xmark_circle_fill, size: 20, color: TrackerColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
