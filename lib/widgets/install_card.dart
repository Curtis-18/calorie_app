import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/pwa_install_provider.dart';
import '../services/pwa_install/pwa_install.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';

/// Adds NuStreak to the Home Screen: the browser's own dialog where there is
/// one, otherwise (iPhone, iPad) the three-step guide.
Future<void> startInstall(BuildContext context, WidgetRef ref) async {
  final state = ref.read(installProvider);
  if (state.mode == InstallMode.prompt) {
    await ref.read(installProvider.notifier).install();
  } else if (state.mode == InstallMode.ios) {
    await showInstallGuide(context);
  }
}

/// The steps for an iPhone or iPad, which have no install dialog.
Future<void> showInstallGuide(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Add to Home Screen'), style: AppType.title(), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr('Open NuStreak like an app, one tap away.'),
            style: AppType.caption(color: TrackerColors.textSecondary, size: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Step(
            key: const ValueKey('install_step_1'),
            n: 1,
            icon: CupertinoIcons.share,
            text: tr('Tap the Share button in Safari.'),
          ),
          const SizedBox(height: AppSpacing.md),
          _Step(
            key: const ValueKey('install_step_2'),
            n: 2,
            icon: CupertinoIcons.plus_app,
            text: tr('Scroll down and choose Add to Home Screen.'),
          ),
          const SizedBox(height: AppSpacing.md),
          _Step(
            key: const ValueKey('install_step_3'),
            n: 3,
            icon: CupertinoIcons.flame_fill,
            text: tr('Tap Add. NuStreak is now on your Home Screen.'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr("Don't see it? Open this page in Safari first."),
            style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const ValueKey('install_guide_done'),
            label: tr('Got it'),
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({super.key, required this.n, required this.icon, required this.text});

  final int n;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: TrackerColors.calorieGradient,
          ),
          child: Icon(icon, size: 20, color: TrackerColors.onAccent),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text('$n. $text', style: AppType.body(size: 15, color: TrackerColors.textPrimary))),
      ],
    );
  }
}

/// A card on Today asking whether to put NuStreak on the Home Screen. Shows
/// only where it can work (not already installed, not a phone build), and only
/// once the person has logged something, so it never competes with the first
/// meal. "Not now" hides it for two weeks.
class InstallCard extends ConsumerWidget {
  const InstallCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(installProvider);
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: !state.showCard
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                key: const ValueKey('install_card'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.containerAll,
                  color: TrackerColors.surface,
                  border: Border.all(color: TrackerColors.alpha(TrackerColors.accentStart, 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            gradient: TrackerColors.calorieGradient,
                          ),
                          child: Icon(CupertinoIcons.flame_fill, size: 22, color: TrackerColors.onAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('Add NuStreak to your Home Screen'), style: AppType.headline()),
                              const SizedBox(height: 2),
                              Text(
                                tr('Open NuStreak like an app, one tap away.'),
                                style: AppType.caption(color: TrackerColors.textSecondary, size: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            key: const ValueKey('install_card_add'),
                            label: state.mode == InstallMode.ios ? tr('Show me how') : tr('Add'),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              startInstall(context, ref);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        AppButton(
                          key: const ValueKey('install_card_dismiss'),
                          style: AppButtonStyle.quiet,
                          expand: false,
                          label: tr('Not now'),
                          onPressed: ref.read(installProvider.notifier).dismissCard,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
