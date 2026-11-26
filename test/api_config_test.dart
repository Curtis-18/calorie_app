import 'dart:convert';
import 'dart:io';

import 'package:calorie_app/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const render = 'https://${ApiConfig.renderHost}';
  final site = Uri.parse('https://calorie-app-ug.vercel.app/u/mia?x=1');

  String resolve({String configured = render, bool isWeb = true, Uri? page}) =>
      ApiConfig.resolveBaseUrl(configured: configured, isWeb: isWeb, page: page ?? site);

  test('the published web app calls its own address', () {
    expect(resolve(), 'https://calorie-app-ug.vercel.app/api');
    // A trailing slash in the BACKEND_URL secret must not switch this off.
    expect(resolve(configured: '$render/'), 'https://calorie-app-ug.vercel.app/api');
  });

  test('phone builds and local development call the backend directly', () {
    expect(resolve(isWeb: false), render);
    expect(resolve(page: Uri.parse('http://localhost:5000/')), render);
    expect(resolve(page: Uri.parse('https://127.0.0.1:5000/')), render);
  });

  test('another BACKEND_URL is used as given', () {
    expect(resolve(configured: 'https://api.example.com'), 'https://api.example.com');
  });

  test('vercel.json forwards /api to the same backend, before the app catch-all', () {
    final config = jsonDecode(File('vercel.json').readAsStringSync()) as Map<String, dynamic>;
    final rewrites = (config['rewrites'] as List).cast<Map<String, dynamic>>();
    final api = rewrites.indexWhere((r) => r['source'] == '/api/(.*)');
    final catchAll = rewrites.indexWhere((r) => r['source'] == '/(.*)');
    expect(api, isNonNegative);
    expect(api, lessThan(catchAll));
    expect(rewrites[api]['destination'], '$render/\$1');
  });

  test('answers forwarded through /api are never cached', () {
    final config = jsonDecode(File('vercel.json').readAsStringSync()) as Map<String, dynamic>;
    final rule = (config['headers'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((h) => h['source'] == '/api/(.*)');
    expect(rule['headers'], [
      {'key': 'x-vercel-enable-rewrite-caching', 'value': '0'},
    ]);
  });
}
