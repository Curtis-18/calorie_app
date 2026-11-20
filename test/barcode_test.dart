import 'dart:convert';

import 'package:calorie_app/models/barcode.dart';
import 'package:calorie_app/models/food_item.dart';
import 'package:calorie_app/screens/food_search_screen.dart' show QuantityDialog;
import 'package:calorie_app/providers/display_prefs_provider.dart';
import 'package:calorie_app/screens/barcode_scanner_screen.dart';
import 'package:calorie_app/services/food_search_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('barcode shape', () {
    test('accepts 8 to 14 digits', () {
      for (final ok in ['96385074', '012345678905', '4006381333931', '00016000275287', ' 012345678905 ']) {
        expect(normalizeBarcode(ok), isNotNull, reason: ok);
      }
    });
    test('rejects anything else', () {
      for (final bad in ['', '1234567', '123456789012345', '12345abc9012', '0123 4567 8905', '١٢٣٤٥٦٧٨٩٠١٢']) {
        expect(normalizeBarcode(bad), isNull, reason: bad);
      }
    });
  });

  group('lookup', () {
    FoodSearchService service(http.Response Function(http.Request) reply, {String? token = 't', List<Uri>? seen}) =>
        FoodSearchService(
          client: MockClient((r) async {
            seen?.add(r.url);
            expect(r.headers['Authorization'], 'Bearer t');
            return reply(r);
          }),
          tokenProvider: () async => token,
        );

    test('a found product comes back with its per-100 g numbers', () async {
      final seen = <Uri>[];
      final item = await service(
        (_) => http.Response(
          jsonEncode({'fdc_id': 5, 'description': 'OAT BAR', 'calories_per_100g': 400, 'protein_g_per_100g': 10, 'carbs_g_per_100g': 55, 'fat_g_per_100g': 15}),
          200,
        ),
        seen: seen,
      ).lookupBarcode('012345678905');
      expect(item!.description, 'OAT BAR');
      expect(item.caloriesPer100g, 400);
      expect(seen.single.path, endsWith('/foods/barcode'));
      expect(seen.single.queryParameters['code'], '012345678905');
    });

    test('404 is null, not an error', () async {
      expect(await service((_) => http.Response('{}', 404)).lookupBarcode('012345678905'), isNull);
    });

    test('a product without calories is treated as not found', () async {
      final item = await service((_) => http.Response(jsonEncode({'fdc_id': 5, 'description': 'X'}), 200)).lookupBarcode('012345678905');
      expect(item, isNull);
    });

    test('other failures are readable errors', () async {
      Future<String> message(int status) async {
        try {
          await service((_) => http.Response('x', status)).lookupBarcode('012345678905');
        } on FoodSearchException catch (e) {
          return e.message;
        }
        fail('expected an error');
      }

      expect(await message(401), contains('session has expired'));
      expect(await message(429), contains('searching very fast'));
      expect(await message(502), FoodSearchService.unavailableMessage);
    });

    test('signed out is a readable error', () async {
      expect(
        () => service((_) => http.Response('{}', 200), token: null).lookupBarcode('012345678905'),
        throwsA(isA<FoodSearchException>()),
      );
    });
  });

  group('Open Food Facts results', () {
    FoodItem item(String? type) => FoodItem(fdcId: type == null ? 7 : 0, description: 'Hazelnut spread', dataType: type, caloriesPer100g: 539);

    test('the backend fallback is recognised from data_type, USDA products are not', () {
      final off = FoodItem.fromApiJson({'fdc_id': 0, 'description': 'Hazelnut spread', 'data_type': 'Open Food Facts', 'calories_per_100g': 539});
      expect(off.isOpenFoodFacts, isTrue);
      expect(item('Branded').isOpenFoodFacts, isFalse);
      expect(item(null).isOpenFoodFacts, isFalse);
    });

    Future<void> showDialogFor(WidgetTester tester, FoodItem food) async {
      await tester.pumpWidget(CupertinoApp(home: Center(child: QuantityDialog(food: food))));
      await tester.pump();
    }

    testWidgets('the amount dialog credits Open Food Facts', (tester) async {
      await showDialogFor(tester, item('Open Food Facts'));
      expect(find.byKey(const ValueKey('off_credit')), findsOneWidget);
      expect(find.text('Source: Open Food Facts'), findsOneWidget);
    });

    testWidgets('and says nothing extra for a USDA product', (tester) async {
      await showDialogFor(tester, item('Branded'));
      expect(find.byKey(const ValueKey('off_credit')), findsNothing);
    });
  });

  group('scanner screen', () {
    Future<String?> run(WidgetTester tester, List<String> seen) async {
      String? result;
      await tester.pumpWidget(CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => result = await Navigator.push<String>(
              context,
              CupertinoPageRoute(
                builder: (_) => BarcodeScannerScreen(
                  previewBuilder: (context, onCode) => GestureDetector(
                    key: const ValueKey('fake_preview'),
                    onTap: () => seen.forEach(onCode),
                  ),
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('fake_preview')));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('returns the first valid code and ignores misreads', (tester) async {
      final result = await run(tester, ['12', 'hello', '012345678905', '4006381333931']);
      expect(result, '012345678905');
    });

    testWidgets('stays open while nothing valid has been seen', (tester) async {
      final result = await run(tester, ['12', 'abc']);
      expect(result, isNull);
      expect(find.text('Scan a barcode'), findsOneWidget);
    });

    testWidgets('a typed number is accepted, a bad one is refused', (tester) async {
      String? result;
      await tester.pumpWidget(CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async => result = await Navigator.push<String>(
              context,
              CupertinoPageRoute(
                builder: (_) => BarcodeScannerScreen(previewBuilder: (context, onCode) => const SizedBox()),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('type_barcode')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('barcode_number')), '123');
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      expect(find.text("That doesn't look like a barcode"), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, isNull);

      await tester.tap(find.byKey(const ValueKey('type_barcode')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('barcode_number')), '012345678905');
      await tester.tap(find.text('Look up'));
      await tester.pumpAndSettle();
      expect(result, '012345678905');
    });
  });

  group('open the camera at launch', () {
    test('is off until chosen, and remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final n = DisplayPrefsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(n.state.launchToCamera, isFalse);
      await n.setLaunchToCamera(true);
      expect(n.state.launchToCamera, isTrue);
      expect((await SharedPreferences.getInstance()).getBool(DisplayPrefsNotifier.launchToCameraKey), isTrue);

      final again = DisplayPrefsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(again.state.launchToCamera, isTrue);
      n.dispose();
      again.dispose();
    });
  });
}
