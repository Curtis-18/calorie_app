import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../providers/scan_queue_provider.dart';
import '../services/voice_note.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';

/// "Anything to add?": say or type what the photo can't show ("half of this,
/// cooked in butter, with a diet soda"). Returns the note, or null if skipped.
Future<String?> showScanNoteSheet(
  BuildContext context, {
  VoiceRecognizer? recognizer,
  String? initial,
}) {
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (_) => _ScanNoteSheet(recognizer: recognizer ?? DeviceVoiceRecognizer(), initial: initial),
  );
}

class _ScanNoteSheet extends StatefulWidget {
  const _ScanNoteSheet({required this.recognizer, this.initial});

  final VoiceRecognizer recognizer;
  final String? initial;

  @override
  State<_ScanNoteSheet> createState() => _ScanNoteSheetState();
}

class _ScanNoteSheetState extends State<_ScanNoteSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.initial ?? '');
  bool _canListen = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    widget.recognizer.available().then((ok) {
      if (mounted) setState(() => _canListen = ok);
    });
  }

  @override
  void dispose() {
    widget.recognizer.stop();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    HapticFeedback.selectionClick();
    if (_listening) {
      await widget.recognizer.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await widget.recognizer.listen((words, done) {
      if (!mounted) return;
      setState(() {
        _text.text = words;
        _text.selection = TextSelection.collapsed(offset: words.length);
        if (done) _listening = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    return Container(
      color: TrackerColors.background,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + inset),
      child: DefaultTextStyle(
        style: AppType.body(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anything to add?', style: AppType.title()),
            const SizedBox(height: 4),
            Text(
              'Say or type what the photo can’t show, like “half of this, cooked in butter”. We’ll scan it again with your note.',
              style: AppType.callout(size: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    key: const ValueKey('scan_note_field'),
                    controller: _text,
                    maxLength: ScanQueueNotifier.maxNoteLength,
                    maxLines: 3,
                    minLines: 1,
                    placeholder: 'Half of this, with a diet soda…',
                    style: AppType.body(size: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TrackerColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TrackerColors.border),
                    ),
                  ),
                ),
                if (_canListen) ...[
                  const SizedBox(width: 10),
                  CupertinoButton(
                    key: const ValueKey('scan_note_mic'),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    onPressed: _toggleMic,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _listening ? null : TrackerColors.calorieGradient,
                        color: _listening ? TrackerColors.error : null,
                      ),
                      child: Icon(
                        _listening ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                        color: TrackerColors.onAccent,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_listening)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Listening…', style: AppType.caption(size: 12)),
              ),
            const SizedBox(height: 14),
            AppButton(
              key: const ValueKey('scan_note_apply'),
              label: 'Scan again with this note',
              onPressed: () {
                final text = _text.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
            ),
            const SizedBox(height: 4),
            Center(
              child: CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Not now', style: AppType.callout(color: TrackerColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
