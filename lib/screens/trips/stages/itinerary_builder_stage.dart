import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';

class ItineraryBuilderStage extends ConsumerStatefulWidget {
  final String tripId;

  const ItineraryBuilderStage({super.key, required this.tripId});

  @override
  ConsumerState<ItineraryBuilderStage> createState() =>
      _ItineraryBuilderStageState();
}

class _ItineraryBuilderStageState
    extends ConsumerState<ItineraryBuilderStage> {
  late final ItineraryDao _itineraryDao;
  late final SpotDao _spotDao;
  late final ZoneDao _zoneDao;
  late final RegionDao _regionDao;

  @override
  void initState() {
    super.initState();
    final db = ref.read(appDatabaseProvider);
    _itineraryDao = ItineraryDao(db);
    _spotDao = ref.read(spotDaoProvider);
    _zoneDao = ref.read(zoneDaoProvider);
    _regionDao = ref.read(regionDaoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<List<ItineraryDay>>(
      stream: _itineraryDao.watchDays(widget.tripId),
      builder: (context, snapshot) {
        final days = snapshot.data ?? [];
        if (days.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.noItineraryDays),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _initDays(context),
                  child: Text(l10n.initializeItinerary),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _autoFill,
                    icon: const Icon(Icons.auto_fix_high),
                    label: Text(l10n.autoFillFromSpots),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: days
                        .map((day) => _DayColumn(
                              day: day,
                              tripId: widget.tripId,
                              itineraryDao: _itineraryDao,
                              spotDao: _spotDao,
                              zoneDao: _zoneDao,
                              onAddZone: () => _pickZoneForDay(day.id),
                              onPickHotel: () => _pickHotelForDay(day.dayNumber),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initDays(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final count = await showDialog<int>(
      context: context,
      builder: (_) {
        final controller = TextEditingController(text: '3');
        return AlertDialog(
          title: Text(l10n.howManyDays),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text)),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );
    if (count != null && count > 0) {
      await _itineraryDao.initializeDays(widget.tripId, count);
    }
  }

  Future<List<Zone>> _getTripZones() async {
    final regions = await _regionDao.watchByTrip(widget.tripId).first;
    final allZones = <Zone>[];
    for (final region in regions) {
      final zones = await _zoneDao.watchByRegion(region.id).first;
      allZones.addAll(zones);
    }
    return allZones;
  }

  Future<void> _addZoneToDay(String dayId, Zone zone) async {
    final spots = await _spotDao.watchByZone(zone.id).first;
    final existing = await _itineraryDao.watchDayItems(dayId).first;
    var order = existing.length;
    for (final spot in spots) {
      await _itineraryDao.addItemToDay(
        dayId: dayId,
        spotId: spot.id,
        zoneId: zone.id,
        order: order++,
      );
    }
  }

  Future<void> _autoFill() async {
    final days = await _itineraryDao.watchDays(widget.tripId).first;
    if (days.isEmpty) return;

    final allZones = await _getTripZones();
    if (allZones.isEmpty) return;

    // ponytail: round-robin distribute zones across days
    for (var i = 0; i < allZones.length; i++) {
      final dayIndex = i % days.length;
      await _addZoneToDay(days[dayIndex].id, allZones[i]);
    }
  }

  Future<void> _pickHotelForDay(int dayNumber) async {
    final allSpots = <Spot>[];
    final regions = await _regionDao.watchByTrip(widget.tripId).first;
    for (final region in regions) {
      final zones = await _zoneDao.watchByRegion(region.id).first;
      for (final zone in zones) {
        final spots = await _spotDao.watchByZone(zone.id).first;
        allSpots.addAll(spots);
      }
    }
    final hotels = allSpots.where((s) => s.type == 'hotel').toList();
    if (!mounted || hotels.isEmpty) return;

    final selected = await showDialog<Spot>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.setHotel),
        children: hotels
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, s),
                  child: Text(s.name),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      await _itineraryDao.setHotelForDay(
        tripId: widget.tripId,
        spotId: selected.id,
        dayNumber: dayNumber,
      );
    }
  }

  Future<void> _pickZoneForDay(String dayId) async {
    final allZones = await _getTripZones();
    if (!mounted || allZones.isEmpty) return;

    final selected = await showDialog<Zone>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.addZoneToDay),
        children: allZones
            .map((z) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, z),
                  child: Text(z.name),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      await _addZoneToDay(dayId, selected);
    }
  }
}

class _DayColumn extends StatelessWidget {
  final ItineraryDay day;
  final String tripId;
  final ItineraryDao itineraryDao;
  final SpotDao spotDao;
  final ZoneDao zoneDao;
  final VoidCallback onAddZone;
  final VoidCallback onPickHotel;

  const _DayColumn({
    required this.day,
    required this.tripId,
    required this.itineraryDao,
    required this.spotDao,
    required this.zoneDao,
    required this.onAddZone,
    required this.onPickHotel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(l10n.dayN(day.dayNumber),
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: onAddZone,
                  tooltip: l10n.addZoneToDay,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<DayItem>>(
              stream: itineraryDao.watchDayItems(day.id),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(l10n.dropSpotsHere,
                        style: TextStyle(color: Colors.grey[500])),
                  );
                }

                // Group items by zone
                final grouped = <String, List<DayItem>>{};
                for (final item in items) {
                  grouped.putIfAbsent(item.zoneId, () => []).add(item);
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: grouped.entries
                      .map((e) => _ZoneGroup(
                            zoneId: e.key,
                            items: e.value,
                            spotDao: spotDao,
                            zoneDao: zoneDao,
                            itineraryDao: itineraryDao,
                          ))
                      .toList(),
                );
              },
            ),
          ),
          const Divider(height: 1),
          _HotelSection(
            tripId: tripId,
            dayNumber: day.dayNumber,
            itineraryDao: itineraryDao,
            spotDao: spotDao,
            onPickHotel: onPickHotel,
          ),
        ],
      ),
    );
  }
}

