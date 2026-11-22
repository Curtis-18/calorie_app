import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../providers/workouts_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';
import 'pressable.dart';

Future<bool?> showLogMovementSheet(BuildContext context) =>
    showAppSheet<bool>(context: context, builder: (_) => const LogMovementSheet());

/// "Log something else": a walk with the dog, a swim, a game of football, anything
/// done away from the app. Pick what it was, how long, and how it felt.
class LogMovementSheet extends ConsumerStatefulWidget {
  const LogMovementSheet({super.key});

  @override
  ConsumerState<LogMovementSheet> createState() => _LogMovementSheetState();
}

class _LogMovementSheetState extends ConsumerState<LogMovementSheet> {
  String? _activity;
  int _minutes = 30;
  String _intensity = 'moderate';
  bool _saving = false;
  bool _failed = false;

  static const _presets = [10, 20, 30, 45, 60];

  Future<void> _save() async {
    final activity = _activity;
    if (activity == null || _saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final entry = await ref.read(moveProvider.notifier).log(minutes: _minutes, activity: activity, intensity: _intensity);
    if (!mounted) return;
    if (entry == null) {
      setState(() {
        _saving = false;
        _failed = true;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  String _intensityLabel(String key) => switch (key) {
        'easy' => tr('Easy'),
        'hard' => tr('Hard'),
        _ => tr('Moderate'),
      };

  @override
  Widget build(BuildContext context) {
    final choices = ref.watch(activityChoicesProvider);
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Log something else'), style: AppType.title()),
          const SizedBox(height: 4),
          Text(tr('Anything counts. Pick what you did.'), style: AppType.body(size: 14, color: TrackerColors.textSecondary)),
          const SizedBox(height: 14),
          choices.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CupertinoActivityIndicator())),
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(tr("Couldn't load the list. Check your connection and try again."),
                  key: const ValueKey('log_error'), style: AppType.body(size: 14, color: TrackerColors.textSecondary)),
            ),
            data: (list) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in list)
                  _Chip(
                    key: ValueKey('activity_${a.key}'),
                    label: '${a.slice.emoji} ${a.label}',
                    selected: _activity == a.key,
                    onTap: () => setState(() => _activity = a.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(tr('How long?'), style: AppType.sectionLabel()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _presets)
                _Chip(
                  key: ValueKey('minutes_$m'),
                  label: tr('{n} min', {'n': '$m'}),
                  selected: _minutes == m,
                  onTap: () => setState(() => _minutes = m),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Step(
                key: const ValueKey('minutes_minus'),
                icon: CupertinoIcons.minus,
                onTap: _minutes > 5 ? () => setState(() => _minutes -= 5) : null,
              ),
              Expanded(
                child: Text(tr('{n} min', {'n': '$_minutes'}),
                    key: const ValueKey('minutes_value'), textAlign: TextAlign.center, style: AppType.title()),
              ),
              _Step(
                key: const ValueKey('minutes_plus'),
                icon: CupertinoIcons.plus,
                onTap: _minutes < 600 ? () => setState(() => _minutes += 5) : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tr('How did it feel?'), style: AppType.sectionLabel()),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final k in const ['easy', 'moderate', 'hard']) ...[
                Expanded(
                  child: _Chip(
                    key: ValueKey('intensity_$k'),
                    label: _intensityLabel(k),
                    selected: _intensity == k,
                    onTap: () => setState(() => _intensity = k),
                    center: true,
                  ),
                ),
                if (k != 'hard') const SizedBox(width: 8),
              ],
            ],
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(tr("Couldn't save. Try again"), key: const ValueKey('log_failed'), style: AppType.body(size: 14, color: TrackerColors.error)),
          ],
          const SizedBox(height: 18),
          AppButton(
            key: const ValueKey('log_save'),
            label: tr('Add to my week'),
            loading: _saving,
            onPressed: _activity == null ? null : _save,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.selected, required this.onTap, this.center = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        alignment: center ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? TrackerColors.accentWash : TrackerColors.glassFill,
          borderRadius: BorderRadius.circular(AppRadii.small),
          border: Border.all(color: selected ? TrackerColors.accentStartText : TrackerColors.border),
        ),
        child: Text(label, style: AppType.body(size: 14, color: selected ? TrackerColors.accentStartText : TrackerColors.textPrimary)),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: TrackerColors.glassFill, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: TrackerColors.textPrimary),
        ),
      ),
    );
  }
}
