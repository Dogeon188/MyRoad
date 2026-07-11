import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/region_detail_screen.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/screens/trips/stages/itinerary_timeline.dart';
import 'package:myroad/screens/trips/stages/pass_dialog.dart';
import 'package:myroad/utils/url_helper.dart';
import 'package:myroad/widgets/time_picker_helper.dart';

export 'package:myroad/screens/trips/stages/itinerary_map_view.dart'
    show ItineraryMapStage;
export 'package:myroad/screens/trips/stages/pass_dialog.dart'
    show showPassDialog;

String _formatDate(DateTime d) =>
    '${d.month}/${d.day} ${DateFormat.E().format(d)}';

Widget emptyItinerary(
  BuildContext context,
  AppLocalizations l10n,
  ItineraryDao itineraryDao,
  String tripId,
) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.noItineraryDays),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
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
                      child: Text(l10n.cancel),
                    ),
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
              await itineraryDao.initializeDays(tripId, count);
            }
          },
          child: Text(l10n.initializeItinerary),
        ),
      ],
    ),
  );
}

Widget iosChip(
  BuildContext context,
  String label,
  bool selected,
  VoidCallback onTap, {
  VoidCallback? onLongPress,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}

class ItineraryListStage extends ConsumerStatefulWidget {
  final String tripId;
  const ItineraryListStage({super.key, required this.tripId});

  @override
  ConsumerState<ItineraryListStage> createState() => _ItineraryListStageState();
}

// ponytail: switched from single ScrollView (all days) to per-day subtabs — only one day renders at a time
class _ItineraryListStageState extends ConsumerState<ItineraryListStage> {
  int _selectedDay = 0;
  final _dayScrollController = ScrollController();

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  void _scrollToDay(int dayNumber, int totalDays) {
    if (!_dayScrollController.hasClients) return;
    // ponytail: estimate chip width (~100px each), center selected chip
    const chipWidth = 100.0;
    final target =
        (dayNumber - 1) * chipWidth -
        (_dayScrollController.position.viewportDimension / 2 - chipWidth / 2);
    _dayScrollController.animateTo(
      target.clamp(0.0, _dayScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(appDatabaseProvider);
    final itineraryDao = ref.watch(itineraryDaoProvider);
    final areaDao = ref.watch(areaDaoProvider);
    final spotDao = ref.watch(spotDaoProvider);

    final daysAsync = ref.watch(itineraryDaysProvider(widget.tripId));
    final tripStartDate = ref
        .watch(tripProvider(widget.tripId))
        .value
        ?.startDate;
    final days = daysAsync.value ?? [];
    final stays = ref.watch(hotelStaysProvider(widget.tripId)).value ?? [];
    final spotTimes = ref.watch(spotTimesProvider(widget.tripId)).value ?? {};
    final afterTransportSpots =
        ref.watch(afterTransportSpotsProvider(widget.tripId)).value ?? {};
    final skippedSpots =
        ref.watch(skippedSpotsProvider(widget.tripId)).value ?? {};
    if (daysAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (days.isEmpty) {
      return emptyItinerary(context, l10n, itineraryDao, widget.tripId);
    }

    // Auto-select today's day on first load
    if (_selectedDay == 0 && tripStartDate != null) {
      final todayDay = DateTime.now().difference(tripStartDate).inDays + 1;
      if (todayDay >= 1 && todayDay <= days.length) {
        _selectedDay = todayDay;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToDay(todayDay, days.length),
        );
      }
    }
    if (_selectedDay == 0) _selectedDay = 1;
    final clampedDay = _selectedDay.clamp(1, days.length);
    final currentDay = days.firstWhere((d) => d.dayNumber == clampedDay);

    return Column(
      children: [
        SingleChildScrollView(
          controller: _dayScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ...days.map((day) {
                final date = tripStartDate?.add(
                  Duration(days: day.dayNumber - 1),
                );
                final dateStr = date != null
                    ? ' ${date.month}/${date.day}'
                    : '';
                return iosChip(
                  context,
                  '${l10n.dayN(day.dayNumber)}$dateStr',
                  clampedDay == day.dayNumber,
                  () => setState(() => _selectedDay = day.dayNumber),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(clampedDay),
            padding: const EdgeInsets.only(bottom: 16),
            child: _DaySpotList(
              day: currentDay,
              stays: stays,
              db: db,
              itineraryDao: itineraryDao,
              areaDao: areaDao,
              spotDao: spotDao,
              tripId: widget.tripId,
              tripStartDate: tripStartDate,
              spotTimes: spotTimes,
              afterTransportSpots: afterTransportSpots,
              skippedSpots: skippedSpots,
              isLast: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final ItineraryDay day;
  final DateTime? tripStartDate;
  final ItineraryDao itineraryDao;
  final AreaDao areaDao;
  final AppDatabase db;

  const _DayHeader({
    required this.day,
    required this.tripStartDate,
    required this.itineraryDao,
    required this.areaDao,
    required this.db,
  });

  Future<List<String>> _resolveRegionNames(List<DayItem> items) async {
    final regionNames = <String>{};
    for (final item in items) {
      if (item.areaId == null) continue;
      final area = await areaDao.getById(item.areaId!);
      if (area == null) continue;
      final region = await (db.select(
        db.regions,
      )..where((r) => r.id.equals(area.regionId))).getSingleOrNull();
      if (region != null) regionNames.add(region.name);
    }
    return regionNames.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = tripStartDate?.add(Duration(days: day.dayNumber - 1));

    return StreamBuilder<List<DayItem>>(
      stream: itineraryDao.watchDayItems(day.id),
      builder: (context, snap) {
        return FutureBuilder<List<String>>(
          future: _resolveRegionNames(snap.data ?? []),
          builder: (context, regionSnap) {
            final names = regionSnap.data ?? [];
            final dateStr = date != null ? ' ${_formatDate(date)}' : '';
            final regionStr = names.isNotEmpty ? ' @ ${names.join(', ')}' : '';

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${l10n.dayN(day.dayNumber)}$dateStr',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (regionStr.isNotEmpty)
                      TextSpan(
                        text: regionStr,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Flattens areas into a spot-level list with transport arrows between each pair.
class _DaySpotList extends ConsumerWidget {
  final ItineraryDay day;
  final List<HotelStay> stays;
  final AppDatabase db;
  final ItineraryDao itineraryDao;
  final AreaDao areaDao;
  final SpotDao spotDao;
  final String tripId;
  final DateTime? tripStartDate;
  final Map<String, int> spotTimes;
  final Set<String> afterTransportSpots;
  final Set<String> skippedSpots;
  final bool isLast;

  const _DaySpotList({
    required this.day,
    required this.stays,
    required this.db,
    required this.itineraryDao,
    required this.areaDao,
    required this.spotDao,
    required this.tripId,
    this.tripStartDate,
    required this.spotTimes,
    required this.afterTransportSpots,
    required this.skippedSpots,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hotel = ItineraryDao.hotelForDay(stays, day.dayNumber);
    final prevHotel = day.dayNumber > 1
        ? ItineraryDao.hotelForDay(stays, day.dayNumber - 1)
        : null;
    final itemsAsync = ref.watch(dayItemsProvider(day.id));
    final items = itemsAsync.value ?? [];
    final allPasses = ref.watch(travelPassesProvider(tripId)).value ?? [];
    final dayPasses = itineraryDao.passesForDay(allPasses, day.dayNumber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayHeader(
          day: day,
          tripStartDate: tripStartDate,
          itineraryDao: itineraryDao,
          areaDao: areaDao,
          db: db,
        ),
        if (dayPasses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: dayPasses
                  .map(
                    (pass) => GestureDetector(
                      onTap: () => showPassDialog(
                        context,
                        itineraryDao,
                        tripId,
                        ref.read(itineraryDaysProvider(tripId)).value?.length ??
                            1,
                        existing: pass,
                      ),
                      child: Chip(
                        avatar: Icon(
                          Icons.confirmation_number,
                          size: 16,
                          color: pass.bought ? Colors.green : Colors.orange,
                        ),
                        label: Text(
                          pass.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        deleteIcon: pass.url != null
                            ? const Icon(Icons.open_in_new, size: 14)
                            : null,
                        onDeleted: pass.url != null
                            ? () => launchUrl(
                                externalUri(pass.url!),
                                mode: LaunchMode.externalApplication,
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (itemsAsync.isLoading)
          const TimelineSkeleton()
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.noSpotsInArea,
              style: TextStyle(color: Colors.grey[500]),
            ),
          )
        else
          _FlatSpotListBuilder(
            items: items,
            areaDao: areaDao,
            spotDao: spotDao,
            db: db,
            tripId: tripId,
            itineraryDao: itineraryDao,
            day: day,
            tripStartDate: tripStartDate,
            prevHotelSpotId: prevHotel?.spotId,
            hotelSpotId: hotel?.spotId,
            stays: stays,
            dayNumber: day.dayNumber,
            spotTimes: spotTimes,
            afterTransportSpots: afterTransportSpots,
            skippedSpots: skippedSpots,
          ),
        if (!isLast) const Divider(indent: 16, endIndent: 16),
      ],
    );
  }
}

class _ViewEntry {
  final Spot? spot;
  final String? areaName;
  final String? itemType;
  final Spot? hotelSpot;
  final int? timeMinutes;
  final String? dayItemId;
  final String? openWarning;
  final bool skipped;
  final String currencyPrefix;

  final String? areaId;
  final String? regionId;

  _ViewEntry.spot({
    required Spot this.spot,
    this.areaName,
    this.areaId,
    this.regionId,
    this.timeMinutes,
    this.openWarning,
    this.skipped = false,
    this.currencyPrefix = '',
  }) : itemType = null,
       hotelSpot = null,
       dayItemId = null;

  _ViewEntry.hotelAction({
    required String this.itemType,
    this.hotelSpot,
    this.timeMinutes,
    this.dayItemId,
  }) : spot = null,
       areaName = null,
       areaId = null,
       regionId = null,
       openWarning = null,
       skipped = false,
       currencyPrefix = '';

  bool get isHotelAction => itemType != null;

  String? get spotId => isHotelAction ? hotelSpot?.id : spot?.id;
}

class _FlatSpotListBuilder extends StatefulWidget {
  final List<DayItem> items;
  final AreaDao areaDao;
  final SpotDao spotDao;
  final AppDatabase db;
  final String tripId;
  final ItineraryDao itineraryDao;
  final ItineraryDay day;
  final DateTime? tripStartDate;
  final String? prevHotelSpotId;
  final String? hotelSpotId;
  final List<HotelStay> stays;
  final int dayNumber;
  final Map<String, int> spotTimes;
  final Set<String> afterTransportSpots;
  final Set<String> skippedSpots;

  const _FlatSpotListBuilder({
    required this.items,
    required this.areaDao,
    required this.spotDao,
    required this.db,
    required this.tripId,
    required this.itineraryDao,
    required this.day,
    this.tripStartDate,
    this.prevHotelSpotId,
    this.hotelSpotId,
    required this.stays,
    required this.dayNumber,
    required this.spotTimes,
    required this.afterTransportSpots,
    required this.skippedSpots,
  });

  @override
  State<_FlatSpotListBuilder> createState() => _FlatSpotListBuilderState();
}

class _FlatSpotListBuilderState extends State<_FlatSpotListBuilder> {
  late Future<List<_ViewEntry>> _entriesFuture;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _entriesFuture = _buildEntries();
      _initialized = true;
    }
  }

  @override
  void didUpdateWidget(_FlatSpotListBuilder old) {
    super.didUpdateWidget(old);
    if (old.items != widget.items ||
        old.stays != widget.stays ||
        old.spotTimes != widget.spotTimes ||
        old.afterTransportSpots != widget.afterTransportSpots ||
        old.skippedSpots != widget.skippedSpots ||
        old.day != widget.day) {
      _entriesFuture = _buildEntries();
    }
  }

  int? _dayOfWeek() {
    if (widget.tripStartDate == null) return null;
    return widget.tripStartDate!
            .add(Duration(days: widget.dayNumber - 1))
            .weekday %
        7;
  }

  DateTime? _dateTimeAt(int? minutes) {
    if (widget.tripStartDate == null || minutes == null) return null;
    final day = widget.tripStartDate!.add(Duration(days: widget.dayNumber - 1));
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: minutes));
  }

  Future<String?> _checkOpeningHours(
    AppLocalizations l10n,
    Spot spot,
    int? timeMinutes,
  ) async {
    final dow = _dayOfWeek();
    if (dow == null) return null;
    final hours = await widget.spotDao.getOpeningHours(spot.id);
    if (hours.isEmpty) return null;
    final todayHours = hours.where((h) => h.day == dow).toList();
    if (todayHours.isEmpty) return l10n.warningClosedAllDay;
    if (timeMinutes == null) return null;
    for (final h in todayHours) {
      final crossesMidnight = h.closeMinutes <= h.openMinutes;
      final inRange = crossesMidnight
          ? (timeMinutes >= h.openMinutes || timeMinutes < h.closeMinutes)
          : (timeMinutes >= h.openMinutes && timeMinutes < h.closeMinutes);
      if (inRange) {
        return null;
      }
    }
    final ranges = todayHours
        .map(
          (h) => '${formatTime(h.openMinutes)}–${formatTime(h.closeMinutes)}',
        )
        .join(', ');
    return l10n.warningClosed(formatTime(timeMinutes), ranges);
  }

  Future<List<_ViewEntry>> _buildEntries() async {
    final l10n = AppLocalizations.of(context)!;
    final result = <_ViewEntry>[];
    int? lastTime;
    int? lastEndTime;
    for (final item in widget.items) {
      if (item.areaId != null) {
        final area = await widget.areaDao.getById(item.areaId!);
        String areaPrefix = '';
        if (area != null) {
          final region = await (widget.db.select(
            widget.db.regions,
          )..where((r) => r.id.equals(area.regionId))).getSingleOrNull();
          if (region != null) areaPrefix = currencySymbol(region.currency);
        }
        final spots = await widget.spotDao.watchByArea(item.areaId!).first;
        for (final spot in spots.where((s) => s.type != 'hotel')) {
          final time = widget.spotTimes[spot.id];
          String? warning = await _checkOpeningHours(l10n, spot, time);
          if (time != null) {
            if (warning == null && lastTime != null) {
              if (time < lastTime) {
                warning = l10n.warningOutOfOrder(formatTime(lastTime));
              } else if (lastEndTime != null && time < lastEndTime) {
                warning = l10n.warningOverlap(formatTime(lastEndTime));
              }
            }
            lastTime = time;
            lastEndTime =
                time +
                spot.estimatedVisitDurationMinutes +
                spot.bufferTimeMinutes;
          }
          result.add(
            _ViewEntry.spot(
              spot: spot,
              areaName: area?.name,
              areaId: area?.id,
              regionId: area?.regionId,
              timeMinutes: time,
              openWarning: warning,
              skipped: widget.skippedSpots.contains(spot.id),
              currencyPrefix: areaPrefix,
            ),
          );
        }
      } else {
        final lookupDay = item.itemType == 'checkout'
            ? widget.dayNumber - 1
            : widget.dayNumber;
        final hotel = ItineraryDao.hotelForDay(widget.stays, lookupDay);
        Spot? hotelSpot;
        if (hotel != null) {
          hotelSpot = await widget.spotDao.getById(hotel.spotId);
        }
        result.add(
          _ViewEntry.hotelAction(
            itemType: item.itemType,
            hotelSpot: hotelSpot,
            timeMinutes: item.startTimeMinutes,
            dayItemId: item.id,
          ),
        );
      }
    }
    return result;
  }

  void _openSpot(BuildContext context, String spotId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: spotId)),
    );
  }

  void Function(BuildContext) _spotTimeTap(String spotId, int? current) {
    return (context) async {
      final result = await pickOrClearTime(context, current: current);
      if (result == null) return;
      widget.itineraryDao.setSpotTime(
        widget.tripId,
        spotId,
        result == -1 ? null : result,
      );
    };
  }

  void Function(BuildContext) _dayTimeTap(
    String dayId,
    int? current, {
    required bool isDeparture,
  }) {
    return (context) async {
      final result = await pickOrClearTime(
        context,
        current: current,
        defaultTime: TimeOfDay(hour: isDeparture ? 9 : 20, minute: 0),
      );
      if (result == null) return;
      final minutes = result == -1 ? null : result;
      if (isDeparture) {
        widget.itineraryDao.setDayDepartureTime(dayId, minutes);
      } else {
        widget.itineraryDao.setDayArrivalTime(dayId, minutes);
      }
    };
  }

  void Function(BuildContext) _itemTimeTap(String itemId, int? current) {
    return (context) async {
      final result = await pickOrClearTime(
        context,
        current: current,
        defaultTime: const TimeOfDay(hour: 12, minute: 0),
      );
      if (result == null) return;
      widget.itineraryDao.setItemTimes(
        itemId,
        startMinutes: result == -1 ? null : result,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<_ViewEntry>>(
      future: _entriesFuture,
      builder: (context, snap) {
        final entries = snap.data ?? [];
        if (entries.isEmpty) return const SizedBox.shrink();

        // Build a flat list of timeline rows: spots/actions interleaved with transports
        final rows = <TimelineRow>[];
        String? lastAreaName;
        String? lastPhysicalSpotId;
        int? lastTimeMinutes;

        if (widget.prevHotelSpotId != null) {
          final depTime = widget.day.departureTimeMinutes;
          rows.add(
            TimelineRow.hotel(
              spotId: widget.prevHotelSpotId!,
              spotDao: widget.spotDao,
              timeMinutes: depTime,
              onTimeTap: _dayTimeTap(widget.day.id, depTime, isDeparture: true),
              onTap: () => _openSpot(context, widget.prevHotelSpotId!),
            ),
          );
          lastPhysicalSpotId = widget.prevHotelSpotId;
          lastTimeMinutes = depTime;
        }

        // Collect deferred online spots (afterTransport=true) to insert after next transport
        final deferredOnline = <TimelineRow>[];

        for (final e in entries) {
          final isOnline = e.spot?.type == 'online';
          final physId = e.isHotelAction
              ? e.spotId
              : (!isOnline && !e.skipped ? e.spotId : null);

          if (physId != null && lastPhysicalSpotId != null) {
            rows.add(
              TimelineRow.transport(
                db: widget.db,
                tripId: widget.tripId,
                fromSpotId: lastPhysicalSpotId,
                toSpotId: physId,
                departTime: _dateTimeAt(lastTimeMinutes),
                arrivalTime: _dateTimeAt(e.timeMinutes),
              ),
            );
            // Insert deferred online spots after this transport
            rows.addAll(deferredOnline);
            deferredOnline.clear();
          }

          if (e.isHotelAction) {
            final label = switch (e.itemType) {
              'checkin' => l10n.addCheckin,
              'checkout' => l10n.addCheckout,
              'luggage' => l10n.addLuggage,
              _ => e.itemType!,
            };
            final hotelName = e.hotelSpot?.name;
            rows.add(
              TimelineRow.spot(
                name: hotelName != null ? '$label — $hotelName' : label,
                type: e.itemType!,
                iconCode: e.hotelSpot?.iconCode,
                colorValue: e.hotelSpot?.colorValue,
                timeMinutes: e.timeMinutes,
                warning: hotelName == null ? l10n.noHotel : null,
                url: e.hotelSpot?.url,
                onTap: e.hotelSpot != null
                    ? () => _openSpot(context, e.hotelSpot!.id)
                    : null,
                onTimeTap: e.dayItemId != null
                    ? _itemTimeTap(e.dayItemId!, e.timeMinutes)
                    : null,
              ),
            );
          } else {
            final showArea = e.areaName != lastAreaName;
            if (showArea) lastAreaName = e.areaName;
            final spotRow = TimelineRow.spot(
              name: e.spot!.name,
              type: e.spot!.type,
              iconCode: e.spot!.iconCode,
              colorValue: e.spot!.colorValue,
              timeMinutes: e.skipped ? null : e.timeMinutes,
              subtitle: () {
                final parts = [
                  if (e.spot!.type != 'transfer')
                    '${e.spot!.estimatedVisitDurationMinutes}min',
                  if (e.spot!.price != null && e.spot!.price!.isNotEmpty)
                    '${e.currencyPrefix}${e.spot!.price!}',
                ];
                return parts.isEmpty ? null : parts.join(' · ');
              }(),
              note: e.spot!.notes.isNotEmpty ? e.spot!.notes : null,
              areaLabel: showArea ? e.areaName : null,
              onAreaTap:
                  showArea &&
                      e.areaId != null &&
                      e.regionId != null &&
                      e.areaName != null
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LibraryAreaDetailPage(
                          areaId: e.areaId!,
                          areaName: e.areaName!,
                          regionId: e.regionId!,
                          tripId: widget.tripId,
                        ),
                      ),
                    )
                  : null,
              warning: e.openWarning != null && !e.skipped
                  ? e.openWarning
                  : null,
              url: e.spot!.url,
              onTap: () => _openSpot(context, e.spot!.id),
              onLongPress: () =>
                  widget.itineraryDao.toggleSkipped(widget.tripId, e.spot!.id),
              onTimeTap: e.skipped
                  ? null
                  : _spotTimeTap(e.spot!.id, e.timeMinutes),
              skipped: e.skipped,
            );
            if (isOnline && widget.afterTransportSpots.contains(e.spot!.id)) {
              deferredOnline.add(spotRow);
            } else {
              rows.add(spotRow);
            }
          }

          if (physId != null) {
            lastPhysicalSpotId = physId;
            lastTimeMinutes = e.timeMinutes;
          }
        }
        // Flush any remaining deferred online spots
        rows.addAll(deferredOnline);

        if (widget.hotelSpotId != null && lastPhysicalSpotId != null) {
          final arrTime = widget.day.arrivalTimeMinutes;
          rows.add(
            TimelineRow.transport(
              db: widget.db,
              tripId: widget.tripId,
              fromSpotId: lastPhysicalSpotId,
              toSpotId: widget.hotelSpotId!,
              departTime: _dateTimeAt(lastTimeMinutes),
              arrivalTime: _dateTimeAt(arrTime),
            ),
          );
          rows.add(
            TimelineRow.hotel(
              spotId: widget.hotelSpotId!,
              spotDao: widget.spotDao,
              timeMinutes: arrTime,
              onTimeTap: _dayTimeTap(
                widget.day.id,
                arrTime,
                isDeparture: false,
              ),
              onTap: () => _openSpot(context, widget.hotelSpotId!),
            ),
          );
        }

        return Timeline(rows: rows);
      },
    );
  }
}
