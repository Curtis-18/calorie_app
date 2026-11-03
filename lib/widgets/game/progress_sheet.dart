import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/progress.dart';
import '../../providers/progress_provider.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../app_button.dart';
import '../app_card.dart';
import '../app_dialog.dart';
import '../glass.dart';
import '../pressable.dart';
import '../share/share_sheet.dart';
import 'flame_style.dart';
import 'header_chips.dart';

Future<void> showProgressSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => const AppSheet(child: _ProgressSheetContent()),
  );
}

class _ProgressSheetContent extends ConsumerWidget {
  const _ProgressSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your progress', style: AppType.title())),
              if (progress != null)
                Semantics(
                  button: true,
                  label: 'Share progress',
                  child: AppIconButton(
                    icon: CupertinoIcons.share,
                    size: 36,
                    iconSize: 16,
                    onPressed: () => showShareProgressSheet(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (progress == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: PulsingRing(size: 40, strokeWidth: 4)),
            )
          else ...[
            StreakHeroCard(streak: progress.streak),
            const SizedBox(height: 14),
            LevelCard(level: progress.level, todayXp: progress.today.xp),
            const SizedBox(height: 22),
            Row(
              children: [
                Text('Badges', style: AppType.headline()),
                const Spacer(),
                Text(
                  '${progress.unlockedCount} / ${progress.achievements.length}',
                  style: AppType.caption(color: TrackerColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            BadgeGrid(achievements: progress.achievements),
            const SizedBox(height: 22),
            const _HowToEarn(),
          ],
        ],
      ),
    );
  }
}

class StreakHeroCard extends StatelessWidget {
  const StreakHeroCard({super.key, required this.streak});

  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    final style = FlameStyle.of(streak.tier, dim: streak.current == 0);
    final next = streak.tier.next;
    final daysToNext = next == null ? 0 : next.minDays - streak.current;

    return AppCard(
      glow: streak.current > 0 ? style.color : null,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TrackerColors.alpha(style.color, 0.12),
                  boxShadow: style.glow > 0 ? AppDecor.glow(style.color, blur: 24, opacity: 0.3 * style.glow) : null,
                ),
                child: GradientIcon(
                  CupertinoIcons.flame_fill,
                  gradient: style.gradient,
                  size: 34,
                  glowColor: style.color,
                  glow: style.glow,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streak.current == 0 ? 'No streak yet' : '${streak.current}-day streak',
                      style: AppType.display(size: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streak.current == 0
                          ? 'Log a meal to light your first flame.'
                          : '${streak.tier.label} · best ${streak.best} day${streak.best == 1 ? '' : 's'}',
                      style: AppType.callout(color: streak.current == 0 ? TrackerColors.textSecondary : style.color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (streak.atRisk) ...[
            const SizedBox(height: AppSpacing.lg),
            _Notice(
              icon: CupertinoIcons.clock_fill,
              color: TrackerColors.accentEndText,
              text: streak.freezes > 0
                  ? "Log something today to grow your streak. If you can't, a freeze will save it."
                  : 'Log something today to keep your streak alive.',
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (var i = 0; i < streak.maxFreezes; i++) ...[
                Icon(
                  CupertinoIcons.snow,
                  size: 18,
                  color: i < streak.freezes
                      ? FlameStyle.freezeColor
                      : TrackerColors.alpha(TrackerColors.textPrimary, 0.18),
                ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Streak freezes cover a missed day. You earn one every 7 days.',
                  style: AppType.caption(color: TrackerColors.textSecondary),
                ),
              ),
            ],
          ),
          if (next != null && streak.current > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '$daysToNext more day${daysToNext == 1 ? '' : 's'} to ${next.label}',
              style: AppType.caption(color: TrackerColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(color, 0.1),
        borderRadius: AppRadii.smallAll,
        border: Border.all(color: TrackerColors.alpha(color, 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppType.caption(color: color, size: 12.5))),
        ],
      ),
    );
  }
}

class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.level, required this.todayXp});

