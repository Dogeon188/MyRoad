import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/json_export_service.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/widgets/dialogs.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/screens/region_library/spot_search_screen.dart';
import 'package:myroad/widgets/name_input_dialog.dart';
import 'package:myroad/widgets/spots_map.dart';

class RegionDetailScreen extends ConsumerStatefulWidget {
  final String regionId;

  const RegionDetailScreen({super.key, required this.regionId});

  @override
  ConsumerState<RegionDetailScreen> createState() => _RegionDetailScreenState();
}

class _RegionDetailScreenState extends ConsumerState<RegionDetailScreen> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);
    final areaDao = ref.watch(areaDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder(
          future: regionDao.getById(widget.regionId),
          builder: (context, snapshot) => Text(snapshot.data?.name ?? ''),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _reordering = !_reordering),
            icon: Icon(_reordering ? Icons.check : Icons.reorder),
            label: Text(_reordering ? l10n.done : l10n.editOrder),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => switch (action) {
              'rename' => _rename(context),
              'currency' => _changeCurrency(context),
              'export' => _exportJson(context),
              'delete' => _confirmDelete(context),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
              PopupMenuItem(value: 'currency', child: Text(l10n.currency)),
              PopupMenuItem(value: 'export', child: Text(l10n.exportJson)),
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteRegion)),
            ],
          ),
        ],
      ),
      body: StreamBuilder(
        stream: areaDao.watchByRegion(widget.regionId),
        builder: (context, snapshot) {
          final areas = snapshot.data ?? [];
          if (areas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.nAreas(0)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _addArea(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addArea),
                  ),
                ],
              ),
            );
          }

          if (_reordering) {
            return ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: areas.length,
              onReorderItem: (oldIndex, newIndex) {
                final ids = areas.map((a) => a.id).toList();
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                areaDao.reorder(ids);
              },
              itemBuilder: (context, index) {
                final area = areas[index];
                return Card(
                  key: ValueKey(area.id),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                    title: Text(area.name),
                  ),
                );
              },
            );
          }

          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _SpotsMapSection(regionId: widget.regionId, areas: areas),
              for (final area in areas)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(area.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => _LibraryAreaDetailPage(
                        areaId: area.id, areaName: area.name, regionId: widget.regionId,
                      )),
                    ),
                    onLongPress: () => _showAreaActions(context, area),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addArea(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAreaActions(BuildContext context, Area area) async {
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
          builder: (_) => NameInputDialog(title: l10n.rename, labelText: l10n.areaName, initialValue: area.name),
        );
        if (name != null) areaDao.updateArea(area.id, name: name);
      case 'move':
        final target = await _pickRegion(context, exclude: widget.regionId);
        if (target != null) await areaDao.moveToRegion(area.id, target.id);
      case 'copy':
        final target = await _pickRegion(context);
        if (target != null) await areaDao.copyToRegion(area.id, target.id, ref.read(spotDaoProvider));
      case 'delete':
        if (await showConfirmDialog(context, title: l10n.delete, content: l10n.deleteAreaConfirm(area.name))) {
          areaDao.deleteArea(area.id);
        }
    }
  }

  Future<Region?> _pickRegion(BuildContext context, {String? exclude}) async {
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

  Future<void> _exportJson(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;
    final db = ref.read(appDatabaseProvider);
    final region = await ref.read(regionDaoProvider).getById(widget.regionId);
    if (region == null) return;
    final json = await JsonExportService(db).exportRegion(widget.regionId);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(json);
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${region.name}.myroad.json'));
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }

  Future<void> _rename(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final region = await ref.read(regionDaoProvider).getById(widget.regionId);
    if (region == null || !context.mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameInputDialog(title: l10n.rename, labelText: l10n.regionName, initialValue: region.name),
    );
    if (name != null) {
      await ref.read(regionDaoProvider).updateRegion(widget.regionId, name: name);
    }
  }

  Future<void> _changeCurrency(BuildContext context) async {
    final region = await ref.read(regionDaoProvider).getById(widget.regionId);
    if (region == null || !context.mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.currency),
        children: currencySymbols.keys.map((code) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, code),
          child: Text('$code (${currencySymbol(code)})'),
        )).toList(),
      ),
    );
    if (selected != null) {
      await ref.read(regionDaoProvider).updateRegion(widget.regionId, currency: selected);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final region = await ref.read(regionDaoProvider).getById(widget.regionId);
    if (region == null || !context.mounted) return;
    if (await showConfirmDialog(context, title: l10n.deleteRegion, content: l10n.deleteRegionConfirm(region.name))) {
      await ref.read(regionDaoProvider).deleteRegion(widget.regionId);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _addArea(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameInputDialog(title: l10n.addArea, labelText: l10n.areaName),
    );
    if (name != null) {
      await ref.read(areaDaoProvider).insertArea(name, 'city', regionId: widget.regionId);
    }
  }
}

