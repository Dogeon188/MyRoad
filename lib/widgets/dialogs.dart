import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/widgets/name_input_dialog.dart';

Widget requiredLabel(String text, {TextStyle? style}) => Text.rich(
  TextSpan(text: text, children: [
    TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: (style?.fontSize ?? 16) * 0.9)),
  ]),
  style: style,
);

Future<bool> showConfirmDialog(BuildContext context, {String? title, required String content}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return result == true;
}

Future<Area?> showAreaPicker(BuildContext context, WidgetRef ref, {String? exclude}) async {
  final l10n = AppLocalizations.of(context)!;
  final regions = await ref.read(regionDaoProvider).watchAll().first;
  final areaDao = ref.read(areaDaoProvider);

  final entries = <_RegionAreas>[];
  for (final region in regions) {
    final areas = await areaDao.watchByRegion(region.id).first;
    final filtered = exclude != null ? areas.where((a) => a.id != exclude).toList() : areas;
    if (filtered.isNotEmpty) entries.add(_RegionAreas(region, filtered));
  }
  if (entries.isEmpty || !context.mounted) return null;

  return showDialog<Area>(
    context: context,
    builder: (_) => SimpleDialog(
      title: Text(l10n.selectArea),
      children: entries.map((e) => ExpansionTile(
        // ponytail: all expanded by default, collapse when list is long
        initiallyExpanded: entries.length <= 3,
        title: Text(e.region.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
        children: e.areas.map((a) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, a),
          child: Text(a.name),
        )).toList(),
      )).toList(),
    ),
  );
}

class _RegionAreas {
  final Region region;
  final List<Area> areas;
  _RegionAreas(this.region, this.areas);
}

Future<Region?> showRegionPicker(BuildContext context, WidgetRef ref, {String? exclude}) async {
  final l10n = AppLocalizations.of(context)!;
  final regions = await ref.read(regionDaoProvider).watchAll().first;
  final filtered = exclude != null ? regions.where((r) => r.id != exclude).toList() : regions;
  if (filtered.isEmpty || !context.mounted) return null;
  return showDialog<Region>(
    context: context,
    builder: (_) => SimpleDialog(
      title: Text(l10n.selectRegion),
      children: filtered.map((r) => SimpleDialogOption(
        onPressed: () => Navigator.pop(context, r),
        child: Text(r.name),
      )).toList(),
    ),
  );
}

Future<void> showAreaActions(
  BuildContext context,
  WidgetRef ref, {
  required String areaId,
  required String areaName,
  required String regionId,
  ValueChanged<String>? onRenamed,
  VoidCallback? onDeleted,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(l10n.rename),
            onTap: () => Navigator.pop(context, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: Text(l10n.moveToRegion),
            onTap: () => Navigator.pop(context, 'move'),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(l10n.copyToRegion),
            onTap: () => Navigator.pop(context, 'copy'),
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            title: Text(l10n.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final areaDao = ref.read(areaDaoProvider);
  switch (action) {
    case 'rename':
      final name = await showDialog<String>(
        context: context,
        builder: (_) => NameInputDialog(title: l10n.rename, labelText: l10n.areaName, initialValue: areaName),
      );
      if (name != null) {
        await areaDao.updateArea(areaId, name: name);
        onRenamed?.call(name);
      }
    case 'move':
      final target = await showRegionPicker(context, ref, exclude: regionId);
      if (target != null) await areaDao.moveToRegion(areaId, target.id);
    case 'copy':
      final target = await showRegionPicker(context, ref);
      if (target != null) await areaDao.copyToRegion(areaId, target.id, ref.read(spotDaoProvider));
    case 'delete':
      if (await showConfirmDialog(context, title: l10n.delete, content: l10n.deleteAreaConfirm(areaName))) {
        await areaDao.deleteArea(areaId);
        onDeleted?.call();
      }
  }
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
