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
import 'package:myroad/screens/region_library/area_section.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/widgets/name_input_dialog.dart';
import 'package:myroad/widgets/spots_map.dart';

class RegionDetailScreen extends ConsumerWidget {
  final String regionId;

  const RegionDetailScreen({super.key, required this.regionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);
    final areaDao = ref.watch(areaDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder(
          future: regionDao.getById(regionId),
          builder: (context, snapshot) => Text(snapshot.data?.name ?? ''),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) => switch (action) {
              'rename' => _rename(context, ref),
              'export' => _exportJson(context, ref),
              'delete' => _confirmDelete(context, ref),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
              PopupMenuItem(value: 'export', child: Text(l10n.exportJson)),
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteRegion)),
            ],
          ),
        ],
      ),
      body: StreamBuilder(
        stream: areaDao.watchByRegion(regionId),
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
                    onPressed: () => _addArea(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addArea),
                  ),
                ],
              ),
            );
          }
          return ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _SpotsMapSection(regionId: regionId, areas: areas),
              for (final area in areas)
                AreaSection(areaId: area.id, areaName: area.name, regionId: regionId),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addArea(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    final db = ref.read(appDatabaseProvider);
    final region = await ref.read(regionDaoProvider).getById(regionId);
    if (region == null) return;
    final json = await JsonExportService(db).exportRegion(regionId);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(json);
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${region.name}.myroad.json'));
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final region = await ref.read(regionDaoProvider).getById(regionId);
    if (region == null || !context.mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameInputDialog(
        title: l10n.rename,
        labelText: l10n.regionName,
        initialValue: region.name,
      ),
    );
    if (name != null) {
      await ref.read(regionDaoProvider).updateRegion(regionId, name: name);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final region = await ref.read(regionDaoProvider).getById(regionId);
    if (region == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteRegion),
        content: Text(l10n.deleteRegionConfirm(region.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(regionDaoProvider).deleteRegion(regionId);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _addArea(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameInputDialog(title: l10n.addArea, labelText: l10n.areaName),
    );
    if (name != null) {
      await ref.read(areaDaoProvider).insertArea(name, 'city', regionId: regionId);
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
