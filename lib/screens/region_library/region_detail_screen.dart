import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/widgets/spots_map.dart';
import 'package:myroad/utils/spot_appearance.dart';
import 'package:myroad/widgets/icon_color_picker.dart';
import 'package:drift/drift.dart' show Value;

class RegionDetailScreen extends ConsumerStatefulWidget {
  final String regionId;
  final String? tripId;

  const RegionDetailScreen({super.key, required this.regionId, this.tripId});

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
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.editRegion,
            onPressed: () => _edit(context),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: Icon(
                      areaIcon(area.type, iconCode: area.iconCode),
                      color: areaColor(area.type),
                    ),
                    title: Text(area.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LibraryAreaDetailPage(
                          areaId: area.id,
                          areaName: area.name,
                          regionId: widget.regionId,
                          tripId: widget.tripId,
                        ),
                      ),
                    ),
                    onLongPress: () => showAreaActions(
                      context,
                      ref,
                      areaId: area.id,
                      regionId: widget.regionId,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addArea,
        onPressed: () => _addArea(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final region = await ref.read(regionDaoProvider).getById(widget.regionId);
    if (region == null || !context.mounted) return;
    final result = await showDialog<EditRegionResult>(
      context: context,
      builder: (_) => _EditRegionDialog(region: region),
    );
    if (result != null) {
      await ref
          .read(regionDaoProvider)
          .updateRegion(
            widget.regionId,
            name: result.name,
            currency: result.currency,
            iconCode: Value(result.iconCode),
          );
    }
  }

  Future<void> _addArea(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          NameInputDialog(title: l10n.addArea, labelText: l10n.areaName),
    );
    if (name != null) {
      await ref
          .read(areaDaoProvider)
          .insertArea(name, 'city', regionId: widget.regionId);
    }
  }
}

class LibraryAreaDetailPage extends ConsumerStatefulWidget {
  final String areaId;
  final String areaName;
  final String regionId;
  final String? tripId;
  const LibraryAreaDetailPage({
    super.key,
    required this.areaId,
    required this.areaName,
    required this.regionId,
    this.tripId,
  });

  @override
  ConsumerState<LibraryAreaDetailPage> createState() =>
      LibraryAreaDetailPageState();
}

