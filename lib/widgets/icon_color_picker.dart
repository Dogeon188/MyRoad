import 'package:flutter/material.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/utils/spot_appearance.dart';

const _pickerDialogWidth = 300.0;
const _colorSwatchSize = 40.0;

class IconPickerButton extends StatelessWidget {
  final IconData current;
  final Color color;
  final void Function(IconData?) onPicked;
  const IconPickerButton({
    super.key,
    required this.current,
    required this.color,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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

class ColorPickerButton extends StatelessWidget {
  final Color current;
  final void Function(Color?) onPicked;
  const ColorPickerButton({
    super.key,
    required this.current,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        // Returns ARGB32 int, or 0 for reset, or null for barrier dismiss
        final result = await showDialog<int>(
          context: context,
          builder: (_) => _ColorPickerDialog(current: current),
        );
        if (!context.mounted || result == null) return;
        onPicked(result == 0 ? null : Color(result));
      },
      child: Container(
        width: _colorSwatchSize,
        height: _colorSwatchSize,
        decoration: BoxDecoration(
          color: current,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  final Color current;
  const _ColorPickerDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.color),
      content: SizedBox(
        width: _pickerDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: spotColorChoices
                  .map(
                    (color) => InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(context, color.toARGB32()),
                      child: Container(
                        width: _colorSwatchSize,
                        height: _colorSwatchSize,
                        decoration: BoxDecoration(
                          color: color,
                          border: color == current
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 3,
                                )
                              : Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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
