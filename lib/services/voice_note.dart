import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// Turns speech into text on the phone. Nothing is recorded or uploaded by the
/// app: only the resulting words are ever sent (as the note on a scan).
abstract class VoiceRecognizer {
  /// Whether this device can listen (permission granted, a recogniser exists).
  /// False in many browsers, which hides the mic.
  Future<bool> available();

  /// Start listening. [onText] gets the words so far, and `done` true at the end.
  Future<void> listen(void Function(String text, bool done) onText);

  Future<void> stop();
}

class DeviceVoiceRecognizer implements VoiceRecognizer {
  final SpeechToText _speech = SpeechToText();
  bool? _ready;

  @override
  Future<bool> available() async {
    try {
      return _ready ??= await _speech.initialize();
    } catch (_) {
      return _ready = false;
    }
  }

  @override
  Future<void> listen(void Function(String text, bool done) onText) async {
    if (!await available()) return;
    await _speech.listen(
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
