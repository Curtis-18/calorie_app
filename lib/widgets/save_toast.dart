import 'package:flutter/material.dart';
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
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          if (state == SaveToastState.success)
            const Icon(Icons.check, color: TrackerColors.success, size: 18),
          const SizedBox(width: 8),
          Text(
            state == SaveToastState.loading ? 'Saving...' : 
            state == SaveToastState.success ? 'Saved!' : 'Unsaved changes',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (state == SaveToastState.initial) ...[
            const SizedBox(width: 12),
            TextButton(onPressed: onReset, child: const Text('Reset')),
            ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
              child: const Text('Save'),
            ),
          ]
        ],
      ),
    );
  }
}
