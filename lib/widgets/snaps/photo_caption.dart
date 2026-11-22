import 'package:flutter/cupertino.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_typography.dart';

const _white = Color(0xFFFFFFFF);

/// The words people put on a photo, the way a Snapchat caption looks: a dark
/// strip across the full width of the picture with the words centred in it.
class CaptionBand extends StatelessWidget {
  const CaptionBand(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: Container(
        width: double.infinity,
        color: const Color(0x99000000),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppType.body(size: 18, color: _white).copyWith(fontWeight: FontWeight.w600, height: 1.25),
        ),
      ),
    );
  }
}

/// Where the band sits on a full-screen photo: the lower middle, clear of the
/// buttons at the bottom and the name at the top.
const double captionBandTopFraction = 0.58;

/// A caption on a full-screen photo in a viewer (bites and stories).
Widget positionedCaption(BuildContext context, String? caption) {
  if (caption == null || caption.trim().isEmpty) return const SizedBox.shrink();
  final height = MediaQuery.sizeOf(context).height;
  return Positioned(
    left: 0,
    right: 0,
    top: height * captionBandTopFraction,
    child: IgnorePointer(child: CaptionBand(caption, key: const ValueKey('caption_band'))),
  );
}

/// The photo you just took, with a caption you type straight onto it: tap the
/// picture, type, tap Done. Empty, it shows a small "Tap to add a caption" hint.
class CaptionedPhoto extends StatefulWidget {
  const CaptionedPhoto({super.key, required this.image, required this.controller, this.maxLength = 120});

  final Widget image;
  final TextEditingController controller;
  final int maxLength;

  @override
  State<CaptionedPhoto> createState() => _CaptionedPhotoState();
}

class _CaptionedPhotoState extends State<CaptionedPhoto> {
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _edit() {
    if (_editing) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _done() {
    _focus.unfocus();
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _editing ? _done : _edit,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.image,
          if (_editing) const ColoredBox(color: Color(0x66000000)),
          Align(
            alignment: const Alignment(0, 0.4),
            child: _editing
                ? Container(
                    width: double.infinity,
                    color: const Color(0x99000000),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: CupertinoTextField(
                      key: const ValueKey('caption_field'),
                      controller: widget.controller,
                      focusNode: _focus,
                      maxLength: widget.maxLength,
                      maxLines: 3,
                      minLines: 1,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _done(),
                      padding: EdgeInsets.zero,
                      decoration: null,
                      cursorColor: _white,
                      placeholder: tr('Type a caption'),
                      placeholderStyle: AppType.body(size: 18, color: const Color(0x99FFFFFF)),
                      style: AppType.body(size: 18, color: _white).copyWith(fontWeight: FontWeight.w600, height: 1.25),
                    ),
                  )
                : text.isEmpty
                    ? Container(
                        key: const ValueKey('caption_hint'),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Aa', style: AppType.body(size: 15, color: _white).copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            Text(tr('Tap to add a caption'), style: AppType.body(size: 14, color: _white)),
                          ],
                        ),
                      )
                    : CaptionBand(text, key: const ValueKey('caption_band')),
          ),
          if (_editing)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                key: const ValueKey('caption_done'),
                onTap: _done,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(18)),
                  child: Text(tr('Done'), style: AppType.body(size: 15, color: _white).copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
