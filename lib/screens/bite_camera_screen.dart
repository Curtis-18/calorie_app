import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/bite_meal.dart';
import '../services/bite_stamp.dart';
import '../theme/app_typography.dart';
import '../widgets/pressable.dart';

/// What the camera hands back: the finished bite, or a note that the live
/// camera couldn't start (so the caller can fall back to the system camera).
class BiteCameraResult {
  const BiteCameraResult.photo(Uint8List this.bytes) : unavailable = false;
  const BiteCameraResult.unavailable() : bytes = null, unavailable = true;

  final Uint8List? bytes;
  final bool unavailable;
}

/// A camera made for food: a plate guide to line the meal up in, and a meal
/// label that gets stamped onto the photo. Everything on screen is what ends
/// up in the bite (4:5 frame, the stamp where you see it).
class BiteCameraScreen extends StatefulWidget {
  const BiteCameraScreen({super.key, this.debugPreview, this.debugShoot, this.now});

  /// Test hooks: stand-ins for the live preview and the shutter.
  final Widget? debugPreview;
  final Future<Uint8List> Function()? debugShoot;
  final DateTime Function()? now;

  @override
  State<BiteCameraScreen> createState() => _BiteCameraScreenState();
}

class _BiteCameraScreenState extends State<BiteCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _flash = false;
  bool _shooting = false;
  late BiteMeal? _meal = BiteMeal.forHour((widget.now ?? DateTime.now)().hour);

  bool get _ready => widget.debugPreview != null || (_controller?.value.isInitialized ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.debugPreview == null) _start();
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw CameraException('none', 'No camera');
      _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _open();
    } catch (_) {
      if (mounted) Navigator.of(context).pop(const BiteCameraResult.unavailable());
    }
  }

  Future<void> _open() async {
    final old = _controller;
    final c = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = c;
    await old?.dispose();
    await c.initialize();
    await c.setFlashMode(_flash ? FlashMode.auto : FlashMode.off).catchError((_) {});
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && _controller == null && _cameras.isNotEmpty) {
      _open().catchError((_) {
        if (mounted) Navigator.of(context).pop(const BiteCameraResult.unavailable());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _shooting) return;
    HapticFeedback.selectionClick();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() {});
    try {
      await _open();
    } catch (_) {
      if (mounted) Navigator.of(context).pop(const BiteCameraResult.unavailable());
    }
  }

  Future<void> _toggleFlash() async {
    HapticFeedback.selectionClick();
    setState(() => _flash = !_flash);
    await _controller?.setFlashMode(_flash ? FlashMode.auto : FlashMode.off).catchError((_) {});
  }

  Future<void> _shoot() async {
    if (_shooting || !_ready) return;
    setState(() => _shooting = true);
    HapticFeedback.mediumImpact();
    try {
      final raw = widget.debugShoot != null ? await widget.debugShoot!() : await (await _controller!.takePicture()).readAsBytes();
      final bite = await prepareBite(raw, _meal);
      if (mounted) Navigator.of(context).pop(BiteCameraResult.photo(bite));
    } catch (_) {
      if (mounted) {
        setState(() => _shooting = false);
        Navigator.of(context).pop(const BiteCameraResult.unavailable());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: pad.top + 56,
            left: 0,
            right: 0,
            child: AspectRatio(
              aspectRatio: biteWidth / biteHeight,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: const Color(0xFF111111), child: _ready ? _preview() : null),
                    const IgnorePointer(child: CustomPaint(painter: PlateGuidePainter())),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 14,
                      child: Text(
                        'Fit your plate in the circle',
                        key: const ValueKey('plate_hint'),
                        textAlign: TextAlign.center,
                        style: AppType.caption(color: const Color(0xE6FFFFFF), size: 13),
                      ),
                    ),
                    if (_meal != null)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, box) => Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: EdgeInsets.all(box.maxWidth * 0.05),
                              child: _StampPreview(label: _meal!.label, scale: box.maxWidth / biteWidth),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: pad.top + 6,
            left: 8,
            right: 8,
            child: Row(
              children: [
                _RoundButton(
                  key: const ValueKey('camera_close'),
                  icon: CupertinoIcons.xmark,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _RoundButton(
                  key: const ValueKey('camera_flash'),
                  icon: _flash ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash,
                  onTap: _toggleFlash,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: pad.bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final m in BiteMeal.values)
                        _MealChip(
                          meal: m,
                          selected: _meal == m,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            // Tapping the chosen one again takes the label off.
                            setState(() => _meal = _meal == m ? null : m);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 56),
                    Pressable(
                      key: const ValueKey('shutter'),
                      onTap: _shoot,
                      child: Container(
                        width: 78,
                        height: 78,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFFFFF), width: 4),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _shooting ? const Color(0x88FFFFFF) : const Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: _cameras.length > 1
                          ? _RoundButton(
                              key: const ValueKey('camera_flip'),
                              icon: CupertinoIcons.camera_rotate,
                              onTap: _flip,
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (widget.debugPreview != null) return widget.debugPreview!;
    final c = _controller!;
    final size = c.value.previewSize;
    final w = size == null ? 3.0 : (size.width < size.height ? size.width : size.height);
    final h = size == null ? 4.0 : (size.width < size.height ? size.height : size.width);
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: w, height: h, child: CameraPreview(c)),
    );
  }
}

/// Dims everything outside a plate-sized circle, so the meal gets centred and
/// filled in. Public so it can be tested on its own.
class PlateGuidePainter extends CustomPainter {
  const PlateGuidePainter();

  /// The circle's diameter as a share of the frame width.
  static const diameterShare = 0.78;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.5);
    final radius = size.width * diameterShare / 2;
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: centre, radius: radius));
    canvas.drawPath(scrim, Paint()..color = const Color(0x55000000));
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xCCFFFFFF),
    );
  }

  @override
  bool shouldRepaint(PlateGuidePainter oldDelegate) => false;
}

/// How the stamp will look on the photo (the real one is drawn in
/// [prepareBite]), scaled for the on-screen frame.
class _StampPreview extends StatelessWidget {
  const _StampPreview({required this.label, required this.scale});
  final String label;

  /// Screen pixels per photo pixel.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('stamp_preview'),
      padding: EdgeInsets.symmetric(horizontal: 30 * scale, vertical: 18 * scale),
      decoration: BoxDecoration(color: const Color(0xA6000000), borderRadius: BorderRadius.circular(60 * scale)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16 * scale,
            height: 16 * scale,
            decoration: const BoxDecoration(color: Color(0xFF7CF542), shape: BoxShape.circle),
          ),
          SizedBox(width: 14 * scale),
          Text(label, style: AppType.caption(color: const Color(0xFFFFFFFF), size: 46 * scale)),
        ],
      ),
    );
  }
}

class _MealChip extends StatelessWidget {
  const _MealChip({required this.meal, required this.selected, required this.onTap});

  final BiteMeal meal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        key: ValueKey('meal_${meal.name}'),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFFFFF) : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            meal.label,
            style: AppType.caption(color: selected ? const Color(0xFF000000) : const Color(0xFFFFFFFF), size: 14),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x55000000)),
        child: Icon(icon, color: const Color(0xFFFFFFFF), size: 20),
      ),
    );
  }
}
