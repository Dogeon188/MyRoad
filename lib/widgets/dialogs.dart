import 'package:flutter/material.dart';
import 'package:myroad/l10n/app_localizations.dart';

Future<bool> showConfirmDialog(BuildContext context, {String? title, required String content}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
      ],
    ),
  );
  return result == true;
}

Future<DateTime?> showTripDatePicker(BuildContext context, {DateTime? initialDate}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 10),
    initialDate: initialDate ?? now,
  );
}
