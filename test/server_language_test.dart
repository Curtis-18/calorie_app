import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/services/language_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('the language the server is told', () {
    test('every request says which language the app is showing, read when it is sent', () async {
      final seen = <String?>[];
      final client = languageClient(MockClient((request) async {
        seen.add(request.headers['Accept-Language']);
        return http.Response('{}', 200);
      }));
      await client.get(Uri.parse('https://example.test/a'));
      AppStrings.active = 'es';
      await client.post(Uri.parse('https://example.test/b'), body: '{}');
      AppStrings.active = 'pt';
      await client.get(Uri.parse('https://example.test/c'), headers: {'Authorization': 'Bearer x'});
      expect(seen, ['en', 'es', 'pt']);
    });
  });

  group('a scanned food in another language', () {
    Map<String, dynamic> item({String? display}) => {
          'name': 'rice',
          'estimated_grams': 150,
          'matched': true,
          'calories_per_100g': 130,
          'display_name': ?display,
        };

    test('shows the local name but searches the food database with the English one', () {
      final food = DetectedFood.fromApiJson(item(display: 'arroz'));
      expect(food.name, 'arroz');
      expect(food.lookupName, 'rice');
    });

    test('once the person renames it, their own words are used', () {
      final food = DetectedFood.fromApiJson(item(display: 'arroz'));
      food.name = 'arroz con pollo';
      expect(food.lookupName, 'arroz con pollo');
    });

    test('without a local name nothing changes', () {
      final food = DetectedFood.fromApiJson(item());
      expect(food.name, 'rice');
      expect(food.lookupName, 'rice');
      food.name = 'brown rice';
      expect(food.lookupName, 'brown rice');
    });
  });
}
