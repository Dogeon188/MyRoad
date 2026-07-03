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

  final entries = <RegionAreas>[];
  for (final region in regions) {
    final areas = await areaDao.watchByRegion(region.id).first;
    final filtered = exclude != null ? areas.where((a) => a.id != exclude).toList() : areas;
    if (filtered.isNotEmpty) entries.add(RegionAreas(region, filtered));
  }
  if (entries.isEmpty || !context.mounted) return null;

  return showAreaPickerDialog(context, title: l10n.selectArea, entries: entries);
}

class RegionAreas {
  final Region region;
  final List<Area> areas;
  RegionAreas(this.region, this.areas);
}

Future<Area?> showAreaPickerDialog(
  BuildContext context, {
  required String title,
  required List<RegionAreas> entries,
}) {
  return showDialog<Area>(
    context: context,
    builder: (_) => _AreaPickerDialog(title: title, entries: entries),
  );
}

class _AreaPickerDialog extends StatefulWidget {
  final String title;
  final List<RegionAreas> entries;

  const _AreaPickerDialog({required this.title, required this.entries});

  @override
  State<_AreaPickerDialog> createState() => _AreaPickerDialogState();
}

class _AreaPickerDialogState extends State<_AreaPickerDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RegionAreas> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.entries;
    return widget.entries
        .map((e) {
          final regionMatches = e.region.name.toLowerCase().contains(query);
          final areas = regionMatches
              ? e.areas
              : e.areas.where((a) => a.name.toLowerCase().contains(query)).toList();
          return RegionAreas(e.region, areas);
        })
        .where((e) => e.areas.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filtered;
    final searching = _query.trim().isNotEmpty;

    return SimpleDialog(
      title: Text(widget.title),
      children: [
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(l10n.noResults),
          )
        else
          ...filtered.map((e) => ExpansionTile(
                key: ValueKey(e.region.id),
                // ponytail: all expanded by default, collapse when list is long; searching always expands matches
                initiallyExpanded: searching || widget.entries.length <= 3,
                title: Text(e.region.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
                children: e.areas.map((a) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, a),
                      child: Text(a.name),
                    )).toList(),
              )),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.filterAreas,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                      }),
                    ),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
      ],
    );
  }
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
