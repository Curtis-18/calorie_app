import 'package:flutter/cupertino.dart';
import '../theme/tracker_colors.dart';

enum SaveToastState { initial, loading, success }

class SaveToast extends StatelessWidget {
  final SaveToastState state;
  final VoidCallback? onReset;
  final VoidCallback? onSave;

  const SaveToast({
    super.key,
    required this.state,
    this.onReset,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: TrackerColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: TrackerColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == SaveToastState.loading)
            const CupertinoActivityIndicator(),
          if (state == SaveToastState.success)
            const Icon(CupertinoIcons.check_mark, color: TrackerColors.success, size: 18),
          const SizedBox(width: 8),
          Text(
            state == SaveToastState.loading ? 'Saving...' : 
            state == SaveToastState.success ? 'Saved!' : 'Unsaved changes',
            style: CupertinoTheme.of(context).textTheme.textStyle,
          ),
          if (state == SaveToastState.initial) ...[
            const SizedBox(width: 12),
            CupertinoButton(onPressed: onReset, child: const Text('Reset')),
            CupertinoButton.filled(
              onPressed: onSave,
              child: const Text('Save'),
            ),
          ]
        ],
      ),
    );
  }
}
