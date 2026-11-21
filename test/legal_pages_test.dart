import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The privacy policy and terms are static pages in the web build (Google's
/// sign-in review and the stores need public links to them). These guard the
/// parts that must not rot: they exist, are reachable before the catch-all
/// rewrite, name a contact, and still describe what the app really sends out.
void main() {
  final privacy = File('web/privacy.html').readAsStringSync();
  final terms = File('web/terms.html').readAsStringSync();

  test('both pages exist, are complete HTML and name the contact address', () {
    for (final page in [privacy, terms]) {
      expect(page, startsWith('<!DOCTYPE html>'));
      expect(page, contains('</html>'));
      expect(page, contains('mailto:18vicu@gmail.com'));
      expect(page, contains('Last updated 21 November 2026'));
      expect(page, isNot(contains('TODO')));
      expect(page, isNot(contains('[')), reason: 'no placeholder left to fill in');
    }
  });

  test('the routes /privacy and /terms are served before the single-page rewrite', () {
    final rewrites = (jsonDecode(File('vercel.json').readAsStringSync())['rewrites'] as List).cast<Map<String, dynamic>>();
    final sources = rewrites.map((r) => r['source']).toList();
    expect(sources.indexOf('/privacy'), lessThan(sources.indexOf('/(.*)')));
    expect(sources.indexOf('/terms'), lessThan(sources.indexOf('/(.*)')));
    expect(rewrites.firstWhere((r) => r['source'] == '/privacy')['destination'], '/privacy.html');
    expect(rewrites.firstWhere((r) => r['source'] == '/terms')['destination'], '/terms.html');
    expect(rewrites.last['destination'], '/index.html');
  });

  test('the privacy policy covers what the app really does', () {
    for (final must in [
      'You must be 18 or older',
      'Gemini',
      'Supabase',
      'Render',
      'Vercel',
      'USDA FoodData Central',
      'Open Food Facts',
      'Google Sign-In',
      'Delete account',
      'Data Protection and Privacy Act, 2019',
      'We do not store scan photos',
      'do <strong>not</strong> use advertising or analytics trackers',
      'Not medical advice',
      '24 hours',
    ]) {
      expect(privacy, contains(must), reason: 'missing: $must');
    }
  });

  test('the terms cover the rules the app enforces', () {
    for (final must in ['18 or older', 'not medical advice', 'block people and report', 'eating disorders', 'laws of Uganda', '/privacy']) {
      expect(terms, contains(must), reason: 'missing: $must');
    }
  });

  test('the two pages link to each other', () {
    expect(privacy, contains('href="/terms"'));
    expect(terms, contains('href="/privacy"'));
  });
}
