import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/services/transport_service.dart';
import 'package:myroad/widgets/spot_block.dart';
import 'package:myroad/widgets/spots_map.dart';
import 'package:myroad/widgets/transport_arrow.dart';

class ItineraryViewStage extends ConsumerStatefulWidget {
  final String tripId;

  const ItineraryViewStage({super.key, required this.tripId});

  @override
  ConsumerState<ItineraryViewStage> createState() => _ItineraryViewStageState();
}

class _ItineraryViewStageState extends ConsumerState<ItineraryViewStage> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.list), icon: const Icon(Icons.list)),
              ButtonSegment(value: true, label: Text(l10n.map), icon: const Icon(Icons.map)),
            ],
            selected: {_showMap},
            onSelectionChanged: (v) => setState(() => _showMap = v.first),
          ),
        ),
        Expanded(
          child: _showMap
              ? _MapView(tripId: widget.tripId)
              : _ListView(tripId: widget.tripId),
        ),
      ],
    );
  }

}

class _ListView extends ConsumerWidget {
  final String tripId;
  const _ListView({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(appDatabaseProvider);
    final itineraryDao = ref.watch(itineraryDaoProvider);
    final zoneDao = ref.watch(zoneDaoProvider);
    final spotDao = ref.watch(spotDaoProvider);

    return StreamBuilder<List<ItineraryDay>>(
      stream: itineraryDao.watchDays(tripId),
      builder: (context, snapshot) {
        final days = snapshot.data ?? [];
        if (days.isEmpty) return Center(child: Text(l10n.noItineraryDays));

        return StreamBuilder<List<HotelStay>>(
          stream: itineraryDao.watchHotelStays(tripId),
          builder: (context, staysSnap) {
            final stays = staysSnap.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: days.length,
              itemBuilder: (context, dayIndex) {
                final day = days[dayIndex];
                return _DaySpotList(
                  day: day,
                  stays: stays,
                  db: db,
                  itineraryDao: itineraryDao,
                  zoneDao: zoneDao,
                  spotDao: spotDao,
                  tripId: tripId,
                  isLast: dayIndex == days.length - 1,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Flattens zones into a spot-level list with transport arrows between each pair.
class _DaySpotList extends StatelessWidget {
  final ItineraryDay day;
  final List<HotelStay> stays;
  final AppDatabase db;
  final ItineraryDao itineraryDao;
  final ZoneDao zoneDao;
  final SpotDao spotDao;
  final String tripId;
  final bool isLast;

  const _DaySpotList({
    required this.day,
    required this.stays,
    required this.db,
    required this.itineraryDao,
    required this.zoneDao,
    required this.spotDao,
    required this.tripId,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hotel = ItineraryDao.hotelForDay(stays, day.dayNumber);
    final prevHotel = day.dayNumber > 1
        ? ItineraryDao.hotelForDay(stays, day.dayNumber - 1)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.dayN(day.dayNumber), style: Theme.of(context).textTheme.titleLarge),
        ),
        StreamBuilder<List<DayItem>>(
          stream: itineraryDao.watchDayItems(day.id),
          builder: (context, itemSnap) {
            final items = itemSnap.data ?? [];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(l10n.noSpotsInZone, style: TextStyle(color: Colors.grey[500])),
              );
            }

            return _FlatSpotListBuilder(
              items: items,
              zoneDao: zoneDao,
              spotDao: spotDao,
              db: db,
              tripId: tripId,
              prevHotelSpotId: prevHotel?.spotId,
              hotelSpotId: hotel?.spotId,
              stays: stays,
              dayNumber: day.dayNumber,
            );
          },
        ),
        if (!isLast) const Divider(indent: 16, endIndent: 16),
      ],
    );
  }
}

class _FlatSpotListBuilder extends StatelessWidget {
  final List<DayItem> items;
  final ZoneDao zoneDao;
  final SpotDao spotDao;
  final AppDatabase db;
  final String tripId;
  final String? prevHotelSpotId;
  final String? hotelSpotId;
  final List<HotelStay> stays;
  final int dayNumber;

  const _FlatSpotListBuilder({
    required this.items,
    required this.zoneDao,
    required this.spotDao,
    required this.db,
    required this.tripId,
    this.prevHotelSpotId,
    this.hotelSpotId,
    required this.stays,
    required this.dayNumber,
  });

  // Entry = either a spot from a zone, or a hotel action (checkin/checkout/luggage)
  Future<List<_ViewEntry>> _buildEntries() async {
    final result = <_ViewEntry>[];
    for (final item in items) {
      if (item.zoneId != null) {
        final zone = await zoneDao.getById(item.zoneId!);
        final spots = await spotDao.watchByZone(item.zoneId!).first;
        for (final spot in spots.where((s) => s.type != 'hotel')) {
          result.add(_ViewEntry.spot(spot: spot, zoneName: zone?.name));
        }
      } else {
        final lookupDay = item.itemType == 'checkout' ? dayNumber - 1 : dayNumber;
        final hotel = ItineraryDao.hotelForDay(stays, lookupDay);
        Spot? hotelSpot;
        if (hotel != null) {
          hotelSpot = await spotDao.getById(hotel.spotId);
        }
        result.add(_ViewEntry.hotelAction(
          itemType: item.itemType,
          hotelSpot: hotelSpot,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<_ViewEntry>>(
      future: _buildEntries(),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        if (entries.isEmpty) return const SizedBox.shrink();

        final widgets = <Widget>[];
        String? lastZoneName;

        // Previous day hotel departure
        if (prevHotelSpotId != null && entries.isNotEmpty) {
          widgets.add(_HotelBlock(spotId: prevHotelSpotId!, spotDao: spotDao));
          final firstSpotId = entries.first.spotId;
          if (firstSpotId != null) {
            widgets.add(_SpotPairTransport(
              db: db, tripId: tripId,
              fromSpotId: prevHotelSpotId!, toSpotId: firstSpotId,
            ));
          }
        }

        for (var i = 0; i < entries.length; i++) {
          final e = entries[i];

          if (e.isHotelAction) {
            final label = switch (e.itemType) {
              'checkin' => l10n.addCheckin,
              'checkout' => l10n.addCheckout,
              'luggage' => l10n.addLuggage,
              _ => e.itemType!,
            };
            final hotelName = e.hotelSpot?.name;
            widgets.add(SpotBlock(
              name: hotelName != null ? '$label — $hotelName' : label,
              type: e.itemType!,
              warning: hotelName == null ? l10n.noHotel : null,
            ));
          } else {
            if (e.zoneName != lastZoneName) {
              lastZoneName = e.zoneName;
              widgets.add(Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
                child: Text(
                  e.zoneName ?? '...',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ));
            }
            widgets.add(SpotBlock(
              name: e.spot!.name,
              type: e.spot!.type,
              subtitle: '${e.spot!.estimatedVisitDurationMinutes}min',
            ));
          }

          // Transport to next entry
          if (i < entries.length - 1) {
            final fromId = e.spotId;
            final toId = entries[i + 1].spotId;
            if (fromId != null && toId != null) {
              widgets.add(_SpotPairTransport(
                db: db, tripId: tripId,
                fromSpotId: fromId, toSpotId: toId,
              ));
            }
          }
        }

        // Last entry → hotel
        if (hotelSpotId != null && entries.isNotEmpty) {
          final lastSpotId = entries.last.spotId;
          if (lastSpotId != null) {
            widgets.add(_SpotPairTransport(
              db: db, tripId: tripId,
              fromSpotId: lastSpotId, toSpotId: hotelSpotId!,
            ));
          }
          widgets.add(_HotelBlock(spotId: hotelSpotId!, spotDao: spotDao));
        }

        return Column(children: widgets);
      },
    );
  }
}

class _ViewEntry {
  final Spot? spot;
  final String? zoneName;
  final String? itemType;
  final Spot? hotelSpot;

  _ViewEntry.spot({required Spot this.spot, this.zoneName})
      : itemType = null, hotelSpot = null;

  _ViewEntry.hotelAction({required String this.itemType, this.hotelSpot})
      : spot = null, zoneName = null;

  bool get isHotelAction => itemType != null;

  String? get spotId => isHotelAction ? hotelSpot?.id : spot?.id;
}

/// Looks up transports by (fromSpotId, toSpotId). Supports multiple legs. Tappable to edit.
class _SpotPairTransport extends ConsumerStatefulWidget {
  final AppDatabase db;
  final String tripId;
  final String fromSpotId;
  final String toSpotId;

  const _SpotPairTransport({
    required this.db,
    required this.tripId,
    required this.fromSpotId,
    required this.toSpotId,
  });

  @override
  ConsumerState<_SpotPairTransport> createState() => _SpotPairTransportState();
}

class _SpotPairTransportState extends ConsumerState<_SpotPairTransport> {
  List<Transport> _legs = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await (widget.db.select(widget.db.transports)
          ..where((t) =>
              t.fromSpotId.equals(widget.fromSpotId) &
              t.toSpotId.equals(widget.toSpotId)))
        .get();
    if (mounted) setState(() { _legs = results; _loaded = true; });
  }

  static String modeLabel(BuildContext context, String mode) {
    final l10n = AppLocalizations.of(context)!;
    return switch (mode) {
      'walk' => l10n.modeWalk,
      'transit' => l10n.modeTransit,
      'car' => l10n.modeCar,
      'motorcycle' => l10n.modeMotorcycle,
      _ => mode,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 20);

    return GestureDetector(
      onTap: () => _showEditSheet(context),
      child: _legs.isNotEmpty
          ? Column(
              children: _legs.map((t) => TransportArrow(
                mode: t.mode,
                durationMinutes: t.estimatedDurationMinutes,
                distanceMeters: t.distanceMeters,
                routeName: t.routeName,
                price: t.price,
              )).toList(),
            )
          : const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Icon(Icons.more_horiz, size: 16, color: Colors.grey),
                ],
              ),
            ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TransportEditSheet(
        db: widget.db,
        tripId: widget.tripId,
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        legs: _legs,
        transportService: ref.read(transportServiceProvider),
        onChanged: () async {
          await _load();
        },
      ),
    );
  }
}

class _TransportEditSheet extends StatefulWidget {
  final AppDatabase db;
  final String tripId;
  final String fromSpotId;
  final String toSpotId;
  final List<Transport> legs;
  final TransportService transportService;
  final VoidCallback onChanged;

  const _TransportEditSheet({
    required this.db,
    required this.tripId,
    required this.fromSpotId,
    required this.toSpotId,
    required this.legs,
    required this.transportService,
    required this.onChanged,
  });

  @override
  State<_TransportEditSheet> createState() => _TransportEditSheetState();
}

class _TransportEditSheetState extends State<_TransportEditSheet> {
  late List<Transport> _legs;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _legs = List.of(widget.legs);
  }

  Future<void> _reload() async {
    final results = await (widget.db.select(widget.db.transports)
          ..where((t) =>
              t.fromSpotId.equals(widget.fromSpotId) &
              t.toSpotId.equals(widget.toSpotId)))
        .get();
    if (mounted) setState(() => _legs = results);
    widget.onChanged();
  }

  Future<void> _fetchRoute() async {
    setState(() => _fetching = true);
    try {
      await widget.transportService.getOrFetchTransport(
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        tripId: widget.tripId,
        mode: 'walk',
      );
      await _reload();
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _addLeg() async {
    await widget.db.into(widget.db.transports).insert(
      TransportsCompanion.insert(
        tripId: widget.tripId,
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        estimatedDurationMinutes: 10,
      ),
    );
    await _reload();
  }

  Future<void> _deleteLeg(String id) async {
    await (widget.db.delete(widget.db.transports)..where((t) => t.id.equals(id))).go();
    await _reload();
  }

  Future<void> _updateLeg(String id, {required String mode, required int duration, String? routeName, String? price, String? notes}) async {
    await (widget.db.update(widget.db.transports)..where((t) => t.id.equals(id)))
        .write(TransportsCompanion(
      mode: Value(mode),
      estimatedDurationMinutes: Value(duration),
      routeName: Value(routeName),
      price: Value(price),
      notes: Value(notes),
    ));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _legs.isEmpty ? l10n.addTransport : l10n.editTransport,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _legs.length; i++)
              _LegEditor(
                leg: _legs[i],
                index: i,
                onUpdate: (mode, duration, {routeName, price, notes}) =>
                    _updateLeg(_legs[i].id, mode: mode, duration: duration, routeName: routeName, price: price, notes: notes),
                onDelete: () => _deleteLeg(_legs[i].id),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _addLeg,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addLeg),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _fetching ? null : _fetchRoute,
                  icon: _fetching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.route, size: 18),
                  label: Text(_fetching ? l10n.fetchingRoute : l10n.fetchRoute),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.done),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegEditor extends StatefulWidget {
  final Transport leg;
  final int index;
  final void Function(String mode, int duration, {String? routeName, String? price, String? notes}) onUpdate;
  final VoidCallback onDelete;

  const _LegEditor({
    required this.leg,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_LegEditor> createState() => _LegEditorState();
}

class _LegEditorState extends State<_LegEditor> {
  late String _mode;
  late TextEditingController _durationCtrl;
  late TextEditingController _routeNameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _mode = widget.leg.mode;
    _durationCtrl = TextEditingController(text: '${widget.leg.estimatedDurationMinutes}');
    _routeNameCtrl = TextEditingController(text: widget.leg.routeName ?? '');
    _priceCtrl = TextEditingController(text: widget.leg.price ?? '');
    _notesCtrl = TextEditingController(text: widget.leg.notes ?? '');
  }

  @override
  void didUpdateWidget(_LegEditor old) {
    super.didUpdateWidget(old);
    if (old.leg.id != widget.leg.id) {
      _mode = widget.leg.mode;
      _durationCtrl.text = '${widget.leg.estimatedDurationMinutes}';
      _routeNameCtrl.text = widget.leg.routeName ?? '';
      _priceCtrl.text = widget.leg.price ?? '';
      _notesCtrl.text = widget.leg.notes ?? '';
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _routeNameCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  static IconData _modeIcon(String mode) => switch (mode) {
    'transit' => Icons.directions_bus,
    'car' => Icons.directions_car,
    'motorcycle' => Icons.motorcycle,
    'bicycle' => Icons.directions_bike,
    _ => Icons.directions_walk,
  };

  void _save() {
    widget.onUpdate(
      _mode,
      int.tryParse(_durationCtrl.text) ?? widget.leg.estimatedDurationMinutes,
      routeName: _routeNameCtrl.text.isEmpty ? null : _routeNameCtrl.text,
      price: _priceCtrl.text.isEmpty ? null : _priceCtrl.text,
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final m in TransportMode.values)
                  ChoiceChip(
                    avatar: Icon(_modeIcon(m.value), size: 18),
                    label: Text(_SpotPairTransportState.modeLabel(context, m.value)),
                    selected: _mode == m.value,
                    onSelected: (_) {
                      setState(() => _mode = m.value);
                      _save();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.durationMin,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _save(),
                    onTapOutside: (_) => _save(),
                  ),
                ),
                if (widget.leg.distanceMeters != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.leg.distanceMeters! >= 1000
                        ? '${(widget.leg.distanceMeters! / 1000).toStringAsFixed(1)} km'
                        : '${widget.leg.distanceMeters!.round()} m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: widget.onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_mode == 'transit') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _routeNameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.routeName,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _save(),
                      onTapOutside: (_) => _save(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.price,
                        prefixText: '¥',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _save(),
                      onTapOutside: (_) => _save(),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: l10n.notes,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: null,
              onTapOutside: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotelBlock extends StatelessWidget {
  final String spotId;
  final SpotDao spotDao;

  const _HotelBlock({required this.spotId, required this.spotDao});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Spot?>(
      future: spotDao.getById(spotId),
      builder: (context, snap) {
        final spot = snap.data;
        return SpotBlock(
          name: spot?.name ?? '...',
          type: 'hotel',
        );
      },
    );
  }
}

// ponytail: map shows all spots from assigned zones, polyline routes when spot-level itinerary exists
class _MapView extends ConsumerStatefulWidget {
  final String tripId;
  const _MapView({required this.tripId});

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  int? _filterDay;

  @override
  Widget build(BuildContext context) {
    if (!SpotsMap.supported) {
      return const Center(child: Text('Map not available on this platform'));
    }

    final l10n = AppLocalizations.of(context)!;
    final itineraryDao = ref.watch(itineraryDaoProvider);
    final zoneDao = ref.watch(zoneDaoProvider);
    final spotDao = ref.watch(spotDaoProvider);

    return StreamBuilder<List<ItineraryDay>>(
      stream: itineraryDao.watchDays(widget.tripId),
      builder: (context, daysSnap) {
        final days = daysSnap.data ?? [];
        if (days.isEmpty) return Center(child: Text(l10n.noItineraryDays));

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l10n.allDays),
                      selected: _filterDay == null,
                      onSelected: (_) => setState(() => _filterDay = null),
                    ),
                  ),
                  ...days.map((day) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l10n.dayN(day.dayNumber)),
                      selected: _filterDay == day.dayNumber,
                      onSelected: (_) => setState(() => _filterDay = day.dayNumber),
                    ),
                  )),
                ],
              ),
            ),
            Expanded(
              child: _SpotsMapLoader(
                days: _filterDay == null ? days : days.where((d) => d.dayNumber == _filterDay).toList(),
                itineraryDao: itineraryDao,
                zoneDao: zoneDao,
                spotDao: spotDao,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpotsMapLoader extends StatelessWidget {
  final List<ItineraryDay> days;
  final ItineraryDao itineraryDao;
  final ZoneDao zoneDao;
  final SpotDao spotDao;

  const _SpotsMapLoader({
    required this.days,
    required this.itineraryDao,
    required this.zoneDao,
    required this.spotDao,
  });

  Future<List<MapSpot>> _loadSpots() async {
    final zoneIds = <String>{};
    for (final day in days) {
      final items = await itineraryDao.watchDayItems(day.id).first;
      for (final item in items) {
        if (item.zoneId != null) zoneIds.add(item.zoneId!);
      }
    }

    final spots = <MapSpot>[];
    for (final zoneId in zoneIds) {
      final zoneSpots = await spotDao.watchByZone(zoneId).first;
      for (final s in zoneSpots) {
        spots.add(MapSpot(id: s.id, name: s.name, type: s.type, lat: s.lat, lng: s.lng));
      }
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MapSpot>>(
      future: _loadSpots(),
      builder: (context, snapshot) {
        final spots = snapshot.data ?? [];
        return SpotsMap(spots: spots);
      },
    );
  }
}
