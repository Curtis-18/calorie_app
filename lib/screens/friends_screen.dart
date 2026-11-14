import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/friends.dart';
import '../models/snaps.dart';
import '../models/stories.dart';
import 'bite_camera_screen.dart';
import '../providers/snaps_provider.dart';
import '../widgets/snaps/flame.dart';
import '../widgets/snaps/sent_bites_sheet.dart';
import 'snap_compose_screen.dart';
import 'snap_viewer_screen.dart';
import 'story_viewer_screen.dart';
import '../widgets/snaps/story_tray.dart';
import '../models/username_rules.dart';
import '../providers/friends_provider.dart';
import '../providers/shell_provider.dart';
import '../services/friends_service.dart';
import '../services/profile_link.dart';
import '../services/tour_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_field.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/page_header.dart';
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';

/// Friends tab: your username, add someone by theirs, answer requests, and
/// see who you're connected with. Snaps and shared streaks build on this.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key, this.pickPhoto, this.share});

  /// Replaces the camera; for tests.
  final Future<XFile?> Function()? pickPhoto;

  /// Replaces the system share sheet; for tests.
  final Future<void> Function(String text)? share;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _copied = false;
  String? _notice;
  bool _noticeIsError = false;
  int _embers = 0;

  // Suggestions while typing a username.
  List<PersonFound> _found = const [];
  String? _foundFor; // the query the list on screen answers
  Timer? _searchDebounce;
  int _searchRun = 0;

  /// Answers already received, by what was searched for. Emptied whenever
  /// a request is sent or the page refreshes, so labels don't go stale.
  final _answers = <String, List<PersonFound>>{};

  // Keeping the page current without pulling down: requests and bites from
  // other people arrive while this screen is open.
  static const _refreshEvery = Duration(seconds: 45);
  Timer? _refreshTimer;
  late final AppLifecycleListener _lifecycle;

  /// The "Share your meal" tip is for people who haven't shared yet. Treated
  /// as already seen until the saved choice has been read, so it never flashes.
  bool _tipSeen = true;

  Future<void> _loadTip() async {
    try {
      final seen = await TourService.hasSeen(TourService.shareTip);
      if (mounted && !seen) setState(() => _tipSeen = false);
    } catch (_) {
      // Storage unavailable: show the tip; dismissing still works this session.
      if (mounted) setState(() => _tipSeen = false);
    }
  }

  void _hideTip() {
    if (!_tipSeen) setState(() => _tipSeen = true);
    TourService.markSeen(TourService.shareTip).catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    _loadTip();
    _lifecycle = AppLifecycleListener(onResume: _refreshQuietly);
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _refreshQuietly());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _refreshTimer?.cancel();
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Reload friends, requests and bites in the background, but only while
  /// this tab is the one on screen.
  void _refreshQuietly() {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    _answers.clear();
    ref.read(friendsProvider.notifier).load();
    ref.read(snapInboxProvider.notifier).load();
  }

  /// Search as you type. The server is slow to answer (about a second or
  /// more), so the list never waits for it when it doesn't have to:
  ///  - an answer already received for this spelling is shown at once;
  ///  - one more letter narrows the list on screen at once, and if that list
  ///    was the whole answer (fewer than the server's limit) nothing is asked;
  ///  - otherwise the server is asked after a short pause, and its answer
  ///    replaces the narrowed list.
  void _onNameChanged(String text) {
    if (_notice != null) setState(() => _notice = null);
    _searchDebounce?.cancel();
    final query = peopleSearchQuery(text);
    if (query == null) {
      _searchRun++; // drop any answer still on its way
      if (_found.isNotEmpty || _foundFor != null) {
        setState(() {
          _found = const [];
          _foundFor = null;
        });
      }
      return;
    }

    final known = _knownAnswer(query);
    if (known != null) {
      _searchRun++;
      setState(() {
        _found = known;
        _foundFor = query;
      });
      return;
    }

    // Not known in full: show what can be worked out now, then ask.
    final base = _foundFor;
    if (base != null && query.startsWith(base)) {
      setState(() => _found = narrowPeople(_found, query));
    }
    _searchDebounce = Timer(const Duration(milliseconds: 150), () => _search(query));
  }

  /// The complete answer for [query] if it can be had without the server:
  /// remembered, or narrowed from a remembered complete answer for a shorter
  /// spelling.
  List<PersonFound>? _knownAnswer(String query) {
    final exact = _answers[query];
    if (exact != null) return exact;
    for (var length = query.length - 1; length >= 2; length--) {
      final shorter = _answers[query.substring(0, length)];
      if (shorter != null && shorter.length < peopleSearchLimit) return narrowPeople(shorter, query);
    }
    return null;
  }

  Future<void> _search(String query) async {
    final run = ++_searchRun;
    final found = await ref.read(friendsProvider.notifier).service.search(query);
    if (!mounted) return;
    _answers[query] = found;
    // A newer keystroke has taken over, or the field was cleared.
    if (run != _searchRun) return;
    setState(() {
      _found = found;
      _foundFor = query;
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchRun++;
    _found = const [];
    _foundFor = null;
    _answers.clear(); // who is "Requested" or a friend has just changed
  }

  void _say(String text, {bool error = false}) => setState(() {
        _notice = text;
        _noticeIsError = error;
      });

  Future<void> _add([String? picked]) async {
    if (_sending) return;
    final name = picked ?? _controller.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (name.isEmpty) return;
    final problem = validateUsername(name);
    if (problem != null) {
      _say("That doesn't look like a username. $problem", error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await ref.read(friendsProvider.notifier).sendRequest(name);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _controller.clear();
      _clearSearch();
      _say(switch (result.outcome) {
        RequestOutcome.sent => 'Request sent to @${result.username}.',
        RequestOutcome.accepted => 'You and @${result.username} are now friends!',
        RequestOutcome.alreadyFriends => "You're already friends with @${result.username}.",
        RequestOutcome.alreadySent => 'You already asked @${result.username}. Waiting for them.',
      });
    } on FriendsException catch (e) {
      if (mounted) _say(e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Open the camera (no gallery: bites are food you're eating right now),
  /// then compose. [to] pre-selects a friend; [story] pre-selects your story.
  Future<void> _snap({String? to, bool story = false}) async {
    final XFile? photo;
    try {
      photo = await (widget.pickPhoto ?? _takePhoto)();
    } catch (_) {
      if (!mounted) return;
      await showAppDialog(
        context: context,
        title: "Couldn't open the camera",
        message: 'Allow camera access in Settings to send bites.',
      );
      return;
    }
    if (photo == null || !mounted) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    final shared = await Navigator.of(context).push<ComposeResult>(
      CupertinoPageRoute(builder: (_) => SnapComposeScreen(image: bytes, preselect: to, toStory: story)),
    );
    if (shared == null || !mounted) return;
    final results = shared.outcomes;
    _hideTip(); // they have shared: the tip has done its job
    if (results.isNotEmpty) ref.read(friendsProvider.notifier).load();
    if (shared.addedToStory) ref.read(storiesProvider.notifier).load();
    final lit = results.where((r) => r.completedToday).toList();
    setState(() => _embers++);
    if (lit.isNotEmpty) {
      final best = lit.reduce((a, b) => a.streak >= b.streak ? a : b);
      await showStreakCelebration(context, username: best.username, streak: best.streak);
    } else {
      _say(shareSummary(shared));
    }
  }

  /// Play stories full screen. [mine] opens your own; otherwise the tray's
  /// friends from [index] onwards, one after another.
  Future<void> _openStories(StoryFeed feed, {required String myUsername, String? myAvatarUrl, int? index}) async {
    final reels = index == null
        ? [StoryReel.mine(feed.mine, username: myUsername, avatarUrl: myAvatarUrl)]
        : [for (final g in feed.friends) StoryReel.friend(g)];
    final result = await Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder<String>(
        opaque: true,
        transitionDuration: AppMotion.medium,
        pageBuilder: (_, _, _) => StoryViewerScreen(reels: reels, startReel: index ?? 0),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
        ),
      ),
    );
    if (result == storyViewerAdd && mounted) await _snap(story: true);
  }

  /// The food camera (plate guide + meal stamp). If the live camera can't
  /// start, the system camera takes over so sending a bite never dead-ends.
  Future<XFile?> _takePhoto() async {
    final result = await Navigator.of(context).push<BiteCameraResult>(
      CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const BiteCameraScreen()),
    );
    if (result == null) return null; // closed without a photo
    if (result.bytes != null) return XFile.fromData(result.bytes!, mimeType: 'image/jpeg', name: 'bite.jpg');
    return ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      maxHeight: 1350,
      imageQuality: 82,
    );
  }

  void _openInbox(List<InboxSnap> snaps, int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: AppMotion.medium,
        pageBuilder: (_, _, _) => SnapViewerScreen(snaps: snaps, startAt: index),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FriendsException catch (e) {
      if (!mounted) return;
      await showAppDialog(context: context, title: 'Something went wrong', message: e.message);
    }
  }

  Future<void> _more(Person person, {required bool isFriend}) async {
    final notifier = ref.read(friendsProvider.notifier);
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('@${person.username}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'remove'),
            child: Text(isFriend ? 'Remove friend' : 'Decline request'),
          ),
          if (person.avatarUrl != null)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'report_photo'),
              child: const Text('Report profile photo'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'block'),
            child: const Text('Block'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'report_photo') {
      await _run(() async {
        await notifier.service.reportPhoto(person.friendshipId!);
        if (!mounted) return;
        await showAppDialog(
          context: context,
          title: 'Thanks for telling us',
          message: "We'll take a look. You can also block @${person.username} from the same menu.",
        );
      });
    } else if (choice == 'remove') {
      final sure = isFriend
          ? await showAppDialog(
              context: context,
              title: 'Remove @${person.username}?',
              message: "You'll stop being friends. You can add each other again later.",
              confirmLabel: 'Remove',
              cancelLabel: 'Cancel',
              destructive: true,
            )
          : true;
      if (sure == true) await _run(() => isFriend ? notifier.remove(person) : notifier.decline(person));
    } else {
      final sure = await showAppDialog(
        context: context,
        title: 'Block @${person.username}?',
        message: "They won't be able to find you or send you anything, and you won't see them. "
            "They aren't told. You can unblock them any time.",
        confirmLabel: 'Block',
        cancelLabel: 'Cancel',
        destructive: true,
      );
      if (sure == true) await _run(() => notifier.block(person));
    }
  }

  /// Copy the link to your profile, to paste into a message or a bio.
  Future<void> _copyLink(String username) async {
    await Clipboard.setData(ClipboardData(text: ProfileLink.urlFor(username)));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// Open the system share sheet with your profile link.
  Future<void> _shareLink(String username) async {
    final url = ProfileLink.urlFor(username);
    try {
      await (widget.share ?? (text) => SharePlus.instance.share(ShareParams(text: text)))(
        'Add me on NuStreak: $url',
      );
    } catch (_) {
      // No share sheet here (some desktop browsers): copying still works.
      await _copyLink(username);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Coming back to this tab shows what arrived meanwhile.
    ref.listen<ShellTab>(shellTabProvider, (previous, tab) {
      if (tab == ShellTab.friends && previous != ShellTab.friends) {
        ref.read(friendsProvider.notifier).load();
        ref.read(snapInboxProvider.notifier).load();
      }
    });
    final friends = ref.watch(friendsProvider);
    final notifier = ref.read(friendsProvider.notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Positioned.fill(child: _page(friends, notifier, bottomInset)),
          if (_embers > 0) Positioned.fill(child: EmberBurst(key: ValueKey(_embers))),
        ],
      ),
    );
  }

  Widget _page(AsyncValue<FriendsData> friends, FriendsNotifier notifier, double bottomInset) {
    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: BoxDecoration(color: TrackerColors.background),
        child: Column(
          children: [
            PageHeader(
              title: 'Friends',
              subtitle: friends.hasValue
                  ? '${friends.value!.friends.length} of ${friends.value!.limit} friends'
                  : 'Share meals, keep streaks together',
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () => Future.wait([
                      notifier.load(),
                      ref.read(snapInboxProvider.notifier).load(),
                      ref.read(storiesProvider.notifier).load(),
                    ]),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 18, 24, AppSpacing.tabBarClearance + bottomInset),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        ..._body(friends),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(AsyncValue<FriendsData> friends) {
    final data = friends.valueOrNull;
    final notifier = ref.read(friendsProvider.notifier);

    final inbox = ref.watch(snapInboxProvider).valueOrNull ?? const <InboxSnap>[];
    // No tray until stories have loaded: an older server, or one where they
    // aren't set up yet, simply shows the page as it was.
    final feed = ref.watch(storiesProvider).valueOrNull;
    final me = data?.myUsername;
    return [
      if (feed != null && me != null && (data!.friends.isNotEmpty || feed.mine.isNotEmpty)) ...[
        StoryTray(
          feed: feed,
          myUsername: me,
          myAvatarUrl: data.myAvatarUrl,
          onMine: () => feed.mine.isEmpty
              ? _snap(story: true)
              : _openStories(feed, myUsername: me, myAvatarUrl: data.myAvatarUrl),
          onFriend: (i) => _openStories(feed, myUsername: me, index: i),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      // Finding people sits right under the story row, where you look first.
      ..._addFriend(data),
      if (data != null && data.friends.isNotEmpty) ...[
        // A first-time tip, not a permanent banner: gone once dismissed, once
        // they have shared, or if they clearly already do (a streak, or a
        // bite sent today). Bites are still one tap away on each friend, and
        // your own bubble in the story row opens the camera.
        if (!_tipSeen && !data.friends.any((p) => p.streak > 0 || p.sentToday)) ...[
          _ShareTip(onTap: () => _snap(), onDismiss: _hideTip),
          const SizedBox(height: AppSpacing.sm),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            key: const ValueKey('open_sent_bites'),
            padding: const EdgeInsets.symmetric(vertical: 10),
            minimumSize: Size.zero,
            onPressed: () => showSentBitesSheet(context, ref.read(snapInboxProvider.notifier).service),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bites you sent', style: AppType.caption(color: TrackerColors.textSecondary, size: 13)),
                const SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_right, size: 12, color: TrackerColors.textTertiary),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (inbox.isNotEmpty) ...[
        SectionHeader(label: 'Bites from friends', trailing: _count(inbox.length)),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: inbox.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, i) => _InboxBubble(snap: inbox[i], onTap: () => _openInbox(inbox, i)),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      ...friends.when(
        loading: () => const [SkeletonRows(count: 4)],
        error: (e, _) => [
          AppEmptyState(
            icon: CupertinoIcons.wifi_exclamationmark,
            title: "Couldn't load your friends",
            message: e is FriendsException ? e.message : 'Pull down to try again.',
            accent: TrackerColors.error,
          ),
          Center(child: AppButton.glass(label: 'Try again', onPressed: notifier.load)),
        ],
        data: _lists,
      ),
    ];
  }

  /// One card for finding people: search as you type, and the link to your own
  /// profile to share the way you would a LinkedIn or Instagram profile.
  List<Widget> _addFriend(FriendsData? data) => [
        const SectionHeader(label: 'Add a friend'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppField(
                      placeholder: 'Their username',
                      controller: _controller,
                      icon: CupertinoIcons.at,
                      keyboardType: TextInputType.visiblePassword, // no autocorrect or suggestions
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_@]')),
                        LengthLimitingTextInputFormatter(usernameMaxLength + 1),
                      ],
                      onChanged: _onNameChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 84,
                    child: AppButton(label: _sending ? '…' : 'Add', onPressed: _sending ? null : _add),
                  ),
                ],
              ),
              AnimatedSize(
                duration: AppMotion.quick,
                alignment: Alignment.topCenter,
                child: _found.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Column(
                          key: const ValueKey('people_suggestions'),
                          children: [
                            for (final person in _found)
                              _SuggestionRow(
                                key: ValueKey('suggest_${person.username}'),
                                person: person,
                                busy: _sending,
                                onAdd: () => _add(person.username),
                              ),
                          ],
                        ),
                      ),
              ),
              AnimatedSize(
                duration: AppMotion.quick,
                child: _notice == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _noticeIsError
                                  ? CupertinoIcons.exclamationmark_circle
                                  : CupertinoIcons.checkmark_circle_fill,
                              size: 14,
                              color: _noticeIsError ? TrackerColors.warning : TrackerColors.accentStartText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _notice!,
                                style: AppType.caption(
                                  color: _noticeIsError ? TrackerColors.warning : TrackerColors.accentStartText,
                                  size: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (data?.myUsername != null) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppDivider(),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    FriendAvatar(username: data!.myUsername!, size: 40, imageUrl: data.myAvatarUrl),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your profile link',
                            style: AppType.caption(color: TrackerColors.textTertiary, size: 11.5),
                          ),
                          const SizedBox(height: 2),
                          // Shrinks rather than cutting off the end of the link.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              ProfileLink.display(data.myUsername!),
                              key: const ValueKey('my_profile_link'),
                              style: AppType.body(size: 14).copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.glass(
                        key: const ValueKey('copy_profile_link'),
                        label: _copied ? 'Copied' : 'Copy link',
                        icon: _copied ? CupertinoIcons.checkmark : CupertinoIcons.link,
                        height: 44,
                        onPressed: () => _copyLink(data.myUsername!),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        key: const ValueKey('share_profile_link'),
                        label: 'Share',
                        icon: CupertinoIcons.share,
                        height: 44,
                        onPressed: () => _shareLink(data.myUsername!),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ];

  /// What needs an answer first (requests), then your friends, then requests
  /// you are waiting on. Adding people is above, under the story row.
  List<Widget> _lists(FriendsData data) {
    final notifier = ref.read(friendsProvider.notifier);
    final requests = [
      if (data.incoming.isNotEmpty) ...[
        SectionHeader(label: 'Requests', trailing: _count(data.incoming.length)),
        const SizedBox(height: AppSpacing.md),
        for (final p in data.incoming)
          _PersonRow(
            person: p,
            subtitle: 'wants to be your friend',
            actions: [
              _Pill(label: 'Accept', primary: true, onTap: () => _run(() => notifier.accept(p))),
              _MoreButton(onTap: () => _more(p, isFriend: false)),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    ];
    final waiting = [
      if (data.outgoing.isNotEmpty) ...[
        SectionHeader(label: 'Waiting for a reply', trailing: _count(data.outgoing.length)),
        const SizedBox(height: AppSpacing.md),
        for (final p in data.outgoing)
          _PersonRow(
            person: p,
            subtitle: 'request sent',
            actions: [_Pill(label: 'Cancel', onTap: () => _run(() => notifier.remove(p)))],
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    ];
    final yours = [
      SectionHeader(label: 'Your friends', trailing: data.friends.isEmpty ? null : _count(data.friends.length)),
      const SizedBox(height: AppSpacing.md),
      if (data.friends.isEmpty)
        AppEmptyState(
          icon: CupertinoIcons.person_2,
          title: 'No friends yet',
          message: 'Add a friend with their username, or share yours. '
              'Then send each other food bites to build a streak.',
        )
      else
        for (final p in data.friends)
          _PersonRow(
            person: p,
            subtitle: _friendSubtitle(p),
            actions: [
              if (p.streak > 0) StreakBadge(count: p.streak, lit: p.sentToday && p.theySentToday),
              _Pill(label: 'Bite', icon: CupertinoIcons.camera_fill, primary: true, onTap: () => _snap(to: p.userId)),
              _MoreButton(onTap: () => _more(p, isFriend: true)),
            ],
          ),
      const SizedBox(height: AppSpacing.xl),
    ];
    return [...requests, ...yours, ...waiting];
  }

  Widget _count(int n) =>
      Text('$n', style: AppType.caption(color: TrackerColors.textTertiary, size: 11));
}

String _friendSubtitle(Person p) {
  if (p.theySentToday && !p.sentToday) return 'sent you a bite today. Send one back!';
  if (p.sentToday && !p.theySentToday) return p.streak > 0 ? 'waiting on them to keep the streak' : 'waiting on their bite';
  if (p.sentToday && p.theySentToday) return 'streak is safe today';
  return p.streak > 0 ? 'send a bite to keep your streak' : 'friends since ${_shortDate(p.since)}';
}

String _shortDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = d.toLocal();
  return '${months[local.month - 1]} ${local.day}';
}

/// Avatar colours: cool, saturated pairs that sit with the lime/aqua brand and
/// keep white initials readable. Deliberately no orange, red or yellow, so a
/// friend's avatar can never be mistaken for a flame or a warning.
const _avatarGradients = <List<Color>>[
  [Color(0xFF7C4DFF), Color(0xFFE040FB)], // violet to magenta
  [Color(0xFF3D5AFE), Color(0xFF00B0FF)], // indigo to sky
  [Color(0xFF00BFA5), Color(0xFF00897B)], // teal
  [Color(0xFF00A86B), Color(0xFF0D9488)], // emerald to teal
  [Color(0xFFD81B8A), Color(0xFF7E3FF2)], // pink to violet
  [Color(0xFF2979FF), Color(0xFF00C2B8)], // blue to aqua
  [Color(0xFF5E35B1), Color(0xFF3949AB)], // deep purple to indigo
  [Color(0xFF8E24AA), Color(0xFFEC407A)], // purple to rose
];

/// A person's picture, or (until they set one, or if it can't load) a round
/// initial on a colour chosen from the name, so they always look the same.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.username, this.size = 42, this.imageUrl});

  final String username;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final pair = _avatarGradients[
        username.toLowerCase().codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0xFFFF) % _avatarGradients.length];
    final initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pair),
      ),
      child: Text(
        username.isEmpty ? '?' : username[0].toUpperCase(),
        style: AppType.headline(color: const Color(0xFFFFFFFF)).copyWith(fontSize: size * 0.42),
      ),
    );
    final url = imageUrl;
    if (url == null) return initial;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            initial, // shows while the picture loads, and stays if it fails
            Image.network(
              url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // Decoded near the size it is drawn at, not at full resolution.
              cacheWidth: (size * 3).round(),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.subtitle, required this.actions});

  final Person person;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: AppDecor.card(borderRadius: AppRadii.buttonAll),
        child: Row(
          children: [
            FriendAvatar(username: person.username, imageUrl: person.avatarUrl),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${person.username}', style: AppType.body(size: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppType.caption(color: TrackerColors.textTertiary, size: 11.5)),
                ],
              ),
            ),
            for (final a in actions) ...[const SizedBox(width: 6), a],
          ],
        ),
      ),
    );
  }
}

