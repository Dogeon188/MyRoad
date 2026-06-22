import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/json_export_service.dart';
import 'package:myroad/services/png_export_service.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/widgets/calendar_export_view.dart';
import 'package:myroad/widgets/detail_export_view.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/screens/region_library/spot_search_screen.dart';
import 'package:myroad/screens/trips/stages/hotel_config_stage.dart';
import 'package:myroad/screens/trips/stages/itinerary_builder_stage.dart';
import 'package:myroad/screens/trips/stages/itinerary_view_stage.dart';
import 'package:myroad/screens/trips/stages/post_trip_stage.dart';
import 'package:myroad/widgets/dialogs.dart';
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
                      case 'export_calendar':
                        if (context.mounted) await _exportCalendarPng(context, ref);
                      case 'export_detail':
                        if (context.mounted) await _exportDetailPng(context, ref);
                      case 'export_json':
                        if (context.mounted) await _exportJson(context, ref);
                      case 'delete':
                        if (await showConfirmDialog(context, title: l10n.delete, content: l10n.deleteTripConfirm(trip?.name ?? ''))) {
                          await tripDao.deleteTrip(tripId);
                          if (context.mounted) Navigator.pop(context);
                        }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                    PopupMenuItem(value: 'dates', child: Text(l10n.editDates)),
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'export_calendar', child: Text(l10n.exportCalendarPng)),
                    PopupMenuItem(value: 'export_detail', child: Text(l10n.exportDetailPng)),
                    PopupMenuItem(value: 'export_json', child: Text(l10n.exportJson)),
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                  ],
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: l10n.list),
                  Tab(text: l10n.map),
                  Tab(text: l10n.itineraryBuilder),
                  Tab(text: l10n.organizeRegions),
                  Tab(text: l10n.hotels),
                  Tab(text: l10n.postTrip),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                ItineraryListStage(tripId: tripId),
                ItineraryMapStage(tripId: tripId),
                ItineraryBuilderStage(tripId: tripId),
                _RegionsStage(tripId: tripId),
                HotelConfigStage(tripId: tripId),
                PostTripStage(tripId: tripId),
              ],
            ),
          ),
        );
      },
    );
  }

  Rect _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;
  }

  Future<String> _tripName(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingle();
    return trip.name;
  }

  Future<void> _exportCalendarPng(BuildContext context, WidgetRef ref) async {
    final origin = _shareOrigin(context);
    final db = ref.read(appDatabaseProvider);
    final service = PngExportService(db);
    final data = await service.getCalendarData(tripId);
    if (!context.mounted) return;
    final bytes = await PngExportService.captureWidget(context, CalendarExportView(data: data));
    final name = await _tripName(ref);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$name.calendar.png'));
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }

  Future<void> _exportDetailPng(BuildContext context, WidgetRef ref) async {
    final origin = _shareOrigin(context);
    final db = ref.read(appDatabaseProvider);
    final itineraryDao = ItineraryDao(db);
    final days = await itineraryDao.watchDays(tripId).first;
    if (days.isEmpty || !context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<List<ItineraryDay>>(
      context: context,
      builder: (ctx) => _DayPickerDialog(days: days, l10n: l10n),
    );
    if (selected == null || selected.isEmpty) return;
    final service = PngExportService(db);
    final name = await _tripName(ref);
    final dir = await getTemporaryDirectory();
    final files = <XFile>[];
    for (final day in selected) {
      final data = await service.getDetailDayData(tripId, day.id);
      if (!context.mounted) return;
      final bytes = await PngExportService.captureWidget(context, DetailExportView(data: data));
      final file = File(p.join(dir.path, '$name.day${day.dayNumber}.png'));
      await file.writeAsBytes(bytes);
      files.add(XFile(file.path));
    }
    await Share.shareXFiles(files, sharePositionOrigin: origin);
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final origin = _shareOrigin(context);
    final db = ref.read(appDatabaseProvider);
    final name = await _tripName(ref);
    final json = await JsonExportService(db).exportTrip(tripId);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(json);
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$name.myroad.json'));
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
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
                          final d = await showTripDatePicker(context, initialDate: start);
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
                          final d = await showTripDatePicker(context, initialDate: end ?? start);
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
                        leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
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
                  confirmDismiss: (_) => showConfirmDialog(context, title: l10n.delete, content: l10n.deleteRegionConfirm(r.name)),
                  onDismissed: (_) => regionDao.removeFromTrip(r.id, widget.tripId),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(r.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => _TripAreaListPage(regionId: r.id, regionName: r.name, tripId: widget.tripId)),
                      ),
                    ),
                  ),
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