  final LevelInfo level;
  final int todayXp;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LevelBadge(level: level, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level ${level.level}', style: AppType.headline()),
                    const SizedBox(height: 2),
                    Text(
                      '${level.xp} XP total',
                      style: AppType.caption(color: TrackerColors.textTertiary),
                    ),
                  ],
                ),
              ),
              if (todayXp > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: TrackerColors.alpha(TrackerColors.accentEnd, 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '+$todayXp today',
                    style: AppType.caption(color: TrackerColors.accentEndText, size: 12)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          XpBar(fraction: level.fraction),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${level.xpIntoLevel} / ${level.xpForLevel} XP to level ${level.level + 1}',
            style: AppType.caption(color: TrackerColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.achievements});

  final List<AchievementInfo> achievements;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 18,
          children: [
            for (final a in achievements) SizedBox(width: width, child: BadgeTile(achievement: a)),
          ],
        );
      },
    );
  }
}

class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.achievement});

  final AchievementInfo achievement;

  void _explain(BuildContext context) {
    final a = achievement;
    final status = a.unlocked
        ? (a.unlockedOn != null ? 'Unlocked ${_formatDate(a.unlockedOn!)}.' : 'Unlocked.')
        : (a.goal > 1 ? 'Progress: ${a.progress} of ${a.goal}.' : 'Not unlocked yet.');
    showAppDialog(context: context, title: a.title, message: '${a.description}\n\n$status');
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    const size = 64.0;
    return Semantics(
      button: true,
      label: '${a.title}, ${a.unlocked ? 'unlocked' : 'locked'}',
      child: Pressable(
        onTap: () => _explain(context),
        borderRadius: AppRadii.buttonAll,
        child: Column(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!a.unlocked && a.goal > 1)
                    CustomPaint(
                      size: const Size.square(size),
                      painter: XpRingPainter(fraction: a.fraction, strokeWidth: 3),
                    ),
                  Container(
                    width: size - 12,
                    height: size - 12,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: a.unlocked ? TrackerColors.calorieGradient : null,
                      color: a.unlocked ? null : TrackerColors.surfaceElevated,
                      border: Border.all(
                        color: a.unlocked
                            ? TrackerColors.alpha(TrackerColors.onAccent, 0.22)
                            : TrackerColors.border,
                      ),
                      boxShadow: a.unlocked ? AppDecor.glow(TrackerColors.accentStart, blur: 16, opacity: 0.35) : null,
                    ),
                    child: Icon(
                      a.icon,
                      size: 22,
                      color: a.unlocked ? TrackerColors.onAccent : TrackerColors.textTertiary,
                    ),
                  ),
                  if (!a.unlocked && a.goal <= 1)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Icon(CupertinoIcons.lock_fill, size: 12, color: TrackerColors.textTertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              a.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption(
                color: a.unlocked ? TrackerColors.textPrimary : TrackerColors.textSecondary,
                size: 12,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            if (!a.unlocked && a.goal > 1)
              Text(
                '${a.progress}/${a.goal}',
                style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _HowToEarn extends StatelessWidget {
  const _HowToEarn();

  static const _rows = [
    (CupertinoIcons.plus_circle_fill, 'Log a meal', '+10'),
    (CupertinoIcons.camera_fill, 'Log it with a photo', '+5'),
    (CupertinoIcons.square_grid_2x2_fill, 'Log all four meals', '+20'),
    (CupertinoIcons.bolt_fill, 'Hit your protein target', '+20'),
    (CupertinoIcons.scope, 'Land within 10% of your calories', '+30'),
    (CupertinoIcons.flame_fill, 'Streak bonus, per day', 'up to +30'),
  ];

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      opacity: 0.05,
      borderRadius: AppRadii.buttonAll,
      border: Border.all(color: TrackerColors.border),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW TO EARN XP', style: AppType.sectionLabel()),
          const SizedBox(height: AppSpacing.sm),
          for (final (icon, label, xp) in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: TrackerColors.accentEndText),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: AppType.callout())),
                  Text(
                    xp,
                    style: AppType.caption(color: TrackerColors.textPrimary, size: 12.5)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