/// One person in the list that narrows as you type: tap Add to send the
/// request without finishing the name.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({super.key, required this.person, required this.onAdd, this.busy = false});

  final PersonFound person;
  final VoidCallback onAdd;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final status = switch (person.relation) {
      Relation.friend => 'Friends',
      Relation.requested => 'Requested',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          FriendAvatar(username: person.username, size: 36, imageUrl: person.avatarUrl),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '@${person.username}',
              style: AppType.body(size: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (status != null)
            Text(status, style: AppType.caption(color: TrackerColors.textTertiary, size: 12.5))
          else
            Opacity(
              opacity: busy ? 0.5 : 1,
              child: _Pill(
                label: person.relation == Relation.wantsYou ? 'Accept' : 'Add',
                icon: CupertinoIcons.person_add_solid,
                primary: true,
                onTap: busy ? () {} : onAdd,
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.icon, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = primary ? TrackerColors.onAccent : TrackerColors.textSecondary;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: primary ? TrackerColors.calorieGradient : null,
          color: primary ? null : TrackerColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: primary ? TrackerColors.alpha(TrackerColors.onAccent, 0.2) : TrackerColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 5)],
            Text(label, style: AppType.caption(color: color, size: 12.5).copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'More options',
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(CupertinoIcons.ellipsis, size: 18, color: TrackerColors.textTertiary),
        ),
      ),
    );
  }
}

