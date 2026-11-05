import 'dart:typed_data';

import 'package:calorie_app/models/bite_meal.dart';
import 'package:calorie_app/screens/bite_camera_screen.dart';
import 'package:calorie_app/services/bite_stamp.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _jpeg(int w, int h, {int gray = 128}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(gray, gray, gray));
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

void main() {
  group('BiteMeal.forHour', () {
    test('picks the likely meal', () {
      expect(BiteMeal.forHour(8), BiteMeal.breakfast);
      expect(BiteMeal.forHour(12), BiteMeal.lunch);
      expect(BiteMeal.forHour(16), BiteMeal.snack);
      expect(BiteMeal.forHour(19), BiteMeal.dinner);
      expect(BiteMeal.forHour(23), BiteMeal.snack);
      expect(BiteMeal.forHour(3), BiteMeal.snack);
    });
  });

  group('prepareBite', () {
    testWidgets('crops to 4:5 at 1080 wide and returns a JPEG', (tester) async {
      final out = await tester.runAsync(() => prepareBite(_jpeg(1600, 1200), null));
      final im = img.decodeJpg(out!)!;
      expect(im.width, biteWidth);
      expect(im.height, biteHeight);
      expect(out.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
    });

    testWidgets('a meal stamp darkens the bottom-left corner only', (tester) async {
      final plain = img.decodeJpg((await tester.runAsync(() => prepareBite(_jpeg(1080, 1350, gray: 220), null)))!)!;
      final stamped =
          img.decodeJpg((await tester.runAsync(() => prepareBite(_jpeg(1080, 1350, gray: 220), BiteMeal.lunch)))!)!;
      // Inside the pill, near its left end.
      final inPill = stamped.getPixel(80, biteHeight - 90).r;
      expect(inPill, lessThan(plain.getPixel(80, biteHeight - 90).r - 40));
      // The opposite corner is untouched.
      expect((stamped.getPixel(biteWidth - 40, 40).r - plain.getPixel(biteWidth - 40, 40).r).abs(), lessThan(4));
    });

    testWidgets('rejects bytes that are not an image', (tester) async {
      await tester.runAsync(() async {
        await expectLater(prepareBite(Uint8List.fromList([1, 2, 3]), null), throwsA(anything));
      });
    });
  });

  group('BiteCameraScreen', () {
    Future<BiteCameraResult?> open(WidgetTester tester, {DateTime? now, Uint8List? shot}) async {
      BiteCameraResult? result;
      var done = false;
      await tester.pumpWidget(
        CupertinoApp(
          theme: AppTheme.cupertino,
          home: Builder(
            builder: (context) => CupertinoButton(
              key: const ValueKey('open'),
              onPressed: () async {
                result = await Navigator.of(context).push<BiteCameraResult>(
                  CupertinoPageRoute(
                    builder: (_) => BiteCameraScreen(
                      debugPreview: const ColoredBox(color: Color(0xFF336699)),
                      debugShoot: () async => shot ?? _jpeg(1200, 1600),
                      now: () => now ?? DateTime(2026, 11, 5, 13),
                    ),
                  ),
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(done, isFalse);
      return result;
    }

    testWidgets('shows the plate hint and the right meal for the time of day', (tester) async {
      await open(tester, now: DateTime(2026, 11, 5, 19));
      expect(find.byKey(const ValueKey('plate_hint')), findsOneWidget);
      expect(find.byKey(const ValueKey('stamp_preview')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('stamp_preview')), matching: find.text('Dinner')), findsOneWidget);
    });

    testWidgets('picking another meal changes the stamp, tapping it again removes it', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('meal_breakfast')));
      await tester.pump();
      expect(find.descendant(of: find.byKey(const ValueKey('stamp_preview')), matching: find.text('Breakfast')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meal_breakfast')));
      await tester.pump();
      expect(find.byKey(const ValueKey('stamp_preview')), findsNothing);
    });

    testWidgets('the shutter returns a finished 4:5 bite', (tester) async {
      BiteCameraResult? got;
      await tester.pumpWidget(
        CupertinoApp(
          theme: AppTheme.cupertino,
          home: Builder(
            builder: (context) => CupertinoButton(
              key: const ValueKey('open'),
              onPressed: () async {
                got = await Navigator.of(context).push<BiteCameraResult>(
                  CupertinoPageRoute(
                    builder: (_) => BiteCameraScreen(
                      debugPreview: const SizedBox(),
                      debugShoot: () async => _jpeg(1200, 1600),
                      now: () => DateTime(2026, 11, 5, 13),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('shutter')));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
      expect(got?.bytes, isNotNull);
      expect(got!.unavailable, isFalse);
      final im = img.decodeJpg(got!.bytes!)!;
      expect((im.width, im.height), (biteWidth, biteHeight));
    });

    testWidgets('closing returns nothing', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        CupertinoApp(
          theme: AppTheme.cupertino,
          home: Builder(
            builder: (context) => CupertinoButton(
              key: const ValueKey('open'),
              onPressed: () async {
                final r = await Navigator.of(context).push<BiteCameraResult>(
                  CupertinoPageRoute(builder: (_) => const BiteCameraScreen(debugPreview: SizedBox())),
                );
                closed = r == null;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('camera_close')));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });
  });
}
