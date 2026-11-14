import 'package:flutter/cupertino.dart';

import '../../models/snaps.dart';
import '../../services/snaps_service.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../app_dialog.dart';
import '../glass.dart';
import '../pressable.dart';
import '../shimmer.dart';

/// The bites you sent in the last 24 hours: who has opened each one, how they
/// reacted, and a way to take one back.
Future<void> showSentBitesSheet(BuildContext context, SnapsService service) {
  return showAppSheet<void>(context: context, builder: (_) => AppSheet(child: SentBitesSheet(service: service)));
}

class SentBitesSheet extends StatefulWidget {
  const SentBitesSheet({super.key, required this.service});

  final SnapsService service;

  @override
  State<SentBitesSheet> createState() => _SentBitesSheetState();
}

class _SentBitesSheetState extends State<SentBitesSheet> {
  List<SentSnap>? _sent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sent = await widget.service.sent();
      if (mounted) {
        setState(() {
          _sent = sent;
          _error = null;
        });
      }
    } on SnapsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _takeBack(SentSnap snap) async {
    final sure = await showAppDialog(
      context: context,
      title: 'Take this bite back?',
      message: "Your friends won't be able to see it any more. Today still counts toward your streaks.",
      confirmLabel: 'Take back',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (sure != true || !mounted) return;
    try {
      await widget.service.delete(snap.id);
      if (mounted) setState(() => _sent = _sent?.where((s) => s.id != snap.id).toList());
    } on SnapsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bites you sent', style: AppType.title()),
          const SizedBox(height: AppSpacing.sm),
          Text('From the last 24 hours. After that they disappear for everyone.', style: AppType.callout()),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null) ...[
            Text(_error!, style: AppType.caption(color: TrackerColors.warning, size: 13)),
            const SizedBox(height: AppSpacing.md),
          ],
          if (sent == null && _error == null)
            const SkeletonRows(count: 2)
          else if (sent != null && sent.isEmpty)
            Text(
              "You haven't sent a bite in the last 24 hours.",
              style: AppType.body(color: TrackerColors.textSecondary),
            )
          else
            for (final snap in sent ?? const <SentSnap>[]) _SentRow(snap: snap, onTakeBack: () => _takeBack(snap)),
        ],
      ),
    );
  }
}

/// "Seen by 2 of 3", or the single friend's name when there is only one.
String sentStatus(SentSnap snap) {
  final total = snap.recipients.length;
  final seen = snap.recipients.where((r) => r.viewed).length;
  if (total == 1) {
    final name = '@${snap.recipients.first.username}';
    return seen == 1 ? 'Seen by $name' : 'Sent to $name · not opened yet';
  }
  return seen == 0 ? 'Sent to $total friends · not opened yet' : 'Seen by $seen of $total';
}

class _SentRow extends StatelessWidget {
  const _SentRow({required this.snap, required this.onTakeBack});

  final SentSnap snap;
  final VoidCallback onTakeBack;

  @override
  Widget build(BuildContext context) {
    final reactions = snap.recipients.where((r) => r.reaction != null).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: AppDecor.card(borderRadius: AppRadii.buttonAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadii.smallAll,
              child: SizedBox(
                width: 56,
                height: 70,
                child: snap.imageUrl == null
                    ? _placeholder()
                    : Image.network(snap.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder()),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(biteSentLabel(snap.createdAt), style: AppType.caption(color: TrackerColors.textTertiary, size: 11)),
                  const SizedBox(height: 2),
                  Text(sentStatus(snap), style: AppType.body(size: 14)),
                  if (snap.caption != null && snap.caption!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      snap.caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption(color: TrackerColors.textSecondary, size: 12),
                    ),
                  ],
                  if (reactions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final r in reactions)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: TrackerColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              border: Border.all(color: TrackerColors.border),
                            ),
                            child: Text(
                              '${r.reaction} @${r.username}',
                              style: AppType.caption(color: TrackerColors.textSecondary, size: 11.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Take this bite back',
              child: Pressable(
                onTap: onTakeBack,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(CupertinoIcons.delete, size: 16, color: TrackerColors.textTertiary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: TrackerColors.surfaceElevated,
        alignment: Alignment.center,
        child: Icon(CupertinoIcons.photo, size: 18, color: TrackerColors.textTertiary),
      );
}
