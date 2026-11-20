import 'dart:ui' show Locale;

/// A language the app can be shown in.
class AppLanguage {
  const AppLanguage(this.code, this.nativeName);

  final String code;

  /// The language's own name, so it can be found whatever language is on screen.
  final String nativeName;
}

const supportedLanguages = <AppLanguage>[
  AppLanguage('en', 'English'),
  AppLanguage('es', 'Español'),
  AppLanguage('fr', 'Français'),
  AppLanguage('de', 'Deutsch'),
  AppLanguage('pt', 'Português'),
  AppLanguage('it', 'Italiano'),
];

const fallbackLanguage = 'en';

bool isSupportedLanguage(String? code) => supportedLanguages.any((l) => l.code == code);

String? languageName(String? code) {
  for (final l in supportedLanguages) {
    if (l.code == code) return l.nativeName;
  }
  return null;
}

/// Which language to show, the way most apps decide: an explicit choice in
/// Settings wins; otherwise the first language in the device's own list that
/// the app has; otherwise English. The device list already reflects where the
/// person lives and what they speak, so no location permission is needed.
String resolveLanguage({String? saved, List<Locale> deviceLocales = const []}) {
  if (isSupportedLanguage(saved)) return saved!;
  for (final locale in deviceLocales) {
    if (isSupportedLanguage(locale.languageCode)) return locale.languageCode;
  }
  return fallbackLanguage;
}
