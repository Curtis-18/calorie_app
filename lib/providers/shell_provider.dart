import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bottom tabs, in order.
enum ShellTab { today, insights, friends, recipes, profile }

/// The selected bottom tab. Written by the tab bar; anything else may set it
/// to move the person to another tab (Settings does, to replay the tutorial).
final shellTabProvider = StateProvider<ShellTab>((ref) => ShellTab.today);

/// Bumped each time someone asks to see the tutorial again. The Today screen
/// listens and starts the tour.
final tourReplayProvider = StateProvider<int>((ref) => 0);
