import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'translations_de.dart';
import 'translations_es.dart';
import 'translations_fr.dart';
import 'translations_it.dart';
import 'translations_pt.dart';

/// Every language's table, keyed by the English text it translates. A phrase
/// with no entry is shown in English, so a screen can be translated a piece at
/// a time and nothing ever shows a blank or a key.
const translationTables = <String, Map<String, String>>{
  'es': spanish,
  'fr': french,
  'de': german,
  'pt': portuguese,
  'it': italian,
};

/// The text of the app in one language. Use `context.tr('English text')`;
/// `{name}` in the text is replaced from `args`.
class AppStrings {
  const AppStrings(this.code);

  final String code;

  /// The language on screen, for text built where there is no `BuildContext`
  /// (services, models, providers). Kept up to date by [LanguageScope].
  static String active = fallbackLanguage;

  static const delegate = _AppStringsDelegate();

  static AppStrings? maybeOf(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings);

  String t(String english, [Map<String, Object?>? args]) {
    var text = translationTables[code]?[english] ?? english;
    if (args != null) {
      args.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    }
    return text;
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => isSupportedLanguage(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(
    isSupportedLanguage(locale.languageCode)
        ? locale.languageCode
        : fallbackLanguage,
  );

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension AppTranslate on BuildContext {
  /// [english] in the language on screen. Depends on the language, so the
  /// widget rebuilds when it changes. Without translations in the tree
  /// (a screen under test) it is just [english].
  String tr(String english, [Map<String, Object?>? args]) =>
      (AppStrings.maybeOf(this) ?? const AppStrings(fallbackLanguage)).t(
        english,
        args,
      );
}

/// [english] in the language on screen, from anywhere (no context needed).
/// Widgets use it in `build`; the whole app rebuilds when the language
/// changes, so nothing stays in the old language. Text that is stored (a
/// constant, a list built once) must keep the English and be passed through
/// here when it is shown.
String tr(String english, [Map<String, Object?>? args]) =>
    AppStrings(AppStrings.active).t(english, args);
