import 'package:flutter/material.dart';

/// Shows a time picker. If [current] is set, offers a "Clear" option.
/// Returns the picked time in minutes, or -1 to clear, or null for no change.
Future<int?> pickOrClearTime(
  BuildContext context, {
  int? current,
  TimeOfDay? defaultTime,
}) async {
  if (current != null) {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(
                '${(current ~/ 60).toString().padLeft(2, '0')}:${(current % 60).toString().padLeft(2, '0')}',
              ),
              subtitle: const Text('Tap to change'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.red),
              title: const Text('Clear time'),
              onTap: () => Navigator.pop(ctx, 'clear'),
            ),
          ],
        ),
      ),
    );
    if (action == 'clear') return -1;
    if (action != 'edit') return null;
    if (!context.mounted) return null;
  }

  final picked = await showTimePicker(
    context: context,
    initialTime: current != null
        ? TimeOfDay(hour: current ~/ 60, minute: current % 60)
        : defaultTime ?? const TimeOfDay(hour: 9, minute: 0),
  );
  if (picked == null) return null;
  return picked.hour * 60 + picked.minute;
}
