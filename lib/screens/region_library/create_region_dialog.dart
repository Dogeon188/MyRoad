import 'package:flutter/material.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/utils/spot_appearance.dart';
import 'package:myroad/widgets/dialogs.dart';
import 'package:myroad/widgets/icon_color_picker.dart';

class CreateRegionDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final String title;

  const CreateRegionDialog({
    super.key,
    this.initialName,
    this.initialDescription,
    required this.title,
  });

  @override
  State<CreateRegionDialog> createState() => _CreateRegionDialogState();
}

class _CreateRegionDialogState extends State<CreateRegionDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  int? _iconCode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              label: requiredLabel(l10n.regionName),
              prefixIcon: const Icon(Icons.map_outlined),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: l10n.regionDescription,
              prefixIcon: const Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.icon, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 8),
              IconPickerButton(
                current: regionIcon(iconCode: _iconCode),
                color: regionColor(),
                onPicked: (icon) => setState(() => _iconCode = icon?.codePoint),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, {
              'name': name,
              'description': _descController.text.trim(),
              'iconCode': _iconCode,
            });
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
