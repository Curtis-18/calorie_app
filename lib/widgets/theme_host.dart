import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appearance.dart';
import '../providers/appearance_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tracker_colors.dart';

/// Applies the user's appearance choice to the whole app.
///
/// Colours come from [TrackerColors], which reads a global palette when each
/// widget builds, so a change of mode must make *every* widget build again,
/// including ones whose configuration didn't change (const widgets, anything
/// cached by an ancestor). The same trick hot reload uses: mark every element
/// dirty. Navigation, scroll positions and form state are untouched.
///
/// Also follows the device setting live when the choice is [AppearanceMode.system],
/// and keeps the status bar icons readable.
class ThemeHost extends ConsumerStatefulWidget {
  const ThemeHost({super.key, required this.builder});

  /// Builds the app (a `CupertinoApp`) with the right theme.
  final Widget Function(BuildContext context, CupertinoThemeData theme) builder;

  @override
  ConsumerState<ThemeHost> createState() => _ThemeHostState();
}

class _ThemeHostState extends ConsumerState<ThemeHost> with WidgetsBindingObserver {
  late Brightness _device = WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final now = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (now != _device) setState(() => _device = now);
  }

  static void _markAllDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markAllDirty);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appearanceProvider);
    final target = mode.resolve(_device);

    if (TrackerColors.apply(target)) {
      // Everything already on screen was built with the old colours.
      (context as Element).visitChildren(_markAllDirty);
    }
    _syncSystemBars(target);

    return widget.builder(context, AppTheme.cupertino);
  }

  /// Status bar icons dark on light backgrounds and vice versa.
  static void _syncSystemBars(Brightness brightness) {
    final onDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: onDark ? Brightness.light : Brightness.dark, // Android
      statusBarBrightness: onDark ? Brightness.dark : Brightness.light, // iOS (inverted)
      systemNavigationBarColor: TrackerColors.background,
      systemNavigationBarIconBrightness: onDark ? Brightness.light : Brightness.dark,
    ));
  }
}
