import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/zone_section.dart';
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
    final zoneDao = ref.watch(zoneDaoProvider);

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
              'delete' => _confirmDelete(context, ref),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
              PopupMenuItem(value: 'delete', child: Text(l10n.deleteRegion)),
            ],
          ),
        ],
      ),
      body: StreamBuilder(
        stream: zoneDao.watchByRegion(regionId),
        builder: (context, snapshot) {
          final zones = snapshot.data ?? [];
          if (zones.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.nZones(0)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _addZone(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addZone),
                  ),
                ],
              ),
            );
          }
          return ListView(
            physics: const ClampingScrollPhysics(),
            children: [
              _SpotsMapSection(regionId: regionId, zones: zones),
              for (final zone in zones)
                ZoneSection(zoneId: zone.id, zoneName: zone.name),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addZone(context, ref),
        child: const Icon(Icons.add),
      ),
    );
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

  Future<void> _addZone(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameInputDialog(title: l10n.addZone, labelText: l10n.zoneName),
    );
    if (name != null) {
      await ref.read(zoneDaoProvider).insertZone(name, 'city', regionId: regionId);
    }
  }
}

class _SpotsMapSection extends ConsumerWidget {
  final String regionId;
  final List<dynamic> zones;

  const _SpotsMapSection({required this.regionId, required this.zones});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SpotsMap.supported) return const SizedBox.shrink();

    final spotDao = ref.watch(spotDaoProvider);
    final allSpotStreams = zones.map((z) => spotDao.watchByZone(z.id));

    return StreamBuilder(
      stream: Stream.fromFuture(
        Future.wait(allSpotStreams.map((s) => s.first)),
      ),
      builder: (context, snapshot) {
        final allSpots = (snapshot.data ?? [])
            .expand((spots) => spots)
            .map((s) => MapSpot(
                  id: s.id,
                  name: s.name,
                  type: s.type,
                  lat: s.lat,
                  lng: s.lng,
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
