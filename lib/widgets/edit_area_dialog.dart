import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/utils/spot_appearance.dart';
import 'package:myroad/widgets/icon_color_picker.dart';
import 'package:myroad/widgets/dialogs.dart';

typedef EditAreaResult = ({
  String name,
  String type,
  int estimatedDurationMinutes,
  String review,
  int? rating,
  int? iconCode,
});

class EditAreaDialog extends ConsumerStatefulWidget {
  final Area area;
  final String regionId;
  final VoidCallback? onDeleted;
  const EditAreaDialog({
    super.key,
    required this.area,
    required this.regionId,
    this.onDeleted,
  });

  @override
  ConsumerState<EditAreaDialog> createState() => _EditAreaDialogState();
}

class _EditAreaDialogState extends ConsumerState<EditAreaDialog> {
  late AreaType _type;
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _reviewController;
  int? _rating;
  int? _iconCode;

  @override
  void initState() {
    super.initState();
    _type = AreaType.fromString(widget.area.type);
    _nameController = TextEditingController(text: widget.area.name);
    _durationController = TextEditingController(
      text: widget.area.estimatedDurationMinutes.toString(),
    );
    _reviewController = TextEditingController(text: widget.area.review ?? '');
    _rating = widget.area.rating;
    _iconCode = widget.area.iconCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  String _typeLabel(AppLocalizations l10n, AreaType t) => switch (t) {
    AreaType.country => l10n.areaTypeCountry,
    AreaType.city => l10n.areaTypeCity,
    AreaType.neighborhood => l10n.areaTypeNeighborhood,
  };

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (
      name: name,
      type: _type.value,
      estimatedDurationMinutes:
          int.tryParse(_durationController.text) ??
          widget.area.estimatedDurationMinutes,
      review: _reviewController.text,
      rating: _rating,
      iconCode: _iconCode,
    ));
  }

  Future<void> _move() async {
    final target = await showRegionPicker(
      context,
      ref,
      exclude: widget.regionId,
    );
    if (target == null || !mounted) return;
    await ref.read(areaDaoProvider).moveToRegion(widget.area.id, target.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _copy() async {
    final target = await showRegionPicker(context, ref);
    if (target == null || !mounted) return;
    await ref
        .read(areaDaoProvider)
        .copyToRegion(widget.area.id, target.id, ref.read(spotDaoProvider));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    if (await showConfirmDialog(
      context,
      title: l10n.delete,
      content: l10n.deleteAreaConfirm(widget.area.name),
    )) {
      await ref.read(areaDaoProvider).deleteArea(widget.area.id);
      if (mounted) Navigator.pop(context);
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.editArea)),
          IconButton(
            onPressed: _move,
            tooltip: l10n.moveToRegion,
            icon: const Icon(Icons.drive_file_move_outline),
          ),
          IconButton(
            onPressed: _copy,
            tooltip: l10n.copyToRegion,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            onPressed: _delete,
            tooltip: l10n.delete,
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconPickerButton(
                    current: areaIcon(_type.value, iconCode: _iconCode),
                    color: areaColor(_type.value),
                    tooltip: l10n.icon,
                    onPicked: (icon) =>
                        setState(() => _iconCode = icon?.codePoint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        label: requiredLabel(l10n.areaName),
                      ),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AreaType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n.areaType,
                  border: const OutlineInputBorder(),
                ),
                items: AreaType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(_typeLabel(l10n, t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: l10n.estimatedDuration,
                  prefixIcon: const Icon(Icons.timer_outlined),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reviewController,
                      decoration: InputDecoration(
                        hintText: l10n.writeReview,
                        prefixIcon: const Icon(Icons.rate_review_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.thumb_up,
                          color: _rating == 1 ? Colors.green : null,
                        ),
                        tooltip: l10n.thumbUp,
                        onPressed: () =>
                            setState(() => _rating = _rating == 1 ? null : 1),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.thumb_down,
                          color: _rating == -1 ? Colors.red : null,
                        ),
                        tooltip: l10n.thumbDown,
                        onPressed: () =>
                            setState(() => _rating = _rating == -1 ? null : -1),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
