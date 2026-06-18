import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/roi_library/zone_section.dart';
import 'package:myroad/screens/roi_library/spot_detail_screen.dart';
import 'package:myroad/widgets/name_input_dialog.dart';
import 'package:myroad/widgets/spots_map.dart';

class RoiDetailScreen extends ConsumerWidget {
  final String roiId;

  const RoiDetailScreen({super.key, required this.roiId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final roiDao = ref.watch(roiDaoProvider);
    final zoneDao = ref.watch(zoneDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder(
          future: roiDao.getById(roiId),
          builder: (context, snapshot) => Text(snapshot.data?.name ?? ''),
        ),
      ),
      body: StreamBuilder(
        stream: zoneDao.watchByRoi(roiId),
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
            children: [
              _SpotsMapSection(roiId: roiId, zones: zones),
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

  Future<void> _addZone(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameInputDialog(title: l10n.addZone, labelText: l10n.zoneName),
    );
    if (name != null) {
      await ref.read(zoneDaoProvider).insertZone(name, 'city', roiId: roiId);
    }
  }
}

class _SpotsMapSection extends ConsumerWidget {
  final String roiId;
  final List<dynamic> zones;

  const _SpotsMapSection({required this.roiId, required this.zones});

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
