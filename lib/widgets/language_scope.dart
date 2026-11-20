import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/language_provider.dart';

/// Keeps the app's language current: follows the phone while the choice is
/// "automatic", and makes every screen build again when the language changes
/// (text made with the global `tr()` is not tied to the widget tree, and a
/// `const` subtree would otherwise keep the old words). Navigation, scroll
/// positions and form state are untouched.
class LanguageScope extends ConsumerStatefulWidget {
  const LanguageScope({super.key, required this.builder});

  final Widget Function(BuildContext context, Locale locale) builder;

  @override
  ConsumerState<LanguageScope> createState() => _LanguageScopeState();
}

class _LanguageScopeState extends ConsumerState<LanguageScope> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The phone's language list changed: follow it while the choice is "automatic".
  @override
  void didChangeLocales(List<Locale>? locales) => ref.invalidate(activeLanguageProvider);

  static void _markAllDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markAllDirty);
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(activeLanguageProvider);
    if (AppStrings.active != language) {
      AppStrings.active = language;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) (context as Element).visitChildren(_markAllDirty);
      });
    }
    return widget.builder(context, Locale(language));
  }
}