class _LibraryAreaDetailPage extends ConsumerStatefulWidget {
  final String areaId;
  final String areaName;
  final String regionId;
  const _LibraryAreaDetailPage({required this.areaId, required this.areaName, required this.regionId});

  @override
  ConsumerState<_LibraryAreaDetailPage> createState() => _LibraryAreaDetailPageState();
}

class _LibraryAreaDetailPageState extends ConsumerState<_LibraryAreaDetailPage> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.areaName),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _reordering = !_reordering),
            icon: Icon(_reordering ? Icons.check : Icons.reorder),
            label: Text(_reordering ? l10n.done : l10n.editOrder),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: spotDao.watchByArea(widget.areaId),
        builder: (context, snapshot) {
          final spots = snapshot.data ?? [];
          if (spots.isEmpty) return Center(child: Text(l10n.nSpots(0)));

          if (_reordering) {
            return ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: spots.length,
              onReorderItem: (oldIndex, newIndex) {
                final ids = spots.map((s) => s.id).toList();
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                spotDao.reorder(ids);
              },
              itemBuilder: (context, index) {
                final spot = spots[index];
                return Card(
                  key: ValueKey(spot.id),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                    title: Text(spot.name),
                  ),
                );
              },
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: spots.map((spot) => Dismissible(
              key: ValueKey(spot.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Theme.of(context).colorScheme.error,
                child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
              ),
              confirmDismiss: (_) => showConfirmDialog(context, content: l10n.deleteSpotConfirm(spot.name)),
              onDismissed: (_) => spotDao.deleteSpot(spot.id),
              child: ListTile(
                leading: Icon(_spotTypeIcon(spot.type)),
                title: Text(spot.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (spot.notes.isNotEmpty)
                      Text(spot.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (spot.address.isNotEmpty)
                      Text(spot.address, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150), fontSize: 12)),
                  ],
                ),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: spot.id)),
                ),
                onLongPress: () => _showSpotActions(context, spot),
              ),
            )).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => SpotSearchScreen(areaId: widget.areaId)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _spotTypeIcon(String type) {
    return switch (type) {
      'restaurant' => Icons.restaurant,
      'hotel' => Icons.hotel,
      'online' => Icons.videocam,
      'custom' => Icons.star_outline,
      _ => Icons.place,
    };
  }

  Future<void> _showSpotActions(BuildContext context, Spot spot) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(l10n.moveToArea),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.copyToArea),
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
    if (action == 'delete') {
      if (await showConfirmDialog(context, content: l10n.deleteSpotConfirm(spot.name))) {
        ref.read(spotDaoProvider).deleteSpot(spot.id);
      }
      return;
    }
    final target = await _pickArea(context, exclude: action == 'move' ? widget.areaId : null);
    if (target == null) return;
    final spotDao = ref.read(spotDaoProvider);
    if (action == 'move') {
      await spotDao.moveToArea(spot.id, target.id);
    } else {
      await spotDao.copyToArea(spot.id, target.id);
    }
  }

  Future<Area?> _pickArea(BuildContext context, {String? exclude}) async {
    final l10n = AppLocalizations.of(context)!;
    final regions = await ref.read(regionDaoProvider).watchAll().first;
    final areaDao = ref.read(areaDaoProvider);
    final children = <Widget>[];
    for (final region in regions) {
      final areas = await areaDao.watchByRegion(region.id).first;
      final filtered = exclude != null ? areas.where((a) => a.id != exclude).toList() : areas;
      if (filtered.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
        child: Text(region.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
      ));
      for (final a in filtered) {
        children.add(SimpleDialogOption(
          onPressed: () => Navigator.pop(context, a),
          child: Text(a.name),
        ));
      }
    }
    if (children.isEmpty || !context.mounted) return null;
    return showDialog<Area>(
      context: context,
      builder: (_) => SimpleDialog(title: Text(l10n.selectArea), children: children),
    );
  }
}

class _SpotsMapSection extends ConsumerWidget {
  final String regionId;
  final List<dynamic> areas;

  const _SpotsMapSection({required this.regionId, required this.areas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SpotsMap.supported) return const SizedBox.shrink();

    final spotDao = ref.watch(spotDaoProvider);
    final allSpotStreams = areas.map((a) => spotDao.watchByArea(a.id));

    return StreamBuilder(
      stream: Stream.fromFuture(
        Future.wait(allSpotStreams.map((s) => s.first)),
      ),
      builder: (context, snapshot) {
        final allSpots = (snapshot.data ?? [])
            .expand((spots) => spots)
            .where((s) => s.lat != null && s.lng != null)
            .map((s) => MapSpot(
                  id: s.id,
                  name: s.name,
                  type: s.type,
                  lat: s.lat!,
                  lng: s.lng!,
                ))
            .toList();
        return SpotsMap(
          spots: allSpots,
          onSpotTapped: (id) => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: id)),
          ),
        );
      },
    );
  }
}
