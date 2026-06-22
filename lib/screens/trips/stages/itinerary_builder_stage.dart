import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/widgets/time_picker_helper.dart';

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
  late final AreaDao _areaDao;
  late final RegionDao _regionDao;
  final _scrollController = ScrollController();
  late final Stream<Map<String, int>> _spotTimesStream;
  late final Stream<Set<String>> _skippedStream;

  @override
  void initState() {
    super.initState();
    final db = ref.read(appDatabaseProvider);
    _itineraryDao = ItineraryDao(db);
    _spotDao = ref.read(spotDaoProvider);
    _areaDao = ref.read(areaDaoProvider);
    _regionDao = ref.read(regionDaoProvider);
    _spotTimesStream = _itineraryDao.watchSpotTimes(widget.tripId);
    _skippedStream = _itineraryDao.watchSkippedSpots(widget.tripId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tripStartDate = ref.watch(tripDaoProvider).watchById(widget.tripId);

    return StreamBuilder<Trip?>(
      stream: tripStartDate,
      builder: (context, tripSnap) {
        final startDate = tripSnap.data?.startDate;

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

                return StreamBuilder<Map<String, int>>(
                  stream: _spotTimesStream,
                  builder: (context, timesSnap) {
                    final spotTimes = timesSnap.data ?? {};

                    return StreamBuilder<Set<String>>(
                      stream: _skippedStream,
                      builder: (context, skippedSnap) {
                        final skippedSpots = skippedSnap.data ?? {};

                    return SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RegionRow(
                            days: days,
                            itineraryDao: _itineraryDao,
                            areaDao: _areaDao,
                            regionDao: _regionDao,
                            scrollController: _scrollController,
                          ),
                          Expanded(
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...days.map((day) => _DayColumn(
                                        day: day,
                                        stays: stays,
                                        tripStartDate: startDate,
                                        itineraryDao: _itineraryDao,
                                        areaDao: _areaDao,
                                        spotDao: _spotDao,
                                        tripId: widget.tripId,
                                        spotTimes: spotTimes,
                                        skippedSpots: skippedSpots,
                                        onAddArea: () => _pickAreaForDay(day.id),
                                        onDelete: () => _itineraryDao.deleteDayAndRenumber(widget.tripId, day.id),
                                      )),
                                  Align(
                                    alignment: Alignment.center,
                                    child: _AddDayButton(onTap: () => _addDay(days)),
                                  ),
                                ],
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
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addDay(List<ItineraryDay> days) async {
    final nextNumber = days.isEmpty ? 1 : days.last.dayNumber + 1;
    await _itineraryDao.addDay(widget.tripId, nextNumber);
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

  Future<void> _pickAreaForDay(String dayId) async {
    final regions = await _regionDao.watchByTrip(widget.tripId).first;
    if (!mounted || regions.isEmpty) return;

    final children = <Widget>[];
    for (final region in regions) {
      final areas = await _areaDao.watchByRegion(region.id).first;
      if (areas.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
        child: Text(region.name,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.teal)),
      ));
      for (final a in areas) {
        children.add(SimpleDialogOption(
          onPressed: () => Navigator.pop(context, a),
          child: Text(a.name),
        ));
      }
    }

    if (children.isEmpty || !mounted) return;

    final selected = await showDialog<Area>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.addAreaToDay),
        children: children,
      ),
    );

    if (selected != null) {
      final existing = await _itineraryDao.watchDayItems(dayId).first;
      await _itineraryDao.addAreaToDay(
        dayId: dayId,
        areaId: selected.id,
        order: existing.length,
      );
    }
  }
}

String _formatDate(DateTime d) => '${d.month}/${d.day}';

class _DayColumn extends StatelessWidget {
  final ItineraryDay day;
  final List<HotelStay> stays;
  final DateTime? tripStartDate;
  final ItineraryDao itineraryDao;
  final AreaDao areaDao;
  final SpotDao spotDao;
  final String tripId;
  final Map<String, int> spotTimes;
  final Set<String> skippedSpots;
  final VoidCallback onAddArea;
  final VoidCallback onDelete;

  const _DayColumn({
    required this.day,
    required this.stays,
    this.tripStartDate,
    required this.itineraryDao,
    required this.areaDao,
    required this.spotDao,
    required this.tripId,
    required this.spotTimes,
    required this.skippedSpots,
    required this.onAddArea,
    required this.onDelete,
  });

  Future<void> _addHotelItem(String type) async {
    final items = await itineraryDao.watchDayItems(day.id).first;
    await itineraryDao.addHotelItem(
      dayId: day.id,
      itemType: type,
      order: items.length,
    );
  }

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.dayN(day.dayNumber),
                        style: Theme.of(context).textTheme.titleMedium),
                    if (tripStartDate != null)
                      Text(
                        _formatDate(tripStartDate!.add(Duration(days: day.dayNumber - 1))),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                      ),
                  ],
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: l10n.addAreaToDay,
                  onSelected: (v) {
                    if (v == 'area') {
                      onAddArea();
                    } else {
                      _addHotelItem(v);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'area', child: Row(children: [
                      const Icon(Icons.map, size: 18), const SizedBox(width: 8),
                      Text(l10n.addAreaToDay),
                    ])),
                    PopupMenuItem(value: 'checkin', child: Row(children: [
                      const Icon(Icons.login, size: 18), const SizedBox(width: 8),
                      Text(l10n.addCheckin),
                    ])),
                    PopupMenuItem(value: 'checkout', child: Row(children: [
                      const Icon(Icons.logout, size: 18), const SizedBox(width: 8),
                      Text(l10n.addCheckout),
                    ])),
                    PopupMenuItem(value: 'luggage', child: Row(children: [
                      const Icon(Icons.luggage, size: 18), const SizedBox(width: 8),
                      Text(l10n.addLuggage),
                    ])),
                  ],
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.dropSpotsHere,
                            style: TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: l10n.removeDay,
                          color: Colors.red[300],
                        ),
                      ],
                    ),
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final ids = items.map((i) => i.id).toList();
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    itineraryDao.reorderItems(ids);
                  },
                  itemBuilder: (context, index) => _AreaCard(
                    key: ValueKey(items[index].id),
                    index: index,
                    item: items[index],
                    stays: stays,
                    dayNumber: day.dayNumber,
                    tripStartDate: tripStartDate,
                    areaDao: areaDao,
                    spotDao: spotDao,
                    itineraryDao: itineraryDao,
                    tripId: tripId,
                    spotTimes: spotTimes,
                    skippedSpots: skippedSpots,
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

class _AreaCard extends StatelessWidget {
  final int index;
  final DayItem item;
  final List<HotelStay> stays;
  final int dayNumber;
  final DateTime? tripStartDate;
  final AreaDao areaDao;
  final SpotDao spotDao;
  final ItineraryDao itineraryDao;
  final String tripId;
  final Map<String, int> spotTimes;
  final Set<String> skippedSpots;

  const _AreaCard({
    super.key,
    required this.index,
    required this.item,
    required this.stays,
    required this.dayNumber,
    this.tripStartDate,
    required this.areaDao,
    required this.spotDao,
    required this.itineraryDao,
    required this.tripId,
    required this.spotTimes,
    required this.skippedSpots,
  });

  static ({IconData icon, String label}) _hotelItemInfo(AppLocalizations l10n, String type) => switch (type) {
    'checkin' => (icon: Icons.login, label: l10n.addCheckin),
    'checkout' => (icon: Icons.logout, label: l10n.addCheckout),
    'luggage' => (icon: Icons.luggage, label: l10n.addLuggage),
    _ => (icon: Icons.help_outline, label: type),
  };

  Future<void> _editAreaDuration(BuildContext context, Area area) async {
    final controller = TextEditingController(text: '${area.estimatedDurationMinutes}');
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.durationMin),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'min'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (result != null) {
      areaDao.updateArea(area.id, estimatedDurationMinutes: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hotel items (checkin/checkout/luggage) — no area
    if (item.areaId == null) {
      final l10n = AppLocalizations.of(context)!;
      final info = _hotelItemInfo(l10n, item.itemType);
      // ponytail: checkout references previous night's hotel
      final lookupDay = item.itemType == 'checkout' ? dayNumber - 1 : dayNumber;
      final hasHotel = ItineraryDao.hotelForDay(stays, lookupDay) != null;
      final itemTime = item.startTimeMinutes;
      final itemTimeStr = itemTime != null
          ? '${(itemTime ~/ 60).toString().padLeft(2, '0')}:${(itemTime % 60).toString().padLeft(2, '0')}'
          : null;
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: hasHotel ? Colors.purple[50] : Colors.red[50],
        child: InkWell(
          onTap: () async {
            final result = await pickOrClearTime(context, current: itemTime, defaultTime: const TimeOfDay(hour: 12, minute: 0));
            if (result == null) return;
            itineraryDao.setItemTimes(item.id, startMinutes: result == -1 ? null : result);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                Icon(info.icon, size: 16, color: hasHotel ? Colors.purple : Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(info.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: hasHotel ? Colors.purple : Colors.red,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                if (itemTimeStr != null)
                  Text(itemTimeStr,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                if (!hasHotel)
                  Tooltip(
                    message: l10n.noHotel,
                    child: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => itineraryDao.removeItem(item.id),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<Area?>(
      future: areaDao.getById(item.areaId!),
      builder: (context, snapshot) {
        final area = snapshot.data;

        if (snapshot.connectionState == ConnectionState.done && area == null) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(AppLocalizations.of(context)!.missingReference,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => itineraryDao.removeItem(item.id),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          );
        }

        final name = area?.name ?? '...';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(
                  children: [
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
                          if (area != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _editAreaDuration(context, area),
                              child: Text(
                                '${area.estimatedDurationMinutes ~/ 60}h${area.estimatedDurationMinutes % 60 > 0 ? '${area.estimatedDurationMinutes % 60}m' : ''}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.grey[500],
                                      decoration: TextDecoration.underline,
                                      decorationStyle: TextDecorationStyle.dotted,
                                    ),
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
                stream: spotDao.watchByArea(item.areaId!),
                builder: (context, snap) {
                  final spots = (snap.data ?? [])
                      .where((s) => s.type != 'hotel')
                      .toList();
                  final totalMin = spots.where((s) => !skippedSpots.contains(s.id)).fold<int>(0, (s, sp) => s + sp.estimatedVisitDurationMinutes + sp.bufferTimeMinutes);
                  final overBudget = area != null && totalMin > area.estimatedDurationMinutes;
                  return Column(
                    children: [
                      if (overBudget)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${totalMin ~/ 60}h${totalMin % 60 > 0 ? '${totalMin % 60}m' : ''} / ${area.estimatedDurationMinutes ~/ 60}h',
                                style: TextStyle(fontSize: 10, color: Colors.amber[800]),
                              ),
                            ],
                          ),
                        ),
                      ...spots
                        .map((spot) {
                          final skipped = skippedSpots.contains(spot.id);
                          final timeMin = spotTimes[spot.id];
                          final timeStr = timeMin != null
                              ? '${(timeMin ~/ 60).toString().padLeft(2, '0')}:${(timeMin % 60).toString().padLeft(2, '0')}'
                              : null;
                          return Opacity(
                            opacity: skipped ? 0.4 : 1.0,
                            child: InkWell(
                              onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: spot.id))),
                              onLongPress: () => itineraryDao.toggleSkipped(tripId, spot.id),
                              child: Padding(
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
                                    if (!skipped) ...[
                                      GestureDetector(
                                        onTap: () async {
                                          final result = await pickOrClearTime(context, current: timeMin);
                                          if (result == null) return;
                                          itineraryDao.setSpotTime(tripId, spot.id, result == -1 ? null : result);
                                        },
                                        child: timeStr != null
                                            ? Text(timeStr,
                                                style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                                            : Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                                      ),
                                      if (timeMin != null)
                                        _OpenHoursWarning(
                                          spotDao: spotDao,
                                          spotId: spot.id,
                                          timeMinutes: timeMin,
                                          tripStartDate: tripStartDate,
                                          dayNumber: dayNumber,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
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
        'hotel' || 'checkin' || 'checkout' || 'luggage' => Colors.purple,
        'online' => Colors.teal,
        'custom' => Colors.grey,
        _ => Colors.blue,
      };
}

class _RegionRow extends StatelessWidget {
  final List<ItineraryDay> days;
  final ItineraryDao itineraryDao;
  final AreaDao areaDao;
  final RegionDao regionDao;
  final ScrollController scrollController;

  const _RegionRow({
    required this.days,
    required this.itineraryDao,
    required this.areaDao,
    required this.regionDao,
    required this.scrollController,
  });

  Future<List<String?>> _resolveRegionIds() async {
    final result = <String?>[];
    for (final day in days) {
      final items = await itineraryDao.watchDayItems(day.id).first;
      if (items.isEmpty) {
        result.add(null);
        continue;
      }
      final firstAreaId = items.map((i) => i.areaId).whereType<String>().firstOrNull;
      if (firstAreaId == null) {
        result.add(null);
        continue;
      }
      final area = await areaDao.getById(firstAreaId);
      result.add(area?.regionId);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
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

          final segments = <({String? regionId, int startCol, int span})>[];
          var i = 0;
          while (i < regionIds.length) {
            final rid = regionIds[i];
            var span = 1;
            while (
                i + span < regionIds.length && regionIds[i + span] == rid) {
              span++;
            }
            segments.add((regionId: rid, startCol: i, span: span));
            i += span;
          }

          return AnimatedBuilder(
            animation: scrollController,
            builder: (context, _) {
              final scrollOffset = scrollController.hasClients
                  ? scrollController.offset
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: segments.map((seg) {
                    final width = seg.span * 208.0 - 8.0;
                    if (seg.regionId == null) {
                      return SizedBox(width: width + 8.0);
                    }
                    // ponytail: sticky text — shift content right when segment is partially scrolled off
                    final segStart = seg.startCol * 208.0;
                    final stickyPad = (scrollOffset - segStart).clamp(0.0, width - 80.0).toDouble();

                    return Container(
                      width: width,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal[200]!),
                      ),
                      clipBehavior: Clip.hardEdge,
                      padding: EdgeInsets.only(left: 8 + stickyPad, right: 8),
                      child: FutureBuilder<Region?>(
                        future: regionDao.getById(seg.regionId!),
                        builder: (context, snap) {
                          final missing = snap.connectionState == ConnectionState.done && snap.data == null;
                          return Row(
                            children: [
                              Icon(missing ? Icons.warning_amber_rounded : Icons.map,
                                  size: 14, color: missing ? Colors.red : Colors.teal),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(missing
                                        ? AppLocalizations.of(context)!.missingReference
                                        : (snap.data?.name ?? '...'),
                                    style: TextStyle(fontSize: 12, color: missing ? Colors.red : null),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
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
          return FutureBuilder<Spot?>(
            future: spotDao.getById(seg.stay!.spotId),
            builder: (context, snap) {
              final missing = snap.connectionState == ConnectionState.done && snap.data == null;
              return Container(
                width: width,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: missing ? Colors.red[50] : Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: missing ? Colors.red[200]! : Colors.purple[200]!),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(missing ? Icons.warning_amber_rounded : Icons.hotel,
                        size: 14, color: missing ? Colors.red : Colors.purple),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(missing
                              ? AppLocalizations.of(context)!.missingReference
                              : (snap.data?.name ?? '...'),
                          style: TextStyle(fontSize: 12, color: missing ? Colors.red : null),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(AppLocalizations.of(context)!.nightsCount(seg.span),
                        style: TextStyle(
                            fontSize: 11, color: Colors.purple[400])),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _AddDayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddDayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 180,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Icon(Icons.add, color: Colors.grey[500]),
        ),
      ),
    );
  }
}

class _OpenHoursWarning extends StatelessWidget {
  final SpotDao spotDao;
  final String spotId;
  final int timeMinutes;
  final DateTime? tripStartDate;
  final int dayNumber;

  const _OpenHoursWarning({
    required this.spotDao,
    required this.spotId,
    required this.timeMinutes,
    this.tripStartDate,
    required this.dayNumber,
  });

  @override
  Widget build(BuildContext context) {
    if (tripStartDate == null) return const SizedBox.shrink();
    final dow = tripStartDate!.add(Duration(days: dayNumber - 1)).weekday % 7;

    return FutureBuilder<List<SpotOpeningHoursEntry>>(
      future: spotDao.getOpeningHours(spotId),
      builder: (context, snap) {
        final hours = snap.data;
        if (hours == null || hours.isEmpty) return const SizedBox.shrink();
        final todayHours = hours.where((h) => h.day == dow).toList();
        if (todayHours.isEmpty) return const SizedBox.shrink();
        final inRange = todayHours.any((h) {
          final crossesMidnight = h.closeMinutes <= h.openMinutes;
          return crossesMidnight
              ? (timeMinutes >= h.openMinutes || timeMinutes < h.closeMinutes)
              : (timeMinutes >= h.openMinutes && timeMinutes < h.closeMinutes);
        });
        if (inRange) return const SizedBox.shrink();
        final ranges = todayHours
            .map((h) => '${_fmt(h.openMinutes)}–${_fmt(h.closeMinutes)}')
            .join(', ');
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: ranges,
            child: const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
          ),
        );
      },
    );
  }

  static String _fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}
