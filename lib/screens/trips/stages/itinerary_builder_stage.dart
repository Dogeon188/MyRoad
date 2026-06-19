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

        return StreamBuilder<List<HotelStay>>(
          stream: _itineraryDao.watchHotelStays(widget.tripId),
          builder: (context, staysSnap) {
            final stays = staysSnap.data ?? [];

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RegionRow(
                    days: days,
                    itineraryDao: _itineraryDao,
                    zoneDao: _zoneDao,
                    regionDao: _regionDao,
                  ),
                  Expanded(
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: days
                            .map((day) => _DayColumn(
                                  day: day,
                                  itineraryDao: _itineraryDao,
                                  zoneDao: _zoneDao,
                                  spotDao: _spotDao,
                                  onAddZone: () => _pickZoneForDay(day.id),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  if (stays.isNotEmpty)
                    _HotelRow(
                      stays: stays,
                      dayCount: days.length,
                      spotDao: _spotDao,
                    ),
                ],
              ),
            );
          },
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

  Future<void> _pickZoneForDay(String dayId) async {
    final regions = await _regionDao.watchByTrip(widget.tripId).first;
    if (!mounted || regions.isEmpty) return;

    final children = <Widget>[];
    for (final region in regions) {
      final zones = await _zoneDao.watchByRegion(region.id).first;
      if (zones.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
        child: Text(region.name,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.teal)),
      ));
      for (final z in zones) {
        children.add(SimpleDialogOption(
          onPressed: () => Navigator.pop(context, z),
          child: Text(z.name),
        ));
      }
    }

    if (children.isEmpty) return;

    final selected = await showDialog<Zone>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.addZoneToDay),
        children: children,
      ),
    );

    if (selected != null) {
      final existing = await _itineraryDao.watchDayItems(dayId).first;
      await _itineraryDao.addZoneToDay(
        dayId: dayId,
        zoneId: selected.id,
        order: existing.length,
      );
    }
  }
}

class _DayColumn extends StatelessWidget {
  final ItineraryDay day;
  final ItineraryDao itineraryDao;
  final ZoneDao zoneDao;
  final SpotDao spotDao;
  final VoidCallback onAddZone;

  const _DayColumn({
    required this.day,
    required this.itineraryDao,
    required this.zoneDao,
    required this.spotDao,
    required this.onAddZone,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: 200,
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

                return ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  buildDefaultDragHandles: false,
                  itemCount: items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = items.map((i) => i.id).toList();
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    itineraryDao.reorderItems(ids);
                  },
                  itemBuilder: (context, index) => _ZoneCard(
                    key: ValueKey(items[index].id),
                    index: index,
                    item: items[index],
                    zoneDao: zoneDao,
                    spotDao: spotDao,
                    itineraryDao: itineraryDao,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final int index;
  final DayItem item;
  final ZoneDao zoneDao;
  final SpotDao spotDao;
  final ItineraryDao itineraryDao;

  const _ZoneCard({
    super.key,
    required this.index,
    required this.item,
    required this.zoneDao,
    required this.spotDao,
    required this.itineraryDao,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Zone?>(
      future: zoneDao.getById(item.zoneId),
      builder: (context, snapshot) {
        final zone = snapshot.data;
        final name = zone?.name ?? '...';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, size: 18),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Row(
                        children: [
                          Text(name,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  )),
                          if ((zone?.estimatedDurationMinutes ?? 0) > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${zone!.estimatedDurationMinutes ~/ 60}h${zone.estimatedDurationMinutes % 60 > 0 ? '${zone.estimatedDurationMinutes % 60}m' : ''}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.grey[500],
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => itineraryDao.removeItem(item.id),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<Spot>>(
                stream: spotDao.watchByZone(item.zoneId),
                builder: (context, snap) {
                  final spots = (snap.data ?? [])
                      .where((s) => s.type != 'hotel')
                      .toList();
                  return Column(
                    children: spots
                        .map((spot) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _spotColor(spot.type),
                                    radius: 5,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(spot.name,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  static Color _spotColor(String type) => switch (type) {
        'restaurant' => Colors.orange,
        'hotel' => Colors.purple,
        'custom' => Colors.grey,
        _ => Colors.blue,
      };
}

class _RegionRow extends StatelessWidget {
  final List<ItineraryDay> days;
  final ItineraryDao itineraryDao;
  final ZoneDao zoneDao;
  final RegionDao regionDao;

  const _RegionRow({
    required this.days,
    required this.itineraryDao,
    required this.zoneDao,
    required this.regionDao,
  });

  Future<List<String?>> _resolveRegionIds() async {
    final result = <String?>[];
    for (final day in days) {
      final items = await itineraryDao.watchDayItems(day.id).first;
      if (items.isEmpty) {
        result.add(null);
        continue;
      }
      final zone = await zoneDao.getById(items.first.zoneId);
      result.add(zone?.regionId);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // Merge all day-item streams so we rebuild when any day changes
    final trigger = Stream.multi((controller) {
      for (final day in days) {
        itineraryDao.watchDayItems(day.id).listen(
          (data) => controller.add(null),
          onError: controller.addError,
        );
      }
    });

    return StreamBuilder(
      stream: trigger,
      builder: (context, _) => FutureBuilder<List<String?>>(
        future: _resolveRegionIds(),
        builder: (context, snapshot) {
          final regionIds = snapshot.data;
          if (regionIds == null) return const SizedBox.shrink();

          final segments = <({String? regionId, int span})>[];
          var i = 0;
          while (i < regionIds.length) {
            final rid = regionIds[i];
            var span = 1;
            while (
                i + span < regionIds.length && regionIds[i + span] == rid) {
              span++;
            }
            segments.add((regionId: rid, span: span));
            i += span;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: segments.map((seg) {
                final width = seg.span * 208.0 - 8.0;
                if (seg.regionId == null) {
                  return SizedBox(width: width + 8.0);
                }
                return Container(
                  width: width,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal[200]!),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FutureBuilder<Region?>(
                    future: regionDao.getById(seg.regionId!),
                    builder: (context, snap) => Row(
                      children: [
                        const Icon(Icons.map, size: 14, color: Colors.teal),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(snap.data?.name ?? '...',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _HotelRow extends StatelessWidget {
  final List<HotelStay> stays;
  final int dayCount;
  final SpotDao spotDao;

  const _HotelRow({
    required this.stays,
    required this.dayCount,
    required this.spotDao,
  });

  @override
  Widget build(BuildContext context) {
    final segments = <({HotelStay? stay, int span})>[];
    var i = 1;
    while (i <= dayCount) {
      final stay = ItineraryDao.hotelForDay(stays, i);
      var span = 1;
      while (i + span <= dayCount &&
          ItineraryDao.hotelForDay(stays, i + span)?.id == stay?.id) {
        span++;
      }
      segments.add((stay: stay, span: span));
      i += span;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: segments.map((seg) {
          final width = seg.span * 208.0 - 8.0;
          if (seg.stay == null) {
            return SizedBox(width: width + 8.0);
          }
          return Container(
            width: width,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple[200]!),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FutureBuilder<Spot?>(
              future: spotDao.getById(seg.stay!.spotId),
              builder: (context, snap) {
                final name = snap.data?.name ?? '...';
                return Row(
                  children: [
                    const Icon(Icons.hotel, size: 14, color: Colors.purple),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(AppLocalizations.of(context)!.nightsCount(seg.span),
                        style: TextStyle(
                            fontSize: 11, color: Colors.purple[400])),
                  ],
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