class _DayPickerDialog extends StatefulWidget {
  final List<ItineraryDay> days;
  final AppLocalizations l10n;
  const _DayPickerDialog({required this.days, required this.l10n});

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late int _start = widget.days.first.dayNumber;
  late int _end = widget.days.last.dayNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final first = widget.days.first.dayNumber;
    final last = widget.days.last.dayNumber;
    return AlertDialog(
      title: Text(l10n.selectDays),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.dayN(_start)} — ${l10n.dayN(_end)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            RangeSlider(
              values: RangeValues(_start.toDouble(), _end.toDouble()),
              min: first.toDouble(),
              max: last.toDouble(),
              divisions: last - first,
              labels: RangeLabels(l10n.dayN(_start), l10n.dayN(_end)),
              onChanged: (v) => setState(() {
                _start = v.start.round();
                _end = v.end.round();
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final chosen = widget.days.where((d) => d.dayNumber >= _start && d.dayNumber <= _end).toList();
            Navigator.pop(context, chosen);
          },
          child: Text(l10n.export),
        ),
      ],
    );
  }
}

class _TripAreaListPage extends ConsumerStatefulWidget {
  final String regionId;
  final String regionName;
  final String tripId;
  const _TripAreaListPage({required this.regionId, required this.regionName, required this.tripId});

  @override
  ConsumerState<_TripAreaListPage> createState() => _TripAreaListPageState();
}

class _TripAreaListPageState extends ConsumerState<_TripAreaListPage> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final areaDao = ref.watch(areaDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.regionName),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _reordering = !_reordering),
            icon: Icon(_reordering ? Icons.check : Icons.reorder),
            label: Text(_reordering ? l10n.done : l10n.editOrder),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: areaDao.watchByRegion(widget.regionId),
        builder: (context, snapshot) {
          final areas = snapshot.data ?? [];
          if (areas.isEmpty) return Center(child: Text(l10n.nAreas(0)));

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
                final a = areas[index];
                return Card(
                  key: ValueKey(a.id),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                    title: Text(a.name),
                  ),
                );
              },
            );
          }

          return ListView(
            children: areas.map((a) => Card(
              key: ValueKey(a.id),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(a.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => _TripSpotListPage(
                    areaId: a.id, areaName: a.name, regionId: widget.regionId, tripId: widget.tripId,
                  )),
                ),
              ),
            )).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await showDialog<String>(
            context: context,
            builder: (_) => NameInputDialog(title: l10n.addArea, labelText: l10n.areaName),
          );
          if (name != null) {
            await areaDao.insertArea(name, 'city', regionId: widget.regionId);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TripSpotListPage extends ConsumerStatefulWidget {
  final String areaId;
  final String areaName;
  final String regionId;
  final String tripId;
  const _TripSpotListPage({required this.areaId, required this.areaName, required this.regionId, required this.tripId});

  @override
  ConsumerState<_TripSpotListPage> createState() => _TripSpotListPageState();
}

class _TripSpotListPageState extends ConsumerState<_TripSpotListPage> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);
    final itineraryDao = ItineraryDao(ref.watch(appDatabaseProvider));

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

          return StreamBuilder<Set<String>>(
            stream: itineraryDao.watchSkippedSpots(widget.tripId),
            builder: (context, skippedSnap) {
              final skipped = skippedSnap.data ?? {};

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
                children: spots.map((spot) => Opacity(
                  key: ValueKey(spot.id),
                  opacity: skipped.contains(spot.id) ? 0.4 : 1.0,
                  child: Dismissible(
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
                          Text('${spot.estimatedVisitDurationMinutes}min + ${spot.bufferTimeMinutes}min buffer'),
                          if (spot.notes.isNotEmpty)
                            Text(spot.notes, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: spot.id)),
                      ),
                      onLongPress: () => _showSpotActions(context, spot, skipped: skipped.contains(spot.id)),
                    ),
                  ),
                )).toList(),
              );
            },
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

  Future<void> _showSpotActions(BuildContext context, Spot spot, {bool skipped = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(skipped ? Icons.visibility : Icons.visibility_off),
              title: Text(skipped ? l10n.unskipSpot : l10n.skipSpot),
              onTap: () => Navigator.pop(context, 'skip'),
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
    if (action == 'skip') {
      final dao = ItineraryDao(ref.read(appDatabaseProvider));
      await dao.toggleSkipped(widget.tripId, spot.id);
    } else if (action == 'delete') {
      if (await showConfirmDialog(context, content: l10n.deleteSpotConfirm(spot.name))) {
        ref.read(spotDaoProvider).deleteSpot(spot.id);
      }
    }
  }
}

