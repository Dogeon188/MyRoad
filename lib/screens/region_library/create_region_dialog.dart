import 'package:flutter/material.dart';
import 'package:myroad/l10n/app_localizations.dart';

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
            decoration: InputDecoration(labelText: l10n.regionName, prefixIcon: const Icon(Icons.map_outlined)),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: InputDecoration(labelText: l10n.regionDescription, prefixIcon: const Icon(Icons.description_outlined)),
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
            });
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