/// People you have blocked, with a way to unblock them. Opened from
/// Settings (it used to be a small link at the bottom of this screen).
Future<void> showBlockedPeopleSheet(BuildContext context, FriendsService service) =>
    showAppSheet<void>(context: context, builder: (_) => _BlockedSheet(service: service));

class _BlockedSheet extends StatefulWidget {
  const _BlockedSheet({required this.service});

  final FriendsService service;

  @override
  State<_BlockedSheet> createState() => _BlockedSheetState();
}

class _BlockedSheetState extends State<_BlockedSheet> {
  List<Person>? _blocked;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.service.blocks();
      if (mounted) setState(() => _blocked = list);
    } on FriendsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _unblock(Person p) async {
    try {
      await widget.service.unblock(p.userId);
      await _load();
    } on FriendsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    return AppSheet(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blocked people', style: AppType.title()),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Blocked people can't find you or add you, and you won't see them.",
              style: AppType.callout(),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null)
              Text(_error!, style: AppType.caption(color: TrackerColors.warning, size: 13))
            else if (blocked == null)
              const SkeletonRows(count: 2)
            else if (blocked.isEmpty)
              Text("You haven't blocked anyone.", style: AppType.body(color: TrackerColors.textSecondary))
            else
              for (final p in blocked)
                _PersonRow(
                  person: p,
                  subtitle: 'blocked',
                  actions: [_Pill(label: 'Unblock', onTap: () => _unblock(p))],
                ),
          ],
        ),
      ),
    );
  }
}