class _ZoneGroup extends StatelessWidget {
  final String zoneId;
  final List<DayItem> items;
  final SpotDao spotDao;
  final ZoneDao zoneDao;
  final ItineraryDao itineraryDao;

  const _ZoneGroup({
    required this.zoneId,
    required this.items,
    required this.spotDao,
    required this.zoneDao,
    required this.itineraryDao,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder<Zone?>(
                    future: zoneDao.getById(zoneId),
                    builder: (context, snapshot) => Text(
                      snapshot.data?.name ?? '...',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () async {
                    for (final item in items) {
                      await itineraryDao.removeItem(item.id);
                    }
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          ...items.map((item) => _SpotTile(item: item, spotDao: spotDao)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _SpotTile extends StatelessWidget {
  final DayItem item;
  final SpotDao spotDao;

  const _SpotTile({required this.item, required this.spotDao});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Spot?>(
      future: spotDao.getById(item.spotId),
      builder: (context, snapshot) {
        final spot = snapshot.data;
        final name = spot?.name ?? '...';
        final color = switch (spot?.type ?? 'spot') {
          'restaurant' => Colors.orange,
          'hotel' => Colors.purple,
          'custom' => Colors.grey,
          _ => Colors.blue,
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color, radius: 5),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 13)),
              ),
              if (item.startTimeMinutes != null)
                Text(
                  '${_fmtTime(item.startTimeMinutes!)}–${_fmtTime(item.endTimeMinutes!)}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
        );
      },
    );
  }

  String _fmtTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _HotelSection extends StatelessWidget {
  final String tripId;
  final int dayNumber;
  final ItineraryDao itineraryDao;
  final SpotDao spotDao;
  final VoidCallback onPickHotel;

  const _HotelSection({
    required this.tripId,
    required this.dayNumber,
    required this.itineraryDao,
    required this.spotDao,
    required this.onPickHotel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<HotelStay?>(
      stream: itineraryDao.watchHotelForDay(tripId, dayNumber),
      builder: (context, snapshot) {
        final stay = snapshot.data;

        if (stay == null) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: onPickHotel,
              icon: const Icon(Icons.hotel, size: 16),
              label: Text(l10n.setHotel),
            ),
          );
        }

        return FutureBuilder<Spot?>(
          future: spotDao.getById(stay.spotId),
          builder: (context, snap) {
            final name = snap.data?.name ?? '...';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.hotel, size: 16, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () =>
                        itineraryDao.removeHotelForDay(tripId, dayNumber),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
