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

/// The photo you just took, a caption, and who gets it. Pops with the
/// per-friend streak results once sent.
class SnapComposeScreen extends ConsumerStatefulWidget {
  const SnapComposeScreen({super.key, required this.image, this.service, this.preselect});

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
    if (_sending || _selected.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final results = await _service.send(
        id: _snapId,
        image: widget.image,
        recipientIds: _selected.toList(),
        caption: _caption.text,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop<List<SendOutcome>>(results);
    } on SnapsException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).valueOrNull?.friends ?? const <Person>[];
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: TrackerColors.navFill,
        middle: Text('Send a snap', style: AppType.headline()),
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
                  Text('Send to', style: AppType.caption(color: TrackerColors.textTertiary, size: 12)),
                  const SizedBox(height: AppSpacing.sm),
                  if (friends.isEmpty)
                    Text(
                      'Add a friend first, then you can send them snaps.',
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
                    label: _selected.isEmpty
                        ? 'Pick who gets it'
                        : 'Send to ${_selected.length} ${_selected.length == 1 ? 'friend' : 'friends'}',
                    icon: CupertinoIcons.paperplane_fill,
                    loading: _sending,
                    onPressed: _selected.isEmpty ? null : _send,
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
              FriendAvatar(username: person.username, size: 36),
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
