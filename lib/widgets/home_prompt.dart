import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/notify_prompt_provider.dart';
import '../providers/web_push_provider.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'install_card.dart';

/// One gentle question at a time under the tiles on Today: first "turn on
/// notifications" (so bites and streak reminders reach the person), and only
/// once that is answered or put away, "add to Home Screen". Nothing shows where
/// neither can work.
class HomePrompt extends ConsumerWidget {
  const HomePrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(notifyPromptHiddenProvider);
    final status = ref.watch(webPushProvider).status;
    final asking = !hidden && status == WebPushStatus.off;
    // While the browser is still being asked, show neither: no flicker.
    if (!hidden && status == WebPushStatus.checking) return const SizedBox(width: double.infinity);
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: asking ? const NotifyCard() : const InstallCard(),
    );
  }
}

/// "Turn on notifications": the browser only asks for permission when the
/// person taps, so this is the tap.
class NotifyCard extends ConsumerWidget {
  const NotifyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final web = ref.watch(webPushProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        key: const ValueKey('notify_card'),
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
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: TrackerColors.calorieGradient),
                  child: Icon(CupertinoIcons.bell_fill, size: 22, color: TrackerColors.onAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Never miss a bite'), style: AppType.headline()),
                      const SizedBox(height: 2),
                      Text(
                        tr('Hear when a friend sends you a bite or your streak needs you. A few a day at most, quiet at night.'),
                        style: AppType.caption(color: TrackerColors.textSecondary, size: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (web.message != null) ...[
              const SizedBox(height: 8),
              Text(web.message!, style: AppType.caption(color: TrackerColors.warning, size: 12)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const ValueKey('notify_card_on'),
                    label: tr('Turn on'),
                    loading: web.busy,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(webPushProvider.notifier).enable();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  key: const ValueKey('notify_card_dismiss'),
                  style: AppButtonStyle.quiet,
                  expand: false,
                  label: tr('Not now'),
                  onPressed: ref.read(notifyPromptHiddenProvider.notifier).dismiss,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
