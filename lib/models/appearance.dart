import 'package:flutter/cupertino.dart';

/// How the user wants the app to look. [system] follows the device.
enum AppearanceMode {
  system('Auto', 'Matches your device', CupertinoIcons.device_phone_portrait),
  light('Light', 'Bright and clean', CupertinoIcons.sun_max_fill),
  dark('Dark', 'Easy on the eyes', CupertinoIcons.moon_fill);

  const AppearanceMode(this.label, this.blurb, this.icon);

  final String label;
  final String blurb;
  final IconData icon;

  /// The brightness to show, given what the device is set to.
  Brightness resolve(Brightness device) => switch (this) {
        AppearanceMode.system => device,
        AppearanceMode.light => Brightness.light,
        AppearanceMode.dark => Brightness.dark,
      };

  static AppearanceMode fromName(String? name) => values.asNameMap()[name] ?? defaultMode;

  /// What people get until they choose: the app's original dark look.
  static const defaultMode = AppearanceMode.dark;
}
