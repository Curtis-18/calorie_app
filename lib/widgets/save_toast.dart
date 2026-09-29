import 'package:flutter/cupertino.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';

enum SaveToastState { initial, loading, success }

/// Floating glass pill used to confirm saves.
class SaveToast extends StatelessWidget {
  const SaveToast({
    super.key,
    required this.state,
    this.onReset,
    this.onSave,
  });

  final SaveToastState state;
  final VoidCallback? onReset;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final isLoading = state == SaveToastState.loading;
    final isSuccess = state == SaveToastState.success;
    final accent = isSuccess ? TrackerColors.success : TrackerColors.accentStart;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: const Cubic(0.34, 1.56, 0.64, 1),
      builder: (context, scale, child) =>
          Transform.translate(offset: Offset(0, 12 * (1 - scale)), child: child),
      child: FrostedGlass(
        blur: 20,
        opacity: 0.92,
        tint: TrackerColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: TrackerColors.alpha(accent, 0.28), width: 1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TrackerColors.alpha(accent, 0.16),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: AppDecor.glow(accent, blur: 10, opacity: 0.35),
                ),
                child: isLoading
                    ? CupertinoActivityIndicator(radius: 7, color: accent)
                    : Icon(
                        isSuccess ? CupertinoIcons.check_mark : CupertinoIcons.exclamationmark,
                        size: 13,
                        color: accent,
                      ),
              ),
              const SizedBox(width: 10),
              Text(
                isLoading
                    ? 'Saving…'
                    : isSuccess
                        ? 'Saved'
                        : 'Unsaved changes',
                style: AppType.caption(color: TrackerColors.textPrimary, size: 13),
              ),
              if (state == SaveToastState.initial) ...[
                const SizedBox(width: AppSpacing.md),
                AppButton(
                  label: 'Reset',
                  style: AppButtonStyle.quiet,
                  expand: false,
                  height: 30,
                  onPressed: onReset,
                ),
                const SizedBox(width: AppSpacing.xs),
                AppButton(
                  label: 'Save',
                  expand: false,
                  height: 30,
                  onPressed: onSave,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
