import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/api/directions_api_client.dart';
import 'package:myroad/services/transport_service.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/widgets/spots_map.dart';
import 'package:myroad/widgets/time_picker_helper.dart';
import 'package:myroad/widgets/transport_arrow.dart';

String _formatDate(DateTime d) => '${d.month}/${d.day}';

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

class _ListView extends ConsumerStatefulWidget {
  final String tripId;
  const _ListView({required this.tripId});

  @override
  ConsumerState<_ListView> createState() => _ListViewState();
}

class _ListViewState extends ConsumerState<_ListView> {
  final _scrollController = ScrollController();
  final _dayContexts = <int, BuildContext>{};
  int _visibleDay = 1;
  bool _navVisible = false;
  bool _navHeld = false;
  int _totalDays = 0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    _showNav();
    _updateVisibleDay();
  }

  void _showNav() {
    if (!_navVisible) setState(() => _navVisible = true);
    _hideTimer?.cancel();
    if (_navHeld) return;
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_navHeld) setState(() => _navVisible = false);
    });
  }

  void _updateVisibleDay() {
    if (!mounted) return;
    int best = 1;
    for (final entry in _dayContexts.entries) {
      final box = entry.value.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
      if (pos.dy <= 80) best = entry.key;
    }
    if (best != _visibleDay) setState(() => _visibleDay = best);
  }

  void _scrollToDay(int dayNumber) {
    final ctx = _dayContexts[dayNumber];
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
    }
  }

  void _registerDayContext(int dayNumber, BuildContext ctx) {
    _dayContexts[dayNumber] = ctx;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.watch(appDatabaseProvider);
    final itineraryDao = ref.watch(itineraryDaoProvider);
    final areaDao = ref.watch(areaDaoProvider);
    final spotDao = ref.watch(spotDaoProvider);
    final tripDao = ref.watch(tripDaoProvider);

    return StreamBuilder<Trip?>(
      stream: tripDao.watchById(widget.tripId),
      builder: (context, tripSnap) {
        final tripStartDate = tripSnap.data?.startDate;

        return StreamBuilder<List<ItineraryDay>>(
          stream: itineraryDao.watchDays(widget.tripId),
          builder: (context, snapshot) {
            final days = snapshot.data ?? [];
            if (days.isEmpty) return Center(child: Text(l10n.noItineraryDays));
            _totalDays = days.length;

            return StreamBuilder<List<HotelStay>>(
              stream: itineraryDao.watchHotelStays(widget.tripId),
              builder: (context, staysSnap) {
                final stays = staysSnap.data ?? [];

                return StreamBuilder<Map<String, int>>(
                  stream: itineraryDao.watchSpotTimes(widget.tripId),
                  builder: (context, timesSnap) {
                    final spotTimes = timesSnap.data ?? {};

                    return StreamBuilder<Set<String>>(
                      stream: itineraryDao.watchAfterTransportSpots(widget.tripId),
                      builder: (context, afterSnap) {
                        final afterTransportSpots = afterSnap.data ?? {};

                        return StreamBuilder<Set<String>>(
                          stream: itineraryDao.watchSkippedSpots(widget.tripId),
                          builder: (context, skippedSnap) {
                            final skippedSpots = skippedSnap.data ?? {};

                        return Stack(
                          children: [
                            SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                children: [
                                  for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                                    Builder(
                                      builder: (dayCtx) {
                                        _registerDayContext(days[dayIndex].dayNumber, dayCtx);
                                        return _DaySpotList(
                                          day: days[dayIndex],
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
                                          isLast: dayIndex == days.length - 1,
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            if (_navVisible && _totalDays > 1)
                              Positioned(
                                right: 4,
                                top: 8,
                                bottom: 8,
                                child: MouseRegion(
                                  onEnter: (_) { _navHeld = true; _hideTimer?.cancel(); },
                                  onExit: (_) { _navHeld = false; _showNav(); },
                                  child: Listener(
                                    onPointerDown: (_) { _navHeld = true; _hideTimer?.cancel(); },
                                    onPointerUp: (_) { _navHeld = false; _showNav(); },
                                    onPointerCancel: (_) { _navHeld = false; _showNav(); },
                                    child: _DayNavOverlay(
                                      totalDays: _totalDays,
                                      visibleDay: _visibleDay,
                                      onDayTap: _scrollToDay,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
      },
    );
  }
}

class _DayNavOverlay extends StatefulWidget {
  final int totalDays;
  final int visibleDay;
  final void Function(int) onDayTap;

  const _DayNavOverlay({
    required this.totalDays,
    required this.visibleDay,
    required this.onDayTap,
  });

  @override
  State<_DayNavOverlay> createState() => _DayNavOverlayState();
}

class _DayNavOverlayState extends State<_DayNavOverlay> {
  final _chipScroll = ScrollController();
  static const _itemExtent = 30.0; // 28 height + 2 margin

  @override
  void didUpdateWidget(_DayNavOverlay old) {
    super.didUpdateWidget(old);
    if (old.visibleDay != widget.visibleDay) _scrollToVisible();
  }

  void _scrollToVisible() {
    if (!_chipScroll.hasClients) return;
    final target = (widget.visibleDay - 1) * _itemExtent;
    final viewport = _chipScroll.position.viewportDimension;
    final current = _chipScroll.offset;
    if (target < current) {
      _chipScroll.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    } else if (target + _itemExtent > current + viewport) {
      _chipScroll.animateTo(target + _itemExtent - viewport, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _chipScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - 100),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: SingleChildScrollView(
            controller: _chipScroll,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.totalDays, (i) {
                final day = i + 1;
                final isCurrent = day == widget.visibleDay;
                return GestureDetector(
                  onTap: () => widget.onDayTap(day),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    decoration: BoxDecoration(
                      color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
    );
  }
}

/// Flattens areas into a spot-level list with transport arrows between each pair.
class _DaySpotList extends StatelessWidget {
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
          child: Row(
            children: [
              Text(l10n.dayN(day.dayNumber), style: Theme.of(context).textTheme.titleLarge),
              if (tripStartDate != null) ...[
                const SizedBox(width: 8),
                Text(
                  _formatDate(tripStartDate!.add(Duration(days: day.dayNumber - 1))),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
        StreamBuilder<List<DayItem>>(
          stream: itineraryDao.watchDayItems(day.id),
          builder: (context, itemSnap) {
            final items = itemSnap.data ?? [];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(l10n.noSpotsInArea, style: TextStyle(color: Colors.grey[500])),
              );
            }

            return _FlatSpotListBuilder(
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
            );
          },
        ),
        if (!isLast) const Divider(indent: 16, endIndent: 16),
      ],
    );
  }
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

  @override
  void initState() {
    super.initState();
    _entriesFuture = _buildEntries();
  }

  @override
  void didUpdateWidget(_FlatSpotListBuilder old) {
    super.didUpdateWidget(old);
    if (old.items != widget.items || old.stays != widget.stays || old.spotTimes != widget.spotTimes || old.afterTransportSpots != widget.afterTransportSpots || old.skippedSpots != widget.skippedSpots || old.day != widget.day) {
      _entriesFuture = _buildEntries();
    }
  }

  int? _dayOfWeek() {
    if (widget.tripStartDate == null) return null;
    return widget.tripStartDate!.add(Duration(days: widget.dayNumber - 1)).weekday % 7;
  }

  Future<String?> _checkOpeningHours(Spot spot, int timeMinutes) async {
    final dow = _dayOfWeek();
    if (dow == null) return null;
    final hours = await widget.spotDao.getOpeningHours(spot.id);
    final todayHours = hours.where((h) => h.day == dow).toList();
    if (todayHours.isEmpty) return null;
    for (final h in todayHours) {
      if (timeMinutes >= h.openMinutes && timeMinutes < h.closeMinutes) return null;
    }
    final ranges = todayHours
        .map((h) => '${_formatTime(h.openMinutes)}–${_formatTime(h.closeMinutes)}')
        .join(', ');
    return ranges;
  }

  Future<List<_ViewEntry>> _buildEntries() async {
    final result = <_ViewEntry>[];
    int? lastTime;
    int? lastEndTime;
    for (final item in widget.items) {
      if (item.areaId != null) {
        final area = await widget.areaDao.getById(item.areaId!);
        final spots = await widget.spotDao.watchByArea(item.areaId!).first;
        for (final spot in spots.where((s) => s.type != 'hotel')) {
          final time = widget.spotTimes[spot.id];
          String? warning;
          if (time != null) {
            warning = await _checkOpeningHours(spot, time);
            if (warning == null && lastTime != null) {
              if (time < lastTime) {
                warning = '↕ out of order';
              } else if (lastEndTime != null && time < lastEndTime) {
                warning = '↕ overlaps previous (ends ${_formatTime(lastEndTime)})';
              }
            }
            lastTime = time;
            lastEndTime = time + spot.estimatedVisitDurationMinutes + spot.bufferTimeMinutes;
          }
          result.add(_ViewEntry.spot(
            spot: spot,
            areaName: area?.name,
            timeMinutes: time,
            openWarning: warning,
            skipped: widget.skippedSpots.contains(spot.id),
          ));
        }
      } else {
        final lookupDay = item.itemType == 'checkout' ? widget.dayNumber - 1 : widget.dayNumber;
        final hotel = ItineraryDao.hotelForDay(widget.stays, lookupDay);
        Spot? hotelSpot;
        if (hotel != null) {
          hotelSpot = await widget.spotDao.getById(hotel.spotId);
        }
        result.add(_ViewEntry.hotelAction(
          itemType: item.itemType,
          hotelSpot: hotelSpot,
          timeMinutes: item.startTimeMinutes,
          dayItemId: item.id,
        ));
      }
    }
    return result;
  }

  void _openSpot(BuildContext context, String spotId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: spotId)));
  }

  void Function(BuildContext) _spotTimeTap(String spotId, int? current) {
    return (context) async {
      final result = await pickOrClearTime(context, current: current);
      if (result == null) return;
      widget.itineraryDao.setSpotTime(widget.tripId, spotId, result == -1 ? null : result);
    };
  }

  void Function(BuildContext) _dayTimeTap(String dayId, int? current, {required bool isDeparture}) {
    return (context) async {
      final result = await pickOrClearTime(context, current: current,
          defaultTime: TimeOfDay(hour: isDeparture ? 9 : 20, minute: 0));
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
      final result = await pickOrClearTime(context, current: current,
          defaultTime: const TimeOfDay(hour: 12, minute: 0));
      if (result == null) return;
      widget.itineraryDao.setItemTimes(itemId, startMinutes: result == -1 ? null : result);
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
        final rows = <_TimelineRow>[];
        String? lastAreaName;
        String? lastPhysicalSpotId;

        if (widget.prevHotelSpotId != null) {
          final depTime = widget.day.departureTimeMinutes;
          rows.add(_TimelineRow.hotel(
            spotId: widget.prevHotelSpotId!, spotDao: widget.spotDao,
            timeMinutes: depTime,
            onTimeTap: _dayTimeTap(widget.day.id, depTime, isDeparture: true),

          ));
          lastPhysicalSpotId = widget.prevHotelSpotId;
        }

        // Collect deferred online spots (afterTransport=true) to insert after next transport
        final deferredOnline = <_TimelineRow>[];

        for (final e in entries) {
          final isOnline = e.spot?.type == 'online';
          final physId = e.isHotelAction ? e.spotId : (!isOnline && !e.skipped ? e.spotId : null);

          if (physId != null && lastPhysicalSpotId != null) {
            rows.add(_TimelineRow.transport(
              db: widget.db, tripId: widget.tripId,
              fromSpotId: lastPhysicalSpotId, toSpotId: physId,
            ));
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
            rows.add(_TimelineRow.spot(
              name: hotelName != null ? '$label — $hotelName' : label,
              type: e.itemType!,
              timeMinutes: e.timeMinutes,
              warning: hotelName == null ? l10n.noHotel : null,
              onTap: e.hotelSpot != null ? () => _openSpot(context, e.hotelSpot!.id) : null,
              onTimeTap: e.dayItemId != null ? _itemTimeTap(e.dayItemId!, e.timeMinutes) : null,

            ));
          } else {
            final showArea = e.areaName != lastAreaName;
            if (showArea) lastAreaName = e.areaName;
            final spotRow = _TimelineRow.spot(
              name: e.spot!.name,
              type: e.spot!.type,
              timeMinutes: e.skipped ? null : e.timeMinutes,
              subtitle: '${e.spot!.estimatedVisitDurationMinutes}min',
              areaLabel: showArea ? e.areaName : null,
              warning: e.openWarning != null && !e.skipped ? '⏰ ${e.openWarning}' : null,
              onTap: () => _openSpot(context, e.spot!.id),
              onLongPress: () => widget.itineraryDao.toggleSkipped(widget.tripId, e.spot!.id),
              onTimeTap: e.skipped ? null : _spotTimeTap(e.spot!.id, e.timeMinutes),
              skipped: e.skipped,

            );
            if (isOnline && widget.afterTransportSpots.contains(e.spot!.id)) {
              deferredOnline.add(spotRow);
            } else {
              rows.add(spotRow);
            }
          }

          if (physId != null) lastPhysicalSpotId = physId;
        }
        // Flush any remaining deferred online spots
        rows.addAll(deferredOnline);

        if (widget.hotelSpotId != null && lastPhysicalSpotId != null) {
          rows.add(_TimelineRow.transport(
            db: widget.db, tripId: widget.tripId,
            fromSpotId: lastPhysicalSpotId, toSpotId: widget.hotelSpotId!,
          ));
          final arrTime = widget.day.arrivalTimeMinutes;
          rows.add(_TimelineRow.hotel(
            spotId: widget.hotelSpotId!, spotDao: widget.spotDao,
            timeMinutes: arrTime,
            onTimeTap: _dayTimeTap(widget.day.id, arrTime, isDeparture: false),

          ));
        }

        return _Timeline(rows: rows);
      },
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

  _ViewEntry.spot({required Spot this.spot, this.areaName, this.timeMinutes, this.openWarning, this.skipped = false})
      : itemType = null, hotelSpot = null, dayItemId = null;

  _ViewEntry.hotelAction({required String this.itemType, this.hotelSpot, this.timeMinutes, this.dayItemId})
      : spot = null, areaName = null, openWarning = null, skipped = false;

  bool get isHotelAction => itemType != null;

  String? get spotId => isHotelAction ? hotelSpot?.id : spot?.id;
}

String _formatTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

enum _RowKind { spot, transport, hotel }

class _TimelineRow {
  final _RowKind kind;
  final String? name;
  final String? type;
  final int? timeMinutes;
  final String? subtitle;
  final String? areaLabel;
  final String? warning;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(BuildContext context)? onTimeTap;
  final bool skipped;

  // transport fields
  final AppDatabase? db;
  final String? tripId;
  final String? fromSpotId;
  final String? toSpotId;
  // hotel fields
  final String? hotelSpotId;
  final SpotDao? spotDao;

  _TimelineRow._({
    required this.kind, this.name, this.type, this.timeMinutes,
    this.subtitle, this.areaLabel, this.warning, this.onTap, this.onLongPress,
    this.onTimeTap, this.skipped = false,
    this.db, this.tripId, this.fromSpotId, this.toSpotId,
    this.hotelSpotId, this.spotDao,
  });

  factory _TimelineRow.spot({
    required String name, required String type, int? timeMinutes,
    String? subtitle, String? areaLabel, String? warning, VoidCallback? onTap,
    VoidCallback? onLongPress,
    void Function(BuildContext context)? onTimeTap, bool skipped = false,
  }) => _TimelineRow._(kind: _RowKind.spot, name: name, type: type,
      timeMinutes: timeMinutes, subtitle: subtitle, areaLabel: areaLabel,
      warning: warning, onTap: onTap, onLongPress: onLongPress,
      onTimeTap: onTimeTap, skipped: skipped);

  factory _TimelineRow.transport({
    required AppDatabase db, required String tripId,
    required String fromSpotId, required String toSpotId,
  }) => _TimelineRow._(kind: _RowKind.transport, db: db, tripId: tripId,
      fromSpotId: fromSpotId, toSpotId: toSpotId);

  factory _TimelineRow.hotel({
    required String spotId, required SpotDao spotDao,
    int? timeMinutes, void Function(BuildContext context)? onTimeTap,
  }) => _TimelineRow._(kind: _RowKind.hotel, hotelSpotId: spotId, spotDao: spotDao,
      timeMinutes: timeMinutes, onTimeTap: onTimeTap);
}

class _Timeline extends StatelessWidget {
  final List<_TimelineRow> rows;
  const _Timeline({required this.rows});

  static Color _spotColor(String type) => switch (type) {
    'restaurant' => Colors.orange,
    'hotel' || 'checkin' || 'checkout' || 'luggage' => Colors.purple,
    'online' => Colors.teal,
    'custom' => Colors.grey,
    _ => Colors.blue,
  };

  static IconData _spotIcon(String type) => switch (type) {
    'restaurant' => Icons.restaurant,
    'hotel' => Icons.hotel,
    'checkin' => Icons.login,
    'checkout' => Icons.logout,
    'luggage' => Icons.luggage,
    'online' => Icons.videocam,
    'custom' => Icons.star_outline,
    _ => Icons.place,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          _buildRow(context, rows[i], isFirst: i == 0, isLast: i == rows.length - 1),
      ],
    );
  }

  Widget _buildRow(BuildContext context, _TimelineRow row, {required bool isFirst, required bool isLast}) {
    if (row.kind == _RowKind.transport) {
      return _TransportTimelineRow(row: row, isFirst: isFirst, isLast: isLast);
    }
    if (row.kind == _RowKind.hotel) {
      return _HotelTimelineRow(row: row, isFirst: isFirst, isLast: isLast);
    }
    // Spot row
    final color = _spotColor(row.type!);
    final lineColor = Colors.grey[300]!;
    return Opacity(
      opacity: row.skipped ? 0.4 : 1.0,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (row.areaLabel != null)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Center(child: Container(width: 2, color: isFirst ? Colors.transparent : lineColor)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 8, 16, 2),
                      child: Text(row.areaLabel!,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Timeline dot + line
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Expanded(child: Center(child: Container(width: 2, color: isFirst && row.areaLabel == null ? Colors.transparent : lineColor))),
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      Expanded(child: Center(child: Container(width: 2, color: isLast ? Colors.transparent : lineColor))),
                    ],
                  ),
                ),
                // Time column — separate gesture target from the spot InkWell
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: row.onTimeTap != null ? () => row.onTimeTap!(context) : null,

                  child: SizedBox(
                    width: 44,
                    child: Center(
                      child: row.timeMinutes != null
                          ? Text(_formatTime(row.timeMinutes!),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                              textAlign: TextAlign.center)
                          : row.onTimeTap != null
                              ? Icon(Icons.access_time, size: 14, color: Colors.grey[400])
                              : null,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Spot info
                Expanded(
                  child: InkWell(
                    onTap: row.onTap,
                    onLongPress: row.onLongPress,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: row.warning != null ? Colors.red.withValues(alpha: 0.08) : color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: row.warning != null ? Colors.red.withValues(alpha: 0.6) : color.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(_spotIcon(row.type!), color: color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.name!, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
                                if (row.subtitle != null)
                                  Text(row.subtitle!, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          if (row.warning != null)
                            Tooltip(message: row.warning!, child: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }
}

class _TransportTimelineRow extends ConsumerStatefulWidget {
  final _TimelineRow row;
  final bool isFirst;
  final bool isLast;
  const _TransportTimelineRow({required this.row, required this.isFirst, required this.isLast});

  @override
  ConsumerState<_TransportTimelineRow> createState() => _TransportTimelineRowState();
}

class _TransportTimelineRowState extends ConsumerState<_TransportTimelineRow> {
  List<Transport> _legs = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await (widget.row.db!.select(widget.row.db!.transports)
          ..where((t) =>
              t.fromSpotId.equals(widget.row.fromSpotId!) &
              t.toSpotId.equals(widget.row.toSpotId!)))
        .get();
    if (mounted) setState(() { _legs = results; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 24);

    return GestureDetector(
      onTap: () => _showEditSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Timeline line (no dot for transport)
              SizedBox(
                width: 20,
                child: Center(child: Container(width: 2, color: Colors.grey[300])),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _legs.isNotEmpty
                      ? Column(
                          children: _legs.map((t) => TransportArrow(
                            mode: t.mode,
                            durationMinutes: t.estimatedDurationMinutes,
                            distanceMeters: t.distanceMeters,
                            routeName: t.routeName,
                            price: t.price,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                          )).toList(),
                        )
                      : Row(
                          children: [
                            Icon(Icons.add_circle_outline, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(AppLocalizations.of(context)!.tapToAddTransport,
                                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final rootMessenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TransportEditSheet(
        db: widget.row.db!,
        tripId: widget.row.tripId!,
        fromSpotId: widget.row.fromSpotId!,
        toSpotId: widget.row.toSpotId!,
        legs: _legs,
        transportService: ref.read(transportServiceProvider),
        onChanged: () async { await _load(); },
        rootMessenger: rootMessenger,
      ),
    );
  }
}

class _HotelTimelineRow extends StatelessWidget {
  final _TimelineRow row;
  final bool isFirst;
  final bool isLast;
  const _HotelTimelineRow({required this.row, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Spot?>(
      future: row.spotDao!.getById(row.hotelSpotId!),
      builder: (context, snap) {
        final missing = snap.connectionState == ConnectionState.done && snap.data == null;
        final name = missing
            ? AppLocalizations.of(context)!.missingReference
            : (snap.data?.name ?? '...');
        final color = Colors.purple;
        final lineColor = Colors.grey[300]!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Expanded(child: Center(child: Container(width: 2, color: isFirst ? Colors.transparent : lineColor))),
                      Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                      Expanded(child: Center(child: Container(width: 2, color: isLast ? Colors.transparent : lineColor))),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: row.onTimeTap != null ? () => row.onTimeTap!(context) : null,

                  child: SizedBox(
                    width: 44,
                    child: Center(
                      child: row.timeMinutes != null
                          ? Text(_formatTime(row.timeMinutes!),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                              textAlign: TextAlign.center)
                          : row.onTimeTap != null
                              ? Icon(Icons.access_time, size: 14, color: Colors.grey[400])
                              : null,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hotel, color: color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13))),
                        if (missing) const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _modeLabel(BuildContext context, String mode) {
  final l10n = AppLocalizations.of(context)!;
  return switch (mode) {
    'walk' => l10n.modeWalk,
    'transit' => l10n.modeTransit,
    'car' => l10n.modeCar,
    'bicycle' => l10n.modeBicycle,
    _ => mode,
  };
}

class _TransportEditSheet extends StatefulWidget {
  final AppDatabase db;
  final String tripId;
  final String fromSpotId;
  final String toSpotId;
  final List<Transport> legs;
  final TransportService transportService;
  final VoidCallback onChanged;
  final ScaffoldMessengerState rootMessenger;

  const _TransportEditSheet({
    required this.db,
    required this.tripId,
    required this.fromSpotId,
    required this.toSpotId,
    required this.legs,
    required this.transportService,
    required this.onChanged,
    required this.rootMessenger,
  });

  @override
  State<_TransportEditSheet> createState() => _TransportEditSheetState();
}

class _TransportEditSheetState extends State<_TransportEditSheet> {
  late List<Transport> _legs;
  bool _fetching = false;
  String _fetchMode = 'walk';
  bool _reordering = false;
  Spot? _transitUnavailableFrom;
  Spot? _transitUnavailableTo;

  @override
  void initState() {
    super.initState();
    _legs = List.of(widget.legs);
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final trip = await (widget.db.select(widget.db.trips)
          ..where((t) => t.id.equals(widget.tripId)))
        .getSingleOrNull();
    final pref = trip?.transportPreference ?? 'walk';
    if (mounted) setState(() => _fetchMode = pref == 'motorcycle' ? 'bicycle' : pref);

    final spots = await Future.wait([
      (widget.db.select(widget.db.spots)..where((t) => t.id.equals(widget.fromSpotId))).getSingleOrNull(),
      (widget.db.select(widget.db.spots)..where((t) => t.id.equals(widget.toSpotId))).getSingleOrNull(),
    ]);
    if (!mounted) return;
    final from = spots[0];
    final to = spots[1];
    if (from != null && to != null &&
        (addressInJapan(from.address) || addressInJapan(to.address))) {
      setState(() {
        _transitUnavailableFrom = from;
        _transitUnavailableTo = to;
      });
    }
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
      final options = await widget.transportService.fetchRouteOptions(
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        mode: _fetchMode,
      );
      if (!mounted) return;

      if (options.isEmpty) {
        if (_fetchMode == 'transit') {
          _showTransitUnavailable();
        } else {
          _showOverlaySnackBar(context, AppLocalizations.of(context)!.noRouteFound);
        }
        return;
      }

      final chosen = options.length == 1
          ? options[0]
          : await _pickRoute(options);
      if (chosen == null) return;

      await widget.transportService.applyRoute(
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        tripId: widget.tripId,
        route: chosen,
      );
      await _reload();
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _showOverlaySnackBar(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.inverseSurface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface)),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), entry.remove);
  }

  Future<void> _showTransitUnavailable() async {
    final spots = await Future.wait([
      (widget.db.select(widget.db.spots)..where((t) => t.id.equals(widget.fromSpotId))).getSingleOrNull(),
      (widget.db.select(widget.db.spots)..where((t) => t.id.equals(widget.toSpotId))).getSingleOrNull(),
    ]);
    if (!mounted) return;
    final from = spots[0];
    final to = spots[1];
    setState(() {
      _transitUnavailableFrom = from;
      _transitUnavailableTo = to;
    });
  }

  Future<RouteOption?> _pickRoute(List<RouteOption> options) {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<RouteOption>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.pickRoute, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final opt in options)
              ListTile(
                leading: const Icon(Icons.route),
                title: Text(opt.summary),
                subtitle: Text('${opt.totalDurationMinutes} min · ${_formatDist(opt.totalDistanceMeters)}'),
                onTap: () => Navigator.pop(ctx, opt),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  Future<void> _addLeg() async {
    await widget.db.into(widget.db.transports).insert(
      TransportsCompanion.insert(
        tripId: widget.tripId,
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        mode: Value(_fetchMode),
        estimatedDurationMinutes: 10,
      ),
    );
    await _reload();
  }

  Future<void> _deleteLeg(String id) async {
    await (widget.db.delete(widget.db.transports)..where((t) => t.id.equals(id))).go();
    await _reload();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _legs.removeAt(oldIndex);
      _legs.insert(newIndex, item);
    });
    _saveOrder();
  }

  Future<void> _saveOrder() async {
    final ordered = List.of(_legs);
    for (final leg in ordered) {
      await (widget.db.delete(widget.db.transports)..where((t) => t.id.equals(leg.id))).go();
    }
    for (final leg in ordered) {
      await widget.db.into(widget.db.transports).insert(
        TransportsCompanion.insert(
          id: Value(leg.id),
          tripId: widget.tripId,
          fromSpotId: widget.fromSpotId,
          toSpotId: widget.toSpotId,
          mode: Value(leg.mode),
          estimatedDurationMinutes: leg.estimatedDurationMinutes,
          distanceMeters: Value(leg.distanceMeters),
          routePolyline: Value(leg.routePolyline),
          routeName: Value(leg.routeName),
          price: Value(leg.price),
          notes: Value(leg.notes),
        ),
      );
    }
    widget.onChanged();
  }

  Future<void> _updateLeg(String id, {required String mode, required int duration, String? routeName, String? price, String? notes}) async {
    await (widget.db.update(widget.db.transports)..where((t) => t.id.equals(id)))
        .write(TransportsCompanion(
      mode: Value(mode),
      estimatedDurationMinutes: Value(duration),
      distanceMeters: mode == 'transit' ? const Value(null) : const Value.absent(),
      routeName: Value(routeName),
      price: Value(price),
      notes: Value(notes),
    ));
    await _reload();
  }

  static IconData _modeIcon(String mode) => switch (mode) {
    'transit' => Icons.directions_bus,
    'car' => Icons.directions_car,
    'bicycle' => Icons.directions_bike,
    _ => Icons.directions_walk,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _legs.isEmpty ? l10n.addTransport : l10n.editTransport,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_legs.length > 1)
                  IconButton(
                    icon: Icon(_reordering ? Icons.check : Icons.swap_vert, size: 20),
                    onPressed: () => setState(() => _reordering = !_reordering),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_reordering)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _legs.length,
                onReorderItem: _onReorder,
                itemBuilder: (context, i) {
                  final leg = _legs[i];
                  return Card(
                    key: ValueKey(leg.id),
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Icon(Icons.drag_handle, size: 20),
                          ),
                          const SizedBox(width: 8),
                          Icon(_modeIcon(leg.mode), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              [
                                _modeLabel(context, leg.mode),
                                '${leg.estimatedDurationMinutes}min',
                                if (leg.routeName != null) leg.routeName!,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            else ...[
              for (var i = 0; i < _legs.length; i++)
                _LegEditor(
                  leg: _legs[i],
                  index: i,
                  onUpdate: (mode, duration, {routeName, price, notes}) =>
                      _updateLeg(_legs[i].id, mode: mode, duration: duration, routeName: routeName, price: price, notes: notes),
                  onDelete: () => _deleteLeg(_legs[i].id),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addLeg,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addLeg),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _fetchMode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: TransportMode.values.map((m) => DropdownMenuItem(
                      value: m.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_modeIcon(m.value), size: 18),
                          const SizedBox(width: 8),
                          Text(_modeLabel(context, m.value)),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() { _fetchMode = v; _transitUnavailableFrom = null; _transitUnavailableTo = null; });
                    },
                  ),
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
            if (_transitUnavailableFrom != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.transitUnavailable, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 13))),
                      if (_transitUnavailableFrom!.lat != null && _transitUnavailableTo?.lat != null)
                        TextButton.icon(
                          onPressed: () {
                            final uri = Uri.parse(
                              'https://www.google.com/maps/dir/?api=1'
                              '&origin=${_transitUnavailableFrom!.lat},${_transitUnavailableFrom!.lng}'
                              '&destination=${_transitUnavailableTo!.lat},${_transitUnavailableTo!.lng}'
                              '&travelmode=transit',
                            );
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(l10n.openInGoogleMaps),
                        ),
                    ],
                  ),
                ),
              ),
            ],
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
    _mode = _migrateMode(widget.leg.mode);
    _durationCtrl = TextEditingController(text: '${widget.leg.estimatedDurationMinutes}');
    _routeNameCtrl = TextEditingController(text: widget.leg.routeName ?? '');
    _priceCtrl = TextEditingController(text: widget.leg.price ?? '');
    _notesCtrl = TextEditingController(text: widget.leg.notes ?? '');
  }

  static String _migrateMode(String mode) => mode == 'motorcycle' ? 'bicycle' : mode;

  @override
  void didUpdateWidget(_LegEditor old) {
    super.didUpdateWidget(old);
    if (old.leg.id != widget.leg.id) {
      _mode = _migrateMode(widget.leg.mode);
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _mode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: TransportMode.values.map((m) => DropdownMenuItem(
                      value: m.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_modeIcon(m.value), size: 18),
                          const SizedBox(width: 8),
                          Text(_modeLabel(context, m.value)),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _mode = v);
                      _save();
                    },
                  ),
                ),
                const SizedBox(width: 8),
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
                if (widget.leg.distanceMeters != null && _mode != 'transit') ...[
                  const SizedBox(width: 4),
                  Text(
                    widget.leg.distanceMeters! >= 1000
                        ? '${(widget.leg.distanceMeters! / 1000).toStringAsFixed(1)} km'
                        : '${widget.leg.distanceMeters!.round()} m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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

// ponytail: map shows all spots from assigned areas, polyline routes when spot-level itinerary exists
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
    final areaDao = ref.watch(areaDaoProvider);
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
                areaDao: areaDao,
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
  final AreaDao areaDao;
  final SpotDao spotDao;

  const _SpotsMapLoader({
    required this.days,
    required this.itineraryDao,
    required this.areaDao,
    required this.spotDao,
  });

  Future<List<MapSpot>> _loadSpots() async {
    final areaIds = <String>{};
    for (final day in days) {
      final items = await itineraryDao.watchDayItems(day.id).first;
      for (final item in items) {
        if (item.areaId != null) areaIds.add(item.areaId!);
      }
    }

    final spots = <MapSpot>[];
    for (final areaId in areaIds) {
      final areaSpots = await spotDao.watchByArea(areaId).first;
      for (final s in areaSpots) {
        if (s.lat != null && s.lng != null) {
          spots.add(MapSpot(id: s.id, name: s.name, type: s.type, lat: s.lat!, lng: s.lng!));
        }
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
        // ponytail: key forces map recreation on spot list change so bounds refit
        return SpotsMap(key: ValueKey(spots.map((s) => s.id).join(',')), spots: spots);
      },
    );
  }
}
