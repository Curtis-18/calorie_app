import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/barcode.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../l10n/app_strings.dart';

/// Point the camera at a barcode; pops with the digits of the first valid one.
/// Typing the number is always offered too: a browser or a denied camera
/// permission would otherwise leave no way in.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, this.previewBuilder});

  /// Replaces the live camera in tests. Call `onCode` with what was "seen".
  @visibleForTesting
  final Widget Function(BuildContext context, void Function(String raw) onCode)? previewBuilder;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.previewBuilder == null) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _found(String raw) {
    if (_done) return;
    final code = normalizeBarcode(raw);
    if (code == null) return; // keep looking
    _done = true;
    Navigator.of(context).pop(code);
  }

  Future<void> _typeIt() async {
    final text = TextEditingController();
    final typed = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(tr('Type the barcode number')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const ValueKey('barcode_number'),
            controller: text,
            keyboardType: TextInputType.number,
            autofocus: true,
            placeholder: tr('The digits under the bars'),
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, text.text),
            child: Text(tr('Look up')),
          ),
        ],
      ),
    );
    text.dispose();
    if (typed == null || !mounted) return;
    if (normalizeBarcode(typed) == null) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(tr("That doesn't look like a barcode")),
          content: Text(tr('Barcodes are 8 to 14 digits long.')),
          actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    _found(typed);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(middle: Text(tr('Scan a barcode'))),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.previewBuilder != null)
            widget.previewBuilder!(context, _found)
          else
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null) _found(raw);
                }
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    tr("The camera isn't available. You can type the number instead."),
                    textAlign: TextAlign.center,
                    style: AppType.body(color: const Color(0xFFFFFFFF)),
                  ),
                ),
              ),
            ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: TrackerColors.accentStart, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: bottomInset + 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('Fit the barcode inside the frame'),
                  style: AppType.callout(color: const Color(0xFFFFFFFF)),
                ),
                const SizedBox(height: 12),
                AppButton.glass(
                  key: const ValueKey('type_barcode'),
                  label: tr('Type the number instead'),
                  icon: CupertinoIcons.keyboard,
                  onPressed: _typeIt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
