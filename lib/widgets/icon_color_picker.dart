import 'package:flutter/material.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/utils/spot_appearance.dart';

const _pickerDialogWidth = 300.0;

class IconPickerButton extends StatelessWidget {
  final IconData current;
  final Color color;
  final void Function(IconData?) onPicked;
  final String? tooltip;
  const IconPickerButton({
    super.key,
    required this.current,
    required this.color,
    required this.onPicked,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        // Returns codePoint, or 0 for reset, or null for barrier dismiss
        final result = await showDialog<int>(
          context: context,
          builder: (_) => _IconPickerDialog(current: current),
        );
        if (!context.mounted || result == null) return;
        onPicked(
          result == 0 ? null : IconData(result, fontFamily: 'MaterialIcons'),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(current, color: color, size: 24),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

class _IconPickerDialog extends StatelessWidget {
  final IconData current;
  const _IconPickerDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.icon),
      content: SizedBox(
        width: _pickerDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: spotIconChoices
                  .map(
                    (icon) => IconButton(
                      icon: Icon(icon),
                      style: icon == current
                          ? IconButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                            )
                          : null,
                      onPressed: () => Navigator.pop(context, icon.codePoint),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: Text(l10n.resetToDefault),
            ),
          ],
        ),
      ),
    );
  }
}
