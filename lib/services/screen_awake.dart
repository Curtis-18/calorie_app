import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen from dimming and locking, for as long as something that is
/// being watched or followed hands-free (a workout) is on screen. Always
/// paired: whoever calls [keepOn] calls [release] when they are done.
abstract class ScreenAwake {
  Future<void> keepOn();
  Future<void> release();
}

/// The real thing: iPhone, Android and browsers that support it. Never throws:
/// a device that cannot do it simply lets the screen dim as before.
class WakelockScreenAwake implements ScreenAwake {
  @override
  Future<void> keepOn() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  @override
  Future<void> release() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}

final screenAwakeProvider = Provider<ScreenAwake>((ref) => WakelockScreenAwake());
