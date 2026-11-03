import 'dart:math' as math;

import 'package:calorie_app/models/appearance.dart';
import 'package:calorie_app/providers/appearance_provider.dart';
import 'package:calorie_app/theme/tracker_colors.dart';
import 'package:calorie_app/widgets/appearance_picker.dart';
import 'package:calorie_app/widgets/theme_host.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  tearDown(() => TrackerColors.apply(Brightness.dark));

  group('light palette contrast (WCAG AA)', () {
    const p = TrackerPalette.light;
    final grounds = {'background': p.background, 'card': p.surface, 'well': p.surfaceElevated};

    for (final g in grounds.entries) {
      test('text on ${g.key}', () {
        expect(_contrast(p.textPrimary, g.value), greaterThanOrEqualTo(7));
        expect(_contrast(p.textSecondary, g.value), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.textTertiary, g.value), greaterThanOrEqualTo(4.5));
      });
      test('ink colours on ${g.key}', () {
        for (final c in [p.accentStartText, p.accentEndText, p.macroProtein, p.macroCarbs, p.macroFat, p.error, p.freeze]) {
          expect(_contrast(c, g.value), greaterThanOrEqualTo(4.5), reason: '$c on ${g.key}');
        }
      });
    }

    test('white on the brand gradient stays legible for large text and icons', () {
      expect(_contrast(TrackerColors.onAccent, TrackerColors.accentStart), greaterThanOrEqualTo(3));
    });
  });

  group('appearance mode', () {
    test('resolves against the device setting', () {
      expect(AppearanceMode.system.resolve(Brightness.light), Brightness.light);
      expect(AppearanceMode.system.resolve(Brightness.dark), Brightness.dark);
      expect(AppearanceMode.light.resolve(Brightness.dark), Brightness.light);
      expect(AppearanceMode.dark.resolve(Brightness.light), Brightness.dark);
    });

    test('unknown or missing saved values fall back to dark', () {
      expect(AppearanceMode.fromName(null), AppearanceMode.dark);
      expect(AppearanceMode.fromName('neon'), AppearanceMode.dark);
      expect(AppearanceMode.fromName('light'), AppearanceMode.light);
    });

    test('the choice is saved and reloaded', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AppearanceNotifier.load(), AppearanceMode.dark);
      await AppearanceNotifier().set(AppearanceMode.light);
      expect(await AppearanceNotifier.load(), AppearanceMode.light);
    });

    test('apply reports whether anything changed and bumps the repaint epoch', () {
      final start = TrackerColors.paletteEpoch;
      expect(TrackerColors.apply(Brightness.dark), isFalse);
      expect(TrackerColors.paletteEpoch, start);
      expect(TrackerColors.apply(Brightness.light), isTrue);
      expect(TrackerColors.paletteEpoch, start + 1);
      expect(TrackerColors.background, TrackerPalette.light.background);
    });
  });

  group('switching live', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('picking Light repaints widgets already on screen, even const ones', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: ThemeHost(
          builder: (context, theme) => CupertinoApp(
            theme: theme,
            home: const CupertinoPageScaffold(
              child: Column(children: [AppearancePicker(), _Swatch()]),
            ),
          ),
        ),
      ));

      Color swatch() => (tester.widget<ColoredBox>(find.byKey(const Key('swatch'))).color);
      expect(swatch(), TrackerPalette.dark.surface);

      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(container.read(appearanceProvider), AppearanceMode.light);
      expect(swatch(), TrackerPalette.light.surface);

      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(swatch(), TrackerPalette.dark.surface);
    });

    testWidgets('Auto follows the device live', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final container = ProviderContainer(
        overrides: [appearanceProvider.overrideWith((ref) => AppearanceNotifier(AppearanceMode.system))],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: ThemeHost(builder: (context, theme) => CupertinoApp(theme: theme, home: const _Swatch())),
      ));
      expect(TrackerColors.isDark, isTrue);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();
      expect(TrackerColors.isDark, isFalse);
    });
  });
}

/// A const widget: it only updates if the host forces a rebuild.
class _Swatch extends StatelessWidget {
  const _Swatch();

  @override
  Widget build(BuildContext context) => ColoredBox(key: const Key('swatch'), color: TrackerColors.surface, child: const SizedBox(height: 10, width: 10));
}
