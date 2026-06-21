import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/area_section.dart';
import 'package:myroad/screens/trips/stages/hotel_config_stage.dart';
import 'package:myroad/screens/trips/stages/itinerary_builder_stage.dart';
import 'package:myroad/screens/trips/stages/export_stage.dart';
import 'package:myroad/screens/trips/stages/itinerary_view_stage.dart';
import 'package:myroad/screens/trips/stages/post_trip_stage.dart';
import 'package:myroad/widgets/name_input_dialog.dart';

class TripDashboardScreen extends ConsumerWidget {
  final String tripId;

  const TripDashboardScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tripDao = ref.watch(tripDaoProvider);

    return StreamBuilder<Trip?>(
      stream: tripDao.watchById(tripId),
      builder: (context, snapshot) {
        final trip = snapshot.data;
        return DefaultTabController(
          length: 6,
          child: Scaffold(
            appBar: AppBar(
              title: Text(trip?.name ?? ''),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    switch (action) {
                      case 'rename':
                        final name = await showDialog<String>(
                          context: context,
                          builder: (_) => NameInputDialog(
                            title: l10n.rename,
                            labelText: l10n.tripName,
                            initialValue: trip?.name ?? '',
                          ),
                        );
                        if (name != null) await tripDao.updateTrip(tripId, name: name);
                      case 'dates':
                        if (trip == null) return;
                        await _editDates(context, ref, tripDao, tripId, trip);
                      case 'delete':
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(l10n.delete),
                            content: Text(l10n.deleteTripConfirm(trip?.name ?? '')),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await tripDao.deleteTrip(tripId);
                          if (context.mounted) Navigator.pop(context);
                        }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                    PopupMenuItem(value: 'dates', child: Text(l10n.editDates)),
                    PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                  ],
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: l10n.organizeRegions),
                  Tab(text: l10n.hotels),
                  Tab(text: l10n.itineraryBuilder),
                  Tab(text: l10n.itineraryView),
                  Tab(text: l10n.export),
                  Tab(text: l10n.postTrip),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _RegionsStage(tripId: tripId),
                HotelConfigStage(tripId: tripId),
                ItineraryBuilderStage(tripId: tripId),
                ItineraryViewStage(tripId: tripId),
                ExportStage(tripId: tripId),
                PostTripStage(tripId: tripId),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editDates(BuildContext context, WidgetRef ref, TripDao tripDao, String tripId, Trip trip) async {
    var start = trip.startDate;
    var end = trip.endDate;
    final l10n = AppLocalizations.of(context)!;
    final itineraryDao = ItineraryDao(ref.read(appDatabaseProvider));
    String? error;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> validate() async {
            if (start != null && end != null) {
              final newDays = end!.difference(start!).inDays + 1;
              final existingDays = await itineraryDao.watchDays(tripId).first;
              if (existingDays.isNotEmpty && newDays < existingDays.length) {
                setDialogState(() => error = l10n.datesTooFewDays(newDays, existingDays.length));
                return;
              }
            }
            setDialogState(() => error = null);
          }

          return AlertDialog(
            title: Text(l10n.editDates),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            initialDate: start ?? DateTime.now(),
                          );
                          if (d != null) {
                            setDialogState(() => start = d);
                            validate();
                          }
                        },
                        child: Text(start != null
                            ? '${l10n.startDate}: ${start.toString().split(' ')[0]}'
                            : '${l10n.startDate} (${l10n.optional})'),
                      ),
                    ),
                    if (start != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setDialogState(() => start = null);
                          validate();
                        },
                        tooltip: l10n.clearDate,
                      ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            initialDate: end ?? start ?? DateTime.now(),
                          );
                          if (d != null) {
                            setDialogState(() => end = d);
                            validate();
                          }
                        },
                        child: Text(end != null
                            ? '${l10n.endDate}: ${end.toString().split(' ')[0]}'
                            : '${l10n.endDate} (${l10n.optional})'),
                      ),
                    ),
                    if (end != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setDialogState(() => end = null);
                          validate();
                        },
                        tooltip: l10n.clearDate,
                      ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: error != null ? null : () async {
                  if (start == null && end == null) {
                    await tripDao.clearTripDates(tripId);
                  } else {
                    await tripDao.updateTrip(tripId, startDate: start, endDate: end);
                    if (start != null && end != null) {
                      final newDays = end!.difference(start!).inDays + 1;
                      final existing = await itineraryDao.watchDays(tripId).first;
                      for (var i = existing.length + 1; i <= newDays; i++) {
                        await itineraryDao.addDay(tripId, i);
                      }
                    }
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- Regions: browse + reorder + swipe-to-remove ---

class _RegionsStage extends ConsumerStatefulWidget {
  final String tripId;
  const _RegionsStage({required this.tripId});

  @override
  ConsumerState<_RegionsStage> createState() => _RegionsStageState();
}

class _RegionsStageState extends ConsumerState<_RegionsStage> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () => _addRegion(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.addRegionToTrip),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _reordering = !_reordering),
                icon: Icon(_reordering ? Icons.check : Icons.reorder),
                label: Text(_reordering ? l10n.done : l10n.editOrder),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: regionDao.watchByTrip(widget.tripId),
            builder: (context, snapshot) {
              final regions = snapshot.data ?? [];
              if (regions.isEmpty) return Center(child: Text(l10n.noRegionsInTrip));

              if (_reordering) {
                return ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: regions.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = regions.map((r) => r.id).toList();
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    regionDao.reorderInTrip(widget.tripId, ids);
                  },
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return Card(
                      key: ValueKey(region.id),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(region.name),
                      ),
                    );
                  },
                );
              }

              return ListView(
                children: regions.map((r) => Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: Theme.of(context).colorScheme.error,
                    child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
                  ),
                  confirmDismiss: (_) => showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(l10n.delete),
                      content: Text(l10n.deleteRegionConfirm(r.name)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
                      ],
                    ),
                  ),
                  onDismissed: (_) => regionDao.removeFromTrip(r.id, widget.tripId),
                  child: _RegionSection(regionId: r.id, regionName: r.name),
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
    final tripRegions = await regionDao.watchByTrip(widget.tripId).first;
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
      await regionDao.addToTrip(selectedId, widget.tripId);
    }
  }
}

class _RegionSection extends ConsumerWidget {
  final String regionId;
  final String regionName;
  const _RegionSection({required this.regionId, required this.regionName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areaDao = ref.watch(areaDaoProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(regionName, style: Theme.of(context).textTheme.titleMedium),
        children: [
          StreamBuilder(
            stream: areaDao.watchByRegion(regionId),
            builder: (context, snapshot) {
              final areas = snapshot.data ?? [];
              return Column(
                children: areas.map((a) =>
                  AreaSection(areaId: a.id, areaName: a.name, regionId: regionId, reorderable: true),
                ).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

