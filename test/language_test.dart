import 'dart:io';

import 'package:calorie_app/l10n/app_language.dart';
import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/main.dart' show appLocalizationsDelegates;
import 'package:calorie_app/providers/language_provider.dart';
import 'package:calorie_app/screens/settings_screen.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/language_scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('which language is shown', () {
    test('a choice in Settings wins over the phone', () {
      expect(resolveLanguage(saved: 'fr', deviceLocales: const [Locale('de')]), 'fr');
    });

    test('otherwise the first language on the phone that the app has', () {
      expect(resolveLanguage(deviceLocales: const [Locale('ja'), Locale('es', 'MX'), Locale('de')]), 'es');
      expect(resolveLanguage(deviceLocales: const [Locale('pt', 'BR')]), 'pt');
    });

    test('English when nothing matches, and an unknown saved choice is ignored', () {
      expect(resolveLanguage(deviceLocales: const [Locale('ja'), Locale('ko')]), 'en');
      expect(resolveLanguage(), 'en');
      expect(resolveLanguage(saved: 'xx', deviceLocales: const [Locale('it')]), 'it');
    });

    test('every language has a name of its own, English first', () {
      expect(supportedLanguages.first.code, 'en');
      expect(languageName('es'), 'Español');
      expect(languageName('xx'), isNull);
    });
  });

  group('the translations', () {
    test('every language has exactly the same phrases, none empty, with the same {placeholders}', () {
      final reference = translationTables['es']!;
      final holes = RegExp(r'\{(\w+)\}');
      Set<String> placeholders(String s) => holes.allMatches(s).map((m) => m.group(1)!).toSet();
      for (final entry in translationTables.entries) {
        expect(entry.value.keys.toSet(), reference.keys.toSet(), reason: '${entry.key} differs from es');
        for (final MapEntry(key: english, value: text) in entry.value.entries) {
          expect(text.trim(), isNotEmpty, reason: '${entry.key}: $english');
          expect(placeholders(text), placeholders(english), reason: '${entry.key}: $english');
        }
      }
      // Every language the picker offers (except English itself) has a table.
      for (final l in supportedLanguages.where((l) => l.code != 'en')) {
        expect(translationTables.containsKey(l.code), isTrue, reason: l.code);
      }
    });

    test('every phrase the app asks to translate has a translation (catches typos)', () {
      final literal = RegExp(r"""context\.tr\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")""");
      final missing = <String>[];
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))) {
        for (final m in literal.allMatches(file.readAsStringSync())) {
          final text = (m.group(1) ?? m.group(2))!.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
          if (text == 'OK') continue; // the same in every language
          if (!translationTables['es']!.containsKey(text)) missing.add('${file.path}: $text');
        }
      }
      expect(missing, isEmpty);
    });

    test('a phrase with no translation is shown in English, and placeholders are filled in', () {
      const es = AppStrings('es');
      expect(es.t('Settings'), 'Ajustes');
      expect(es.t('A phrase nobody translated'), 'A phrase nobody translated');
      expect(es.t('{n} items', {'n': 3}), '3 elementos');
      expect(const AppStrings('en').t('{n} items', {'n': 3}), '3 items');
      expect(const AppStrings('fr').t('1 item'), '1 élément');
    });

    testWidgets('without translations in the tree the English text shows', (tester) async {
      late String text;
      await tester.pumpWidget(CupertinoApp(home: Builder(builder: (context) {
        text = context.tr('Settings');
        return const SizedBox();
      })));
      expect(text, 'Settings');
    });
  });

  group('the saved choice', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('is remembered, can go back to automatic, and junk is ignored', () async {
      expect(await LanguageNotifier.load(), isNull);
      final n = LanguageNotifier();
      await n.set('es');
      expect(n.state, 'es');
      expect(await LanguageNotifier.load(), 'es');
      await n.set('klingon');
      expect(n.state, isNull); // not a language we have: back to automatic
      expect(await LanguageNotifier.load(), isNull);
      await n.set('de');
      await n.set(null);
      expect(await LanguageNotifier.load(), isNull);
    });

    test('a saved value that is no longer supported loads as automatic', () async {
      SharedPreferences.setMockInitialValues({'app_language': 'xx'});
      expect(await LanguageNotifier.load(), isNull);
    });
  });

  group('Settings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => AppStrings.active = 'en');

    Future<ProviderContainer> pump(WidgetTester tester, {String? saved}) async {
      tester.view.physicalSize = const Size(750, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final container = ProviderContainer(overrides: [languageProvider.overrideWith((ref) => LanguageNotifier(saved))]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: LanguageScope(
          builder: (context, locale) => CupertinoApp(
            theme: AppTheme.cupertino,
            locale: locale,
            supportedLocales: [for (final l in supportedLanguages) Locale(l.code)],
            localizationsDelegates: appLocalizationsDelegates,
            home: const SettingsView(profile: null),
          ),
        ),
      ));
      await settle(tester);
      return container;
    }

    testWidgets('follows the phone until a language is chosen, and says so', (tester) async {
      await pump(tester);
      expect(find.text('Réglages'), findsOneWidget); // the phone is French
      final row = find.byKey(const ValueKey('language'));
      await tester.ensureVisible(row);
      expect(find.descendant(of: row, matching: find.text('Automatique · Français')), findsOneWidget);
    });

    testWidgets('choosing a language switches the app at once and remembers it', (tester) async {
      final container = await pump(tester);
      final row = find.byKey(const ValueKey('language'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      expect(find.text('Elige un idioma'), findsNothing); // the sheet is in French
      expect(find.text('Choisissez une langue'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language_es')));
      await settle(tester);
      expect(container.read(languageProvider), 'es');
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Réglages'), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('language')), matching: find.text('Español')), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('app_language'), 'es');
    });

    testWidgets('Automatic goes back to the phone\'s language', (tester) async {
      final container = await pump(tester, saved: 'de');
      expect(find.text('Einstellungen'), findsOneWidget);
      final row = find.byKey(const ValueKey('language'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('language_auto')));
      await settle(tester);
      expect(container.read(languageProvider), isNull);
      expect(find.text('Réglages'), findsOneWidget);
    });

    testWidgets('when the phone changes language, an automatic app follows', (tester) async {
      final container = await pump(tester);
      tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
      // What the app root does when the phone reports new languages.
      container.invalidate(activeLanguageProvider);
      await settle(tester);
      expect(find.text('Impostazioni'), findsOneWidget);
    });
  });
}
