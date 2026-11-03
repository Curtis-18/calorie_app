import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/share_card.dart';
import '../../providers/progress_provider.dart';
import '../../providers/weight_provider.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../app_button.dart';
import '../app_dialog.dart';
import '../glass.dart';
import 'share_card.dart';

/// Hands the image to the platform. Swappable in tests.
typedef ShareHandler = Future<ShareResult> Function(ShareParams params);

Future<ShareResult> _platformShare(ShareParams params) => SharePlus.instance.share(params);

/// Preview the progress card and share it through the native share sheet
/// (Web Share on supporting browsers, otherwise the PNG is downloaded).
///
/// [includeWeight] only pre-selects the weight toggle; the user sees the
/// preview and can switch it off before anything leaves the device.
Future<void> showShareProgressSheet(
  BuildContext context, {
  bool includeWeight = false,
  ShareHandler share = _platformShare,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => AppSheet(
      child: ShareProgressSheet(initialIncludeWeight: includeWeight, share: share),
    ),
  );
}

class ShareProgressSheet extends ConsumerStatefulWidget {
  const ShareProgressSheet({super.key, this.initialIncludeWeight = false, this.share = _platformShare});

  final bool initialIncludeWeight;
  final ShareHandler share;

  @override
  ConsumerState<ShareProgressSheet> createState() => _ShareProgressSheetState();
}

class _ShareProgressSheetState extends ConsumerState<ShareProgressSheet> {
  static const _fileName = 'calorie-tracker-progress.png';

  final _cardKey = GlobalKey();
  final _buttonKey = GlobalKey();
  late bool _includeWeight = widget.initialIncludeWeight;
  bool _sharing = false;

  // The PNG is rendered ahead of the tap: browsers only allow Web Share
  // during a user gesture, and rendering after the tap can outlast it.
  Future<Uint8List>? _png;
  String? _pngSignature;

  String _signature(ShareCardData d) =>
      '${d.date}|${d.streakDays}|${d.bestStreak}|${d.level}|${d.totalXp}|${d.badgeCount}|${d.weightChange}';

  void _scheduleCapture(ShareCardData data) {
    final signature = _signature(data);
    if (signature == _pngSignature) return;
    _pngSignature = signature;
    final completer = Completer<Uint8List>();
    _png = completer.future..ignore();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        completer.complete(await _capture());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
  }

  Future<Uint8List> _capture() async {
    try {
      await GoogleFonts.pendingFonts();
    } catch (_) {
      // Offline: the fallback font is fine for the card.
    }
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('The card is not on screen.');
    final image = await boundary.toImage(pixelRatio: ProgressShareCard.pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not encode the card.');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _share(ShareCardData data) async {
    setState(() => _sharing = true);
    try {
      Uint8List png;
      try {
        png = await (_png ?? _capture());
      } catch (_) {
        png = await _capture(); // The early render failed; try once more now.
      }
      final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
      final result = await widget.share(
        ShareParams(
          files: [XFile.fromData(png, mimeType: 'image/png', name: _fileName)],
          fileNameOverrides: const [_fileName],
          text: data.shareText,
          // iPad anchors its share popover here.
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
      } else if (kIsWeb && result.status == ShareResultStatus.unavailable) {
        // No Web Share in this browser: share_plus downloaded the image.
        await showAppDialog(
          context: context,
          title: 'Card saved',
          message: 'Your progress card was downloaded as an image, ready to post anywhere.',
          confirmLabel: 'Got it',
        );
      }
    } catch (_) {
      if (mounted) {
        await showAppDialog(
          context: context,
          title: "Couldn't share",
          message: 'Something went wrong preparing your card. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final weight = ref.watch(weightProvider).value;
    final unit = ref.watch(weightUnitProvider);

    if (progress == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: PulsingRing(size: 40, strokeWidth: 4)),
      );
    }

    final canShareWeight = ShareCardData.canShareWeight(weight);
    final data = ShareCardData.from(progress: progress, weight: weight, includeWeight: _includeWeight, unit: unit);
    _scheduleCapture(data);

    final screen = MediaQuery.sizeOf(context);
    final previewHeight = math.min(460.0, math.max(280.0, screen.height * 0.5));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Share progress', style: AppType.title()),
        const SizedBox(height: 4),
        Text('Your streak, level and badges. No calorie numbers.', style: AppType.callout()),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: SizedBox(
            height: previewHeight,
            child: FittedBox(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: TrackerColors.borderStrong),
                  boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 30, opacity: 0.18),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: ProgressShareCard(data: data),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (canShareWeight) ...[
          _WeightToggle(value: _includeWeight, onChanged: (v) => setState(() => _includeWeight = v)),
          const SizedBox(height: AppSpacing.lg),
        ],
        KeyedSubtree(
          key: _buttonKey,
          child: AppButton(
            label: 'Share',
            icon: CupertinoIcons.share,
            loading: _sharing,
            onPressed: _sharing ? null : () => _share(data),
          ),
        ),
      ],
    );
  }
}

class _WeightToggle extends StatelessWidget {
  const _WeightToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: TrackerColors.surfaceElevated,
        borderRadius: AppRadii.buttonAll,
        border: Border.all(color: TrackerColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Include weight change', style: AppType.headline().copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  'Shows only how much your trend changed, never your weight.',
                  style: AppType.caption(color: TrackerColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoSwitch(value: value, activeTrackColor: TrackerColors.accentEnd, onChanged: onChanged),
        ],
      ),
    );
  }
}