/// A one-time tip for new people: what bites are for. Tap it to send one;
/// the close button hides it for good.
class _ShareTip extends StatelessWidget {
  const _ShareTip({required this.onTap, required this.onDismiss});

  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ink = TrackerColors.onAccent;
    return Stack(
      key: const ValueKey('share_tip'),
      children: [
        Pressable(
          onTap: onTap,
          borderRadius: AppRadii.containerAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 44, 18),
            decoration: BoxDecoration(
              gradient: TrackerColors.calorieGradient,
              borderRadius: AppRadii.containerAll,
              boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 26, opacity: 0.35),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: TrackerColors.alpha(ink, 0.12), shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.camera_fill, color: ink, size: 21),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TIP', style: AppType.sectionLabel(color: TrackerColors.alpha(ink, 0.7))),
                      const SizedBox(height: 2),
                      Text('Share your meal', style: AppType.headline(color: ink)),
                      const SizedBox(height: 2),
                      Text(
                        'Send a photo of what you are eating to friends, or add it to your story. '
                        'Swap one every day to build a streak together.',
                        style: AppType.caption(color: TrackerColors.alpha(ink, 0.85), size: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Semantics(
            button: true,
            label: 'Dismiss tip',
            child: Pressable(
              key: const ValueKey('dismiss_share_tip'),
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(CupertinoIcons.xmark, size: 15, color: TrackerColors.alpha(ink, 0.75)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A friend's snap waiting in the strip: a glowing ring until you open it.
class _InboxBubble extends StatelessWidget {
  const _InboxBubble({required this.snap, required this.onTap});

  final InboxSnap snap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: snap.viewed ? null : TrackerColors.calorieGradient,
                border: snap.viewed ? Border.all(color: TrackerColors.border, width: 2) : null,
                boxShadow: snap.viewed ? null : AppDecor.glow(TrackerColors.accentStart, blur: 14, opacity: 0.35),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: TrackerColors.background),
                child: ClipOval(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: snap.imageUrl == null
                        ? FriendAvatar(username: snap.senderUsername, size: 52)
                        : Image.network(
                            snap.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => FriendAvatar(username: snap.senderUsername, size: 52),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              snap.senderUsername,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption(
                color: snap.viewed ? TrackerColors.textTertiary : TrackerColors.textPrimary,
                size: 11.5,
              ),
            ),
            Text(
              biteSentLabel(snap.createdAt),
              maxLines: 1,
              style: AppType.caption(color: TrackerColors.textTertiary, size: 10),
            ),
          ],
        ),
      ),
    );
  }
}
