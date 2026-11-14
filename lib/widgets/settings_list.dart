import 'package:flutter/cupertino.dart';

import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';
import 'pressable.dart';

/// A labelled card of rows, the building block of Settings and Profile.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.label, required this.children, this.footer});

  final String? label;
  final List<Widget> children;

  /// A quiet line under the card explaining what the rows do.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text(label!.toUpperCase(), style: AppType.sectionLabel()),
          ),
        ],
        AppCard(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const AppDivider(indent: 16),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(footer!, style: AppType.caption(color: TrackerColors.textTertiary)),
          ),
      ],
    );
  }
}

/// One row: a tinted icon tile, a title with an optional subtitle, then a
/// value and chevron (when tappable) or any [trailing] widget such as a switch.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.color,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Short current value shown before the chevron, e.g. "@river".
  final String? value;

  /// Tint of the icon tile. Defaults to the brand accent.
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? TrackerColors.error : (color ?? TrackerColors.accentEnd);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TrackerColors.alpha(tint, 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: TrackerColors.ink(tint)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppType.body(size: 15.5, color: destructive ? TrackerColors.error : TrackerColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!, style: AppType.caption(color: TrackerColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(size: 14.5, color: TrackerColors.textSecondary),
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
          if (trailing == null && onTap != null) ...[
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_right, size: 14, color: TrackerColors.textTertiary),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: Pressable(onTap: onTap, scale: 1, child: ColoredBox(color: const Color(0x00000000), child: row)),
    );
  }
}

/// A [SettingsRow] ending in a switch.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color,
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: TrackerColors.accentEnd,
        onChanged: onChanged,
      ),
    );
  }
}
