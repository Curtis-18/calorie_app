import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friends.dart';
import '../models/snaps.dart';
import '../providers/friends_provider.dart';
import '../providers/snaps_provider.dart';
import '../services/snaps_service.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/pressable.dart';
import '../widgets/snaps/flame.dart';
import 'friends_screen.dart' show FriendAvatar;

/// What a share did: the per-friend streak results of a bite, and whether the
/// photo also went on the person's story.
class ComposeResult {
  const ComposeResult({this.outcomes = const [], this.addedToStory = false});

  final List<SendOutcome> outcomes;
  final bool addedToStory;
}

/// One line saying where the photo went.
String shareSummary(ComposeResult r) {
  final n = r.outcomes.length;
  if (n == 0) return 'Added to your story.';
  final who = n == 1 ? '@${r.outcomes.first.username}' : '$n friends';
  return r.addedToStory ? 'Sent to $who and added to your story.' : 'Sent to $who.';
}

/// The photo you just took, a caption, and who gets it: your story (every
/// friend, for 24 hours), chosen friends, or both. Pops with a
/// [ComposeResult] once shared.
class SnapComposeScreen extends ConsumerStatefulWidget {
  const SnapComposeScreen({super.key, required this.image, this.service, this.preselect, this.toStory = false});

  /// Start with "Your story" ticked.
  final bool toStory;

  final Uint8List image;
  final SnapsService? service;

  /// A friend to tick already (when sent from their row).
  final String? preselect;

  @override
  ConsumerState<SnapComposeScreen> createState() => _SnapComposeScreenState();
}

class _SnapComposeScreenState extends ConsumerState<SnapComposeScreen> {
  static const maxRecipients = 20;

  final _caption = TextEditingController();
  late final SnapsService _service = widget.service ?? ref.read(snapInboxProvider.notifier).service;
  // One id per compose session: tapping Send again after a flaky network
  // can't deliver the same snap twice.
  final String _snapId = newSnapId();
  final String _storyId = newSnapId();
  late bool _story = widget.toStory;
  // If the story went up but the bite then failed, Send again only repeats the bite.
  bool _storyPosted = false;
  late final Set<String> _selected = {if (widget.preselect != null) widget.preselect!};
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _toggle(Person p) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (!_selected.remove(p.userId)) {
        if (_selected.length >= maxRecipients) {
          _error = 'You can send to $maxRecipients friends at a time.';
        } else {
          _selected.add(p.userId);
        }
      }
    });
  }

  Future<void> _send() async {
    if (_sending || (_selected.isEmpty && !_story)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (_story && !_storyPosted) {
        await _service.postStory(id: _storyId, image: widget.image, caption: _caption.text);
        _storyPosted = true;
      }
      final results = _selected.isEmpty
          ? const <SendOutcome>[]
          : await _service.send(
              id: _snapId,
              image: widget.image,
              recipientIds: _selected.toList(),
              caption: _caption.text,
            );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(ComposeResult(outcomes: results, addedToStory: _story));
    } on SnapsException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = _storyPosted && _selected.isNotEmpty
              ? "It's on your story, but the bite didn't send. ${e.message}"
              : e.message;
        });
      }
    }
  }

  String get _label {
    final n = _selected.length;
    final friends = '$n ${n == 1 ? 'friend' : 'friends'}';
    if (_story) return n == 0 ? 'Add to your story' : 'Share to story and $friends';
    return n == 0 ? 'Pick who gets it' : 'Send to $friends';
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).valueOrNull?.friends ?? const <Person>[];
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: TrackerColors.navFill,
        middle: Text('Send a bite', style: AppType.headline()),
        border: Border(bottom: BorderSide(color: TrackerColors.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Hero(
                    tag: 'snap-preview',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 4 / 5,
                        child: Image.memory(widget.image, fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CupertinoTextField(
                    controller: _caption,
                    placeholder: 'Add a caption…',
                    maxLength: 120,
                    maxLines: 2,
                    minLines: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    style: AppType.body(),
                    placeholderStyle: AppType.body(color: TrackerColors.textTertiary),
                    decoration: BoxDecoration(
                      color: TrackerColors.surfaceElevated,
                      borderRadius: AppRadii.buttonAll,
                      border: Border.all(color: TrackerColors.border),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Share to', style: AppType.caption(color: TrackerColors.textTertiary, size: 12)),
                  const SizedBox(height: AppSpacing.sm),
                  _StoryChoice(
                    selected: _story,
                    // Once it is up, unticking it wouldn't take it down.
                    onTap: _storyPosted
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() => _story = !_story);
                          },
                  ),
                  if (friends.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Send as a bite', style: AppType.caption(color: TrackerColors.textTertiary, size: 12)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (friends.isEmpty)
                    Text(
                      'Add a friend first, then you can send them bites.',
                      style: AppType.body(color: TrackerColors.textSecondary),
                    )
                  else
                    for (final p in friends) _Choice(person: p, selected: _selected.contains(p.userId), onTap: () => _toggle(p)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + (bottom > 0 ? 0 : 8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: AppMotion.quick,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_error!, style: AppType.caption(color: TrackerColors.warning, size: 12.5)),
                          ),
                  ),
                  AppButton(
                    label: _label,
                    icon: CupertinoIcons.paperplane_fill,
                    loading: _sending,
                    onPressed: _selected.isEmpty && !_story ? null : _send,
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

/// "Your story": every friend can see it for 24 hours.
class _StoryChoice extends StatelessWidget {
  const _StoryChoice({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        key: const ValueKey('story_choice'),
        onTap: onTap,
        borderRadius: AppRadii.buttonAll,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.12) : TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            border: Border.all(
              color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.5) : TrackerColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: TrackerColors.calorieGradient),
                child: Icon(CupertinoIcons.person_2_fill, size: 16, color: TrackerColors.onAccent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your story', style: AppType.body(size: 15)),
                    Text(
                      'All your friends can see it for 24 hours',
                      style: AppType.caption(color: TrackerColors.textTertiary, size: 11.5),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                size: 22,
                color: selected ? TrackerColors.accentStart : TrackerColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.person, required this.selected, required this.onTap});

  final Person person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.buttonAll,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.12) : TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            border: Border.all(
              color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.5) : TrackerColors.border,
            ),
          ),
          child: Row(
            children: [
              FriendAvatar(username: person.username, size: 36, imageUrl: person.avatarUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('@${person.username}', style: AppType.body(size: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (person.streak > 0) ...[
                StreakBadge(count: person.streak, lit: person.sentToday && person.theySentToday),
                const SizedBox(width: 10),
              ],
              Icon(
                selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                size: 22,
                color: selected ? TrackerColors.accentStart : TrackerColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
