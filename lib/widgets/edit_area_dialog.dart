import 'package:flutter/material.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/utils/spot_appearance.dart';
import 'package:myroad/widgets/icon_color_picker.dart';

typedef EditAreaResult = ({
  String type,
  int estimatedDurationMinutes,
  String review,
  int? rating,
  int? iconCode,
  int? colorValue,
});

class EditAreaDialog extends StatefulWidget {
  final Area area;
  const EditAreaDialog({super.key, required this.area});

  @override
  State<EditAreaDialog> createState() => _EditAreaDialogState();
}

class _EditAreaDialogState extends State<EditAreaDialog> {
  late AreaType _type;
  late final TextEditingController _durationController;
  late final TextEditingController _reviewController;
  int? _rating;
  int? _iconCode;
  int? _colorValue;

  @override
  void initState() {
    super.initState();
    _type = AreaType.fromString(widget.area.type);
    _durationController = TextEditingController(
      text: widget.area.estimatedDurationMinutes.toString(),
    );
    _reviewController = TextEditingController(text: widget.area.review ?? '');
    _rating = widget.area.rating;
    _iconCode = widget.area.iconCode;
    _colorValue = widget.area.colorValue;
  }

  @override
  void dispose() {
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
    Navigator.pop(context, (
      type: _type.value,
      estimatedDurationMinutes:
          int.tryParse(_durationController.text) ??
          widget.area.estimatedDurationMinutes,
      review: _reviewController.text,
      rating: _rating,
      iconCode: _iconCode,
      colorValue: _colorValue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.editArea),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Row(
              children: [
                Text(l10n.icon, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: 8),
                IconPickerButton(
                  current: areaIcon(_type.value, iconCode: _iconCode),
                  color: areaColor(_type.value, colorValue: _colorValue),
                  onPicked: (icon) =>
                      setState(() => _iconCode = icon?.codePoint),
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.color,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 8),
                ColorPickerButton(
                  current: areaColor(_type.value, colorValue: _colorValue),
                  onPicked: (color) =>
                      setState(() => _colorValue = color?.toARGB32()),
                ),
              ],
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
                      onPressed: () =>
                          setState(() => _rating = _rating == 1 ? null : 1),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.thumb_down,
                        color: _rating == -1 ? Colors.red : null,
                      ),
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
