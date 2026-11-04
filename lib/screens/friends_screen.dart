import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friends.dart';
import '../models/username_rules.dart';
import '../providers/friends_provider.dart';
import '../services/friends_service.dart';
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
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';

/// Friends tab: your username, add someone by theirs, answer requests, and
/// see who you're connected with. Snaps and shared streaks build on this.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _copied = false;
  String? _notice;
  bool _noticeIsError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String text, {bool error = false}) => setState(() {
        _notice = text;
        _noticeIsError = error;
      });

  Future<void> _add() async {
    if (_sending) return;
    final name = _controller.text.trim().replaceFirst(RegExp(r'^@'), '');
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

    if (choice == 'remove') {
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

  Future<void> _copyName(String name) async {
    await Clipboard.setData(ClipboardData(text: name));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final notifier = ref.read(friendsProvider.notifier);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: BoxDecoration(color: TrackerColors.background),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: FrostedGlass(
                opacity: 0.9,
                tint: TrackerColors.navFill,
                blur: 24,
                borderRadius: BorderRadius.zero,
                border: AppDecor.hairlineTop,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
                  child: Row(
                    children: [
                      Text('Friends', style: AppType.title()),
                      const Spacer(),
                      if (friends.hasValue)
                        Text(
                          '${friends.value!.friends.length} / ${friends.value!.limit}',
                          style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: notifier.load),
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

    return [
      if (data?.myUsername != null) ...[
        AppCard(
          glow: TrackerColors.accentStart,
          child: Row(
            children: [
              _Avatar(username: data!.myUsername!, size: 46),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your username', style: AppType.caption(color: TrackerColors.textTertiary, size: 11)),
                    const SizedBox(height: 2),
                    Text('@${data.myUsername}', style: AppType.headline(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _Pill(
                label: _copied ? 'Copied' : 'Copy',
                icon: _copied ? CupertinoIcons.checkmark : CupertinoIcons.doc_on_doc,
                onTap: () => _copyName(data.myUsername!),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
      const SectionHeader(label: 'Add a friend'),
      const SizedBox(height: AppSpacing.md),
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
              onChanged: (_) {
                if (_notice != null) setState(() => _notice = null);
              },
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
        child: _notice == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _noticeIsError ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.checkmark_circle_fill,
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
      const SizedBox(height: AppSpacing.xl),
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

  List<Widget> _lists(FriendsData data) {
    final notifier = ref.read(friendsProvider.notifier);
    return [
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
        const SizedBox(height: AppSpacing.lg),
      ],
      if (data.outgoing.isNotEmpty) ...[
        SectionHeader(label: 'Waiting for a reply', trailing: _count(data.outgoing.length)),
        const SizedBox(height: AppSpacing.md),
        for (final p in data.outgoing)
          _PersonRow(
            person: p,
            subtitle: 'request sent',
            actions: [_Pill(label: 'Cancel', onTap: () => _run(() => notifier.remove(p)))],
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
      SectionHeader(label: 'Your friends', trailing: data.friends.isEmpty ? null : _count(data.friends.length)),
      const SizedBox(height: AppSpacing.md),
      if (data.friends.isEmpty)
        AppEmptyState(
          icon: CupertinoIcons.person_2,
          title: 'No friends yet',
          message: 'Add a friend with their username, or share yours. '
              "Food snaps and shared streaks are coming.",
        )
      else
        for (final p in data.friends)
          _PersonRow(
            person: p,
            subtitle: 'friends since ${_shortDate(p.since)}',
            actions: [_MoreButton(onTap: () => _more(p, isFriend: true))],
          ),
      const SizedBox(height: AppSpacing.xl),
      Center(
        child: CupertinoButton(
          onPressed: () => showAppSheet<void>(
            context: context,
            builder: (_) => _BlockedSheet(service: ref.read(friendsProvider.notifier).service),
          ),
          child: Text('Blocked people', style: AppType.caption(color: TrackerColors.textTertiary, size: 13)),
        ),
      ),
    ];
  }

  Widget _count(int n) =>
      Text('$n', style: AppType.caption(color: TrackerColors.textTertiary, size: 11));
}

String _shortDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = d.toLocal();
  return '${months[local.month - 1]} ${local.day}';
}

/// A round initial on a colour chosen from the name, so a person always looks the same.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.username, this.size = 42});

  final String username;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = (username.toLowerCase().codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0xFFFF) % 360).toDouble();
    final a = HSLColor.fromAHSL(1, hue, 0.75, 0.55).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.8, 0.45).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
      ),
      child: Text(
        username.isEmpty ? '?' : username[0].toUpperCase(),
        style: AppType.headline(color: const Color(0xFFFFFFFF)).copyWith(fontSize: size * 0.42),
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
            _Avatar(username: person.username),
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