class LibraryAreaDetailPageState extends ConsumerState<LibraryAreaDetailPage> {
  bool _reordering = false;
  late String _areaName = widget.areaName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_areaName),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _reordering = !_reordering),
            icon: Icon(_reordering ? Icons.check : Icons.reorder),
            label: Text(_reordering ? l10n.done : l10n.editOrder),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.moreOptions,
            onPressed: () => showAreaActions(
              context,
              ref,
              areaId: widget.areaId,
              regionId: widget.regionId,
              onRenamed: (name) => setState(() => _areaName = name),
              onDeleted: () => Navigator.pop(context),
            ),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(spot.name),
                  ),
                );
              },
            );
          }

          final tripId = widget.tripId;
          if (tripId != null) {
            final itineraryDao = ItineraryDao(ref.watch(appDatabaseProvider));
            return StreamBuilder<Set<String>>(
              stream: itineraryDao.watchSkippedSpots(tripId),
              builder: (context, skippedSnap) {
                final skipped = skippedSnap.data ?? {};
                return _buildSpotList(context, spots, skipped: skipped);
              },
            );
          }
          return _buildSpotList(context, spots);
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addSpot,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpotSearchScreen(areaId: widget.areaId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSpotList(
    BuildContext context,
    List<Spot> spots, {
    Set<String> skipped = const {},
  }) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: spots
          .map(
            (spot) => Opacity(
              key: ValueKey(spot.id),
              opacity: skipped.contains(spot.id) ? 0.4 : 1.0,
              child: Dismissible(
                key: ValueKey(spot.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Theme.of(context).colorScheme.error,
                  child: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                confirmDismiss: (_) => showConfirmDialog(
                  context,
                  content: l10n.deleteSpotConfirm(spot.name),
                ),
                onDismissed: (_) => spotDao.deleteSpot(spot.id),
                child: ListTile(
                  leading: Icon(
                    spotIcon(spot.type, iconCode: spot.iconCode),
                    color: spotColor(spot.type),
                  ),
                  title: Text(spot.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (spot.price != null && spot.price!.isNotEmpty)
                        Text(
                          spot.price!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      if (spot.notes.isNotEmpty)
                        Text(
                          spot.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (spot.address.isNotEmpty)
                        Text(
                          spot.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withAlpha(150),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpotDetailScreen(spotId: spot.id),
                    ),
                  ),
                  onLongPress: () => _showSpotActions(
                    context,
                    spot,
                    skipped: skipped.contains(spot.id),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _showSpotActions(
    BuildContext context,
    Spot spot, {
    bool skipped = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final tripId = widget.tripId;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tripId != null)
              ListTile(
                leading: Icon(
                  skipped ? Icons.visibility : Icons.visibility_off,
                ),
                title: Text(skipped ? l10n.unskipSpot : l10n.skipSpot),
                onTap: () => Navigator.pop(context, 'skip'),
              ),
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
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'skip') {
      final dao = ItineraryDao(ref.read(appDatabaseProvider));
      await dao.toggleSkipped(tripId!, spot.id);
    } else if (action == 'delete') {
      if (await showConfirmDialog(
        context,
        content: l10n.deleteSpotConfirm(spot.name),
      )) {
        ref.read(spotDaoProvider).deleteSpot(spot.id);
      }
    } else {
      final target = await showAreaPicker(
        context,
        ref,
        exclude: action == 'move' ? widget.areaId : null,
      );
      if (target == null) return;
      final spotDao = ref.read(spotDaoProvider);
      if (action == 'move') {
        await spotDao.moveToArea(spot.id, target.id);
      } else {
        await spotDao.copyToArea(spot.id, target.id);
      }
    }
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
            .map(
              (s) => MapSpot(
                id: s.id,
                name: s.name,
                type: s.type,
                lat: s.lat!,
                lng: s.lng!,
              ),
            )
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

typedef EditRegionResult = ({String name, String currency, int? iconCode});

class _EditRegionDialog extends ConsumerStatefulWidget {
  final Region region;
  const _EditRegionDialog({required this.region});

  @override
  ConsumerState<_EditRegionDialog> createState() => _EditRegionDialogState();
}

class _EditRegionDialogState extends ConsumerState<_EditRegionDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.region.name,
  );
  late String _currency = widget.region.currency;
  late int? _iconCode = widget.region.iconCode;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (
      name: name,
      currency: _currency,
      iconCode: _iconCode,
    ));
  }

  Future<void> _export() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    final db = ref.read(appDatabaseProvider);
    final json = await JsonExportService(db).exportRegion(widget.region.id);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(json);
    final bytes = utf8.encode(jsonStr);
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: '${widget.region.name}.myroad.json',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], sharePositionOrigin: origin),
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    if (await showConfirmDialog(
      context,
      title: l10n.deleteRegion,
      content: l10n.deleteRegionConfirm(widget.region.name),
    )) {
      await ref.read(regionDaoProvider).deleteRegion(widget.region.id);
      if (mounted) {
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.editRegion)),
          IconButton(
            onPressed: _export,
            tooltip: l10n.exportJson,
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            onPressed: _delete,
            tooltip: l10n.deleteRegion,
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
                    current: regionIcon(iconCode: _iconCode),
                    color: regionColor(),
                    tooltip: l10n.icon,
                    onPicked: (icon) =>
                        setState(() => _iconCode = icon?.codePoint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        label: requiredLabel(l10n.regionName),
                      ),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: InputDecoration(
                  labelText: l10n.currency,
                  border: const OutlineInputBorder(),
                ),
                items: currencySymbols.keys
                    .map(
                      (code) => DropdownMenuItem(
                        value: code,
                        child: Text('$code (${currencySymbol(code)})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _currency = v ?? _currency),
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
