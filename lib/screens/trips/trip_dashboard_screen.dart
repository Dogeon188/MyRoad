import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/zone_section.dart';

class TripDashboardScreen extends ConsumerWidget {
  final String tripId;

  const TripDashboardScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tripDao = ref.watch(tripDaoProvider);

    return FutureBuilder(
      future: tripDao.getById(tripId),
      builder: (context, snapshot) {
        final trip = snapshot.data;
        return DefaultTabController(
          length: 8,
          child: Scaffold(
            appBar: AppBar(
              title: Text(trip?.name ?? ''),
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: l10n.reviewAndEdit),
                  Tab(text: l10n.organizeRegions),
                  Tab(text: l10n.organizeZones),
                  Tab(text: l10n.organizeSpots),
                  Tab(text: l10n.itineraryBuilder),
                  Tab(text: l10n.itineraryView),
                  Tab(text: l10n.export),
                  Tab(text: l10n.postTrip),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _ReviewStage(tripId: tripId),
                _OrganizeRegionsStage(tripId: tripId),
                _OrganizeZonesStage(tripId: tripId),
                _OrganizeSpotsStage(tripId: tripId),
                const Center(child: Text('Builder — Plan 2D')),
                const Center(child: Text('View — Plan 3A')),
                const Center(child: Text('Export — Plan 3B')),
                const Center(child: Text('Post-Trip — Plan 3C')),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Review & Edit: browse trip's referenced regions, add/remove regions ---

class _ReviewStage extends ConsumerWidget {
  final String tripId;
  const _ReviewStage({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: FilledButton.icon(
            onPressed: () => _addRegion(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.addRegionToTrip),
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: regionDao.watchByTrip(tripId),
            builder: (context, snapshot) {
              final regions = snapshot.data ?? [];
              if (regions.isEmpty) {
                return Center(child: Text(l10n.noRegionsInTrip));
              }
              return ListView(
                children: regions.map((r) => _RegionReviewSection(
                  regionId: r.id,
                  regionName: r.name,
                  tripId: tripId,
                )).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addRegion(BuildContext context, WidgetRef ref) async {
    final regionDao = ref.read(regionDaoProvider);
    final allRegions = await regionDao.watchAll().first;
    final tripRegions = await regionDao.watchByTrip(tripId).first;
    final tripRegionIds = tripRegions.map((r) => r.id).toSet();
    final available = allRegions.where((r) => !tripRegionIds.contains(r.id)).toList();

    if (!context.mounted || available.isEmpty) return;

    final selectedId = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.selectRegions),
        children: available.map((region) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, region.id),
          child: Text(region.name),
        )).toList(),
      ),
    );

    if (selectedId != null) {
      await regionDao.addToTrip(selectedId, tripId);
    }
  }
}

class _RegionReviewSection extends ConsumerWidget {
  final String regionId;
  final String regionName;
  final String tripId;
  const _RegionReviewSection({required this.regionId, required this.regionName, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoneDao = ref.watch(zoneDaoProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(regionName, style: Theme.of(context).textTheme.titleMedium),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => ref.read(regionDaoProvider).removeFromTrip(regionId, tripId),
        ),
        children: [
          StreamBuilder(
            stream: zoneDao.watchByRegion(regionId),
            builder: (context, snapshot) {
              final zones = snapshot.data ?? [];
              return Column(
                children: zones.map((z) =>
                  ZoneSection(zoneId: z.id, zoneName: z.name),
                ).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- Organize Regions: reorder regions within trip ---

class _OrganizeRegionsStage extends ConsumerWidget {
  final String tripId;
  const _OrganizeRegionsStage({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);

    return StreamBuilder(
      stream: regionDao.watchByTrip(tripId),
      builder: (context, snapshot) {
        final regions = snapshot.data ?? [];
        if (regions.isEmpty) return Center(child: Text(l10n.noRegionsInTrip));

        return ReorderableListView.builder(
          itemCount: regions.length,
          onReorderItem: (oldIndex, newIndex) {
            final ids = regions.map((r) => r.id).toList();
            final moved = ids.removeAt(oldIndex);
            ids.insert(newIndex, moved);
            regionDao.reorderInTrip(tripId, ids);
          },
          itemBuilder: (context, index) {
            final region = regions[index];
            return Card(
              key: ValueKey(region.id),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.drag_handle),
                title: Text(region.name),
                subtitle: Text('${index + 1}'),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Organize Zones: per-region zone reorder (library order) ---

class _OrganizeZonesStage extends ConsumerStatefulWidget {
  final String tripId;
  const _OrganizeZonesStage({required this.tripId});

  @override
  ConsumerState<_OrganizeZonesStage> createState() => _OrganizeZonesStageState();
}

class _OrganizeZonesStageState extends ConsumerState<_OrganizeZonesStage> {
  String? _selectedRegionId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);
    final zoneDao = ref.watch(zoneDaoProvider);

    return Column(
      children: [
        StreamBuilder(
          stream: regionDao.watchByTrip(widget.tripId),
          builder: (context, snapshot) {
            final regions = snapshot.data ?? [];
            if (regions.isEmpty) return Center(child: Text(l10n.noRegionsInTrip));

            _selectedRegionId ??= regions.first.id;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: regions.map((r) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r.name),
                    selected: _selectedRegionId == r.id,
                    onSelected: (_) => setState(() => _selectedRegionId = r.id),
                  ),
                )).toList(),
              ),
            );
          },
        ),
        if (_selectedRegionId != null)
          Expanded(
            child: StreamBuilder(
              stream: zoneDao.watchByRegion(_selectedRegionId!),
              builder: (context, snapshot) {
                final zones = snapshot.data ?? [];
                if (zones.isEmpty) return Center(child: Text(l10n.noZonesInRegion));

                // ponytail: modifies library order, add per-trip zone ordering when needed
                return ReorderableListView.builder(
                  itemCount: zones.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = zones.map((z) => z.id).toList();
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    zoneDao.reorder(ids);
                  },
                  itemBuilder: (context, index) {
                    final zone = zones[index];
                    return Card(
                      key: ValueKey(zone.id),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.drag_handle),
                        title: Text(zone.name),
                        subtitle: Text('${zone.estimatedDurationMinutes} min'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

// --- Organize Spots: per-zone spot reorder with time budget ---

class _OrganizeSpotsStage extends ConsumerStatefulWidget {
  final String tripId;
  const _OrganizeSpotsStage({required this.tripId});

  @override
  ConsumerState<_OrganizeSpotsStage> createState() => _OrganizeSpotsStageState();
}

class _OrganizeSpotsStageState extends ConsumerState<_OrganizeSpotsStage> {
  String? _selectedRegionId;
  String? _selectedZoneId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);
    final zoneDao = ref.watch(zoneDaoProvider);
    final spotDao = ref.watch(spotDaoProvider);

    return Column(
      children: [
        // Region selector
        StreamBuilder(
          stream: regionDao.watchByTrip(widget.tripId),
          builder: (context, snapshot) {
            final regions = snapshot.data ?? [];
            _selectedRegionId ??= regions.firstOrNull?.id;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: regions.map((r) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r.name),
                    selected: _selectedRegionId == r.id,
                    onSelected: (_) => setState(() {
                      _selectedRegionId = r.id;
                      _selectedZoneId = null;
                    }),
                  ),
                )).toList(),
              ),
            );
          },
        ),
        // Zone selector
        if (_selectedRegionId != null)
          StreamBuilder(
            stream: zoneDao.watchByRegion(_selectedRegionId!),
            builder: (context, snapshot) {
              final zones = snapshot.data ?? [];
              _selectedZoneId ??= zones.firstOrNull?.id;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: zones.map((z) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(z.name),
                      selected: _selectedZoneId == z.id,
                      onSelected: (_) => setState(() => _selectedZoneId = z.id),
                    ),
                  )).toList(),
                ),
              );
            },
          ),
        // Spot reorder list
        if (_selectedZoneId != null)
          Expanded(
            child: StreamBuilder(
              stream: spotDao.watchByZone(_selectedZoneId!),
              builder: (context, snapshot) {
                final spots = snapshot.data ?? [];
                if (spots.isEmpty) return Center(child: Text(l10n.noSpotsInZone));

                final totalMinutes = spots.fold<int>(
                  0, (sum, s) => sum + s.estimatedVisitDurationMinutes + s.bufferTimeMinutes,
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: LinearProgressIndicator(
                        value: (totalMinutes / (16 * 60)).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[300],
                        color: totalMinutes > 16 * 60 ? Colors.red : Colors.teal,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(l10n.timeBudget(totalMinutes ~/ 60, totalMinutes % 60)),
                    ),
                    Expanded(
                      // ponytail: modifies library order, add per-trip spot ordering when needed
                      child: ReorderableListView.builder(
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
                              leading: const Icon(Icons.drag_handle),
                              title: Text(spot.name),
                              subtitle: Text(
                                '${spot.estimatedVisitDurationMinutes}min + ${spot.bufferTimeMinutes}min buffer',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
