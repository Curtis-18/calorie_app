import 'package:flutter/cupertino.dart';

import '../../models/share_card.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../game/flame_style.dart';
import '../game/header_chips.dart';

/// The card always uses the dark palette, so a shared image looks the same
/// whichever mode the app is in.
const _p = TrackerPalette.dark;

/// The branded progress card that gets rendered to a PNG and shared.
///
/// Laid out at a fixed 360×640 logical size (9:16, story-friendly) and
/// captured at 3×, so the image is always 1080×1920 whatever the device.
class ProgressShareCard extends StatelessWidget {
  const ProgressShareCard({super.key, required this.data});

  static const size = Size(360, 640);
  static const pixelRatio = 3.0;

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    final style = FlameStyle.of(data.tier, dim: !data.hasStreak, palette: _p);
    final glowColor = data.hasStreak ? style.color : TrackerColors.accentStart;

    return SizedBox.fromSize(
      size: size,
      // Opaque base first: the glow is translucent, and a PNG keeps whatever
      // is (or isn't) underneath it.
      child: DecoratedBox(
        decoration: BoxDecoration(color: _p.background),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 0.95,
              colors: [
                TrackerColors.alpha(glowColor, 0.30),
                TrackerColors.alpha(glowColor, 0.06),
                TrackerColors.alpha(glowColor, 0),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BrandRow(date: data.longDate),
                // Centred in the free space; scales down rather than
                // overflowing if a font runs large.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Hero(data: data, style: style),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: _LevelTile(data: data)),
                    const SizedBox(width: 10),
                    Expanded(child: _BadgeCountTile(data: data)),
                  ],
                ),
                if (data.badges.isNotEmpty) ...[const SizedBox(height: 10), _BadgeRow(data: data)],
                if (data.showsWeight) ...[
                  const SizedBox(height: 10),
                  _WeightTile(change: data.weightChange!, since: data.weightSince!),
                ],
                const SizedBox(height: 18),
                Text(
                  'Small habits, every day.',
                  textAlign: TextAlign.center,
                  style: AppType.caption(color: _p.textTertiary, size: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: TrackerColors.calorieGradient, borderRadius: BorderRadius.circular(8)),
          child: Icon(CupertinoIcons.flame_fill, size: 15, color: _p.textPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Calorie Tracker',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.headline(color: _p.textPrimary).copyWith(fontSize: 14.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(date, style: AppType.caption(color: _p.textSecondary, size: 11.5)),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data, required this.style});

  final ShareCardData data;
  final FlameStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TrackerColors.alpha(style.color, 0.12),
            border: Border.all(color: TrackerColors.alpha(style.color, 0.28)),
            boxShadow: style.glow > 0 ? AppDecor.glow(style.color, blur: 40, opacity: 0.45 * style.glow) : null,
          ),
          child: GradientIcon(
            CupertinoIcons.flame_fill,
            gradient: style.gradient,
            size: 52,
            glowColor: style.color,
            glow: style.glow,
          ),
        ),
        const SizedBox(height: 16),
        if (data.hasStreak) ...[
          Text(
            '${data.streakDays}',
            textAlign: TextAlign.center,
            style: AppType.display(size: 72, color: _p.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'day streak',
            textAlign: TextAlign.center,
            style: AppType.title(color: _p.textSecondary),
          ),
          const SizedBox(height: 12),
          Center(
            child: _Pill(
              color: style.color,
              text: data.bestStreak > data.streakDays
                  ? '${data.tier.label} · best ${data.bestStreak}'
                  : '${data.tier.label} · personal best',
            ),
          ),
        ] else ...[
          Text(
            'Level ${data.level}',
            textAlign: TextAlign.center,
            style: AppType.display(size: 56, color: _p.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'and just getting started',
            textAlign: TextAlign.center,
            style: AppType.title(color: _p.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(color, 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: TrackerColors.alpha(color, 0.35)),
      ),
      child: Text(
        text,
        style: AppType.caption(color: color, size: 12.5).copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Card-local tile: a translucent well with a hairline, like `AppCard` but
/// without its blur (backdrop filters don't capture reliably to an image).
class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: TrackerColors.alpha(_p.surface, 0.82),
        borderRadius: AppRadii.buttonAll,
        border: Border.all(color: _p.borderStrong),
      ),
      child: child,
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LEVEL', style: AppType.sectionLabel(color: _p.textSecondary).copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Text('${data.level}', style: AppType.display(size: 28, color: _p.textPrimary)),
          const SizedBox(height: 8),
          XpBar(fraction: data.levelFraction, height: 6, track: _p.textPrimary.withValues(alpha: 0.1)),
          const SizedBox(height: 6),
          Text('${data.totalXp} XP', style: AppType.caption(color: _p.textTertiary, size: 11)),
        ],
      ),
    );
  }
}

class _BadgeCountTile extends StatelessWidget {
  const _BadgeCountTile({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BADGES', style: AppType.sectionLabel(color: _p.textSecondary).copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: '${data.badgeCount}',
              style: AppType.display(size: 28, color: _p.textPrimary),
              children: [
                TextSpan(
                  text: ' / ${data.badgeTotal}',
                  style: AppType.headline(color: _p.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          XpBar(
            fraction: data.badgeTotal == 0 ? 0 : data.badgeCount / data.badgeTotal,
            height: 6,
            track: _p.textPrimary.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 6),
          Text('unlocked', style: AppType.caption(color: _p.textTertiary, size: 11)),
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.data});

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final badge in data.badges)
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: TrackerColors.calorieGradient,
                border: Border.all(color: TrackerColors.alpha(_p.textPrimary, 0.22)),
                boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 12, opacity: 0.3),
              ),
              child: Icon(badge.icon, size: 18, color: _p.textPrimary),
            ),
        ],
      ),
    );
  }
}

/// Weight as a change only, in the neutral accent (no red/green judgement).
class _WeightTile extends StatelessWidget {
  const _WeightTile({required this.change, required this.since});

  final String change;
  final String since;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TrackerColors.alpha(TrackerColors.accentEnd, 0.14),
            ),
            child: const Icon(CupertinoIcons.graph_square_fill, size: 18, color: TrackerColors.accentEnd),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEIGHT TREND', style: AppType.sectionLabel(color: _p.textSecondary).copyWith(fontSize: 10)),
                const SizedBox(height: 3),
                Text(since, style: AppType.caption(color: _p.textTertiary, size: 11)),
              ],
            ),
          ),
          Text(change, style: AppType.display(size: 24, color: TrackerColors.accentEnd).copyWith(letterSpacing: -0.6)),
        ],
      ),
    );
  }
}
