import 'package:flutter/cupertino.dart';

import '../models/friends.dart';
import '../providers/friends_provider.dart';
import '../screens/friends_screen.dart' show FriendAvatar;
import '../services/friends_service.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';

/// What opening someone's profile link shows: who they are and whether to add
/// them. Nothing is sent until the person taps Add.
Future<void> showProfileLinkSheet(
  BuildContext context, {
  required String username,
  required FriendsNotifier friends,
  String? myUsername,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => AppSheet(child: ProfileLinkContent(username: username, friends: friends, myUsername: myUsername)),
  );
}

enum _Stage { looking, found, missing, self, sending, done, failed }

class ProfileLinkContent extends StatefulWidget {
  const ProfileLinkContent({super.key, required this.username, required this.friends, this.myUsername});

  final String username;
  final FriendsNotifier friends;
  final String? myUsername;

  @override
  State<ProfileLinkContent> createState() => _ProfileLinkContentState();
}

class _ProfileLinkContentState extends State<ProfileLinkContent> {
  _Stage _stage = _Stage.looking;
  PersonFound? _person;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _look();
  }

  Future<void> _look() async {
    final mine = widget.myUsername;
    if (mine != null && mine.toLowerCase() == widget.username.toLowerCase()) {
      setState(() => _stage = _Stage.self);
      return;
    }
    final found = await widget.friends.service.search(widget.username.toLowerCase());
    if (!mounted) return;
    final exact = found.where((p) => p.username.toLowerCase() == widget.username.toLowerCase());
    setState(() {
      _person = exact.isEmpty ? null : exact.first;
      _stage = _person == null ? _Stage.missing : _Stage.found;
    });
  }

  Future<void> _add() async {
    final person = _person;
    if (person == null) return;
    setState(() => _stage = _Stage.sending);
    try {
      final result = await widget.friends.sendRequest(person.username);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.done;
        _message = switch (result.outcome) {
          RequestOutcome.accepted => 'You and @${person.username} are now friends!',
          RequestOutcome.alreadyFriends => "You're already friends with @${person.username}.",
          RequestOutcome.alreadySent => 'You already asked @${person.username}. Waiting for them.',
          RequestOutcome.sent => 'Request sent to @${person.username}.',
        };
      });
    } on FriendsException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _message = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.username;
    final person = _person;
    final relation = person?.relation ?? Relation.none;

    Widget header;
    final String line;
    switch (_stage) {
      case _Stage.looking:
        header = const CupertinoActivityIndicator();
        line = 'Finding @$name…';
      case _Stage.self:
        header = Icon(CupertinoIcons.person_crop_circle, size: 56, color: TrackerColors.textTertiary);
        line = "That's your own link. Share it with friends so they can add you.";
      case _Stage.missing:
        header = Icon(CupertinoIcons.person_crop_circle_badge_xmark, size: 56, color: TrackerColors.textTertiary);
        line = "We couldn't find @$name. The link may be out of date, or they may have changed their username.";
      default:
        header = FriendAvatar(username: person?.username ?? name, size: 72, imageUrl: person?.avatarUrl);
        line = switch (_stage) {
          _Stage.done || _Stage.failed => _message,
          _ => switch (relation) {
              Relation.friend => "You're already friends.",
              Relation.requested => 'You already asked them. Waiting for their answer.',
              Relation.wantsYou => 'They asked to be your friend.',
              Relation.none => 'Add them to swap food bites and build a streak.',
            },
        };
    }

    final showAdd = (_stage == _Stage.found || _stage == _Stage.failed || _stage == _Stage.sending) &&
        (relation == Relation.none || relation == Relation.wantsYou);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Center(child: header),
        const SizedBox(height: AppSpacing.md),
        if (_stage == _Stage.found || _stage == _Stage.sending || _stage == _Stage.done || _stage == _Stage.failed)
          Text('@${person?.username ?? name}', style: AppType.title(), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          line,
          key: const ValueKey('profile_link_message'),
          style: AppType.callout(
            color: _stage == _Stage.failed ? TrackerColors.warning : TrackerColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (showAdd)
          AppButton(
            key: const ValueKey('profile_link_add'),
            label: _stage == _Stage.sending ? 'Sending…' : (relation == Relation.wantsYou ? 'Accept' : 'Add friend'),
            icon: CupertinoIcons.person_add_solid,
            onPressed: _stage == _Stage.sending ? null : _add,
          )
        else
          AppButton.glass(
            key: const ValueKey('profile_link_close'),
            label: _stage == _Stage.done ? 'Done' : 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        if (showAdd) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton.glass(label: 'Not now', onPressed: () => Navigator.of(context).pop()),
        ],
      ],
    );
  }
}
