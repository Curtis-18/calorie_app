import 'package:flutter/cupertino.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_typography.dart';

const _ink = Color(0xFF111111);
const _white = Color(0xFFFFFFFF);

/// Where a caption sits when its sender did not place it: a little below the
/// middle, as a fraction of the photo's height.
const double defaultCaptionY = 0.62;

/// How far up or down the strip may be dragged, so it never leaves the photo.
const double captionYMin = 0.06;
const double captionYMax = 0.94;

/// The strip a caption is written on: white, the full width of the photo, the
/// words centred on it in dark type.
class CaptionStrip extends StatelessWidget {
  const CaptionStrip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xEBFFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: child,
    );
  }
}

TextStyle get captionTextStyle => AppType.body(size: 18, color: _ink).copyWith(fontWeight: FontWeight.w600, height: 1.25);

/// A caption on a full-screen photo in a viewer (bites and stories), at the
/// height its sender dragged it to ([y], a fraction of the photo's height).
Widget positionedCaption(BuildContext context, String? caption, double? y) {
  if (caption == null || caption.trim().isEmpty) return const SizedBox.shrink();
  final height = MediaQuery.sizeOf(context).height;
  final at = (y ?? defaultCaptionY).clamp(captionYMin, captionYMax);
  return Positioned(
    left: 0,
    right: 0,
    top: height * at,
    child: FractionalTranslation(
      translation: const Offset(0, -0.5),
      child: IgnorePointer(
        child: Semantics(
          label: caption,
          child: CaptionStrip(
            key: const ValueKey('caption_band'),
            child: Text(caption, textAlign: TextAlign.center, style: captionTextStyle),
          ),
        ),
      ),
    ),
  );
}

/// The photo you just took, with the Snapchat way of writing on it: tap the
/// **T**, a white strip appears and you type in it, drag it up or down to where
/// you want it, tap Done. A strip left empty goes away.
///
/// [controller] holds the words and [position] where the strip sits (a fraction
/// of the photo's height); the screen reads both when it sends.
class CaptionedPhoto extends StatefulWidget {
  const CaptionedPhoto({super.key, required this.image, required this.controller, required this.position, this.maxLength = 120});

  final Widget image;
  final TextEditingController controller;
  final ValueNotifier<double> position;
  final int maxLength;

  @override
  State<CaptionedPhoto> createState() => _CaptionedPhotoState();
}

class _CaptionedPhotoState extends State<CaptionedPhoto> {
  final _focus = FocusNode();
  late bool _shown = widget.controller.text.trim().isNotEmpty;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    widget.position.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.position.removeListener(_changed);
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _edit() {
    setState(() {
      _shown = true;
      _editing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _done() {
    _focus.unfocus();
    if (!mounted) return;
    setState(() {
      _editing = false;
      if (widget.controller.text.trim().isEmpty) {
        widget.controller.clear();
        _shown = false;
      }
    });
  }

  void _drag(DragUpdateDetails d, double photoHeight) {
    if (photoHeight <= 0) return;
    widget.position.value = (widget.position.value + d.delta.dy / photoHeight).clamp(captionYMin, captionYMax);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _editing ? _done : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.image,
              if (_editing) const ColoredBox(color: Color(0x55000000)),
              if (_shown)
                Positioned(
                  left: 0,
                  right: 0,
                  top: height * widget.position.value,
                  child: FractionalTranslation(
                    translation: const Offset(0, -0.5),
                    child: GestureDetector(
                      key: const ValueKey('caption_strip'),
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) => _drag(d, height),
                      onTap: _editing ? null : _edit,
                      child: CaptionStrip(
                        child: _editing
                            ? CupertinoTextField(
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
                                cursorColor: _ink,
                                placeholder: tr('Type a caption'),
                                placeholderStyle: AppType.body(size: 18, color: const Color(0x88111111)).copyWith(fontWeight: FontWeight.w600),
                                style: captionTextStyle,
                              )
                            : Text(widget.controller.text, key: const ValueKey('caption_text'), textAlign: TextAlign.center, style: captionTextStyle),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: _editing
                    ? GestureDetector(
                        key: const ValueKey('caption_done'),
                        onTap: _done,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(18)),
                          child: Text(tr('Done'), style: AppType.body(size: 15, color: _white).copyWith(fontWeight: FontWeight.w700)),
                        ),
                      )
                    : Semantics(
                        button: true,
                        label: tr('Add a caption'),
                        child: GestureDetector(
                          key: const ValueKey('caption_t_button'),
                          onTap: _edit,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
                            child: Text('T', style: AppType.body(size: 20, color: _white).copyWith(fontWeight: FontWeight.w800, height: 1)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
