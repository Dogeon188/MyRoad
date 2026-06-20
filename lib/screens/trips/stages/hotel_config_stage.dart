import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';

class HotelConfigStage extends ConsumerStatefulWidget {
  final String tripId;

  const HotelConfigStage({super.key, required this.tripId});

  @override
  ConsumerState<HotelConfigStage> createState() => _HotelConfigStageState();
}

class _HotelConfigStageState extends ConsumerState<HotelConfigStage> {
  late final ItineraryDao _itineraryDao;
  late final SpotDao _spotDao;
  late final AreaDao _areaDao;
  late final RegionDao _regionDao;
  bool _showDates = false;

  @override
  void initState() {
    super.initState();
    _itineraryDao = ItineraryDao(ref.read(appDatabaseProvider));
    _spotDao = ref.read(spotDaoProvider);
    _areaDao = ref.read(areaDaoProvider);
    _regionDao = ref.read(regionDaoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final tripDao = ref.watch(tripDaoProvider);

    return StreamBuilder<Trip?>(
      stream: tripDao.watchById(widget.tripId),
      builder: (context, tripSnap) {
        final startDate = tripSnap.data?.startDate;

        return StreamBuilder<List<ItineraryDay>>(
          stream: _itineraryDao.watchDays(widget.tripId),
          builder: (context, daysSnap) {
            final days = daysSnap.data ?? [];
            final dayCount = days.length;

            return StreamBuilder<List<HotelStay>>(
              stream: _itineraryDao.watchHotelStays(widget.tripId),
              builder: (context, staysSnap) {
                final stays = staysSnap.data ?? [];

                return Column(
                  children: [
                    if (dayCount > 0) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _DayLabelsRow(
                                dayCount: dayCount,
                                startDate: startDate,
                                showDates: _showDates,
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              child: IconButton(
                                icon: Icon(_showDates ? Icons.numbers : Icons.calendar_today, size: 16),
                                padding: EdgeInsets.zero,
                                onPressed: startDate != null
                                    ? () => setState(() => _showDates = !_showDates)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: _HotelBars(
                        dayCount: dayCount,
                        stays: stays,
                        spotDao: _spotDao,
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: dayCount > 0
                            ? () => _addStay(context, dayCount, stays)
                            : null,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addHotelStay),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: stays.isEmpty
                      ? Center(child: Text(l10n.noHotelStays))
                      : ListView.builder(
                          itemCount: stays.length,
                          itemBuilder: (context, index) =>
                              _StayCard(
                                stay: stays[index],
                                allStays: stays,
                                dayCount: dayCount,
                                spotDao: _spotDao,
                                itineraryDao: _itineraryDao,
                                onPickHotel: () =>
                                    _changeHotel(stays[index]),
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
  }

  Future<List<({Spot spot, String location})>> _getHotelSpots() async {
    final result = <({Spot spot, String location})>[];
    final regions = await _regionDao.watchByTrip(widget.tripId).first;
    for (final region in regions) {
      final areas = await _areaDao.watchByRegion(region.id).first;
      for (final area in areas) {
        final spots = await _spotDao.watchByArea(area.id).first;
        for (final s in spots.where((s) => s.type == 'hotel')) {
          result.add((spot: s, location: '${region.name} — ${area.name}'));
        }
      }
    }
    return result;
  }

  Future<void> _addStay(BuildContext context, int dayCount, List<HotelStay> stays) async {
    final hotels = await _getHotelSpots();
    if (!context.mounted) return;

    if (hotels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noResults)),
      );
      return;
    }

    final selected = await showDialog<Spot>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.selectHotel),
        children: hotels
            .map((h) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, h.spot),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.spot.name),
                      Text(h.location, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      // Find latest uncovered day, scanning backwards
      var checkInDay = 1;
      for (var d = 1; d <= dayCount; d++) {
        if (ItineraryDao.hotelForDay(stays, d) == null) {
          checkInDay = d;
          break;
        }
      }
      // Check-out = next covered day or end+1
      var checkOutDay = dayCount + 1;
      for (var d = checkInDay + 1; d <= dayCount; d++) {
        if (ItineraryDao.hotelForDay(stays, d) != null) {
          checkOutDay = d;
          break;
        }
      }

      await _itineraryDao.addHotelStayForDays(
        tripId: widget.tripId,
        spotId: selected.id,
        checkInDay: checkInDay,
        checkOutDay: checkOutDay,
      );
    }
  }

  Future<void> _changeHotel(HotelStay stay) async {
    final hotels = await _getHotelSpots();
    if (!mounted || hotels.isEmpty) return;

    final selected = await showDialog<Spot>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.selectHotel),
        children: hotels
            .map((h) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, h.spot),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.spot.name),
                      Text(h.location, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ))
            .toList(),
      ),
    );

    if (selected != null) {
      await _itineraryDao.updateHotelStay(stay.id, spotId: selected.id);
    }
  }
}

class _DayLabelsRow extends StatelessWidget {
  final int dayCount;
  final DateTime? startDate;
  final bool showDates;

  const _DayLabelsRow({required this.dayCount, this.startDate, required this.showDates});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    if (!showDates || startDate == null) {
      return Row(
        children: List.generate(
          dayCount,
          (i) => Expanded(child: Center(child: Text('${i + 1}', style: style))),
        ),
      );
    }
    final dates = List.generate(dayCount, (i) => startDate!.add(Duration(days: i)));
    final mf = DateFormat.MMM();
    final monthHeight = (style?.fontSize ?? 12) + 4;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: monthHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colWidth = constraints.maxWidth / dayCount;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < dayCount; i++)
                    if (i == 0 || dates[i].month != dates[i - 1].month)
                      Positioned(
                        left: i * colWidth,
                        child: Text(mf.format(dates[i]), style: style),
                      ),
                ],
              );
            },
          ),
        ),
        Row(
          children: List.generate(dayCount, (i) => Expanded(
            child: Center(child: Text('${dates[i].day}', style: style)),
          )),
        ),
      ],
    );
  }
}

class _HotelBars extends StatelessWidget {
  final int dayCount;
  final List<HotelStay> stays;
  final SpotDao spotDao;

  const _HotelBars({
    required this.dayCount,
    required this.stays,
    required this.spotDao,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: stays.map((stay) {
        final checkIn = ItineraryDao.dayFromKey(stay.checkInDateTime);
        final checkOut = ItineraryDao.dayFromKey(stay.checkOutDateTime);
        final startFrac = (checkIn - 1) / dayCount;
        final widthFrac = (checkOut - checkIn) / dayCount;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0,
            child: Stack(
              children: [
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Positioned(
                  left: startFrac *
                      (MediaQuery.of(context).size.width - 64),
                  child: FutureBuilder<Spot?>(
                    future: spotDao.getById(stay.spotId),
                    builder: (context, snap) => Container(
                      width: widthFrac *
                          (MediaQuery.of(context).size.width - 64),
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.purple[300]!),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        snap.data?.name ?? '...',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StayCard extends StatelessWidget {
  final HotelStay stay;
  final List<HotelStay> allStays;
  final int dayCount;
  final SpotDao spotDao;
  final ItineraryDao itineraryDao;
  final VoidCallback onPickHotel;

  const _StayCard({
    required this.stay,
    required this.allStays,
    required this.dayCount,
    required this.spotDao,
    required this.itineraryDao,
    required this.onPickHotel,
  });

  List<String> _warnings(AppLocalizations l10n, int checkIn, int checkOut) {
    final warnings = <String>[];
    if (checkOut <= checkIn) {
      warnings.add(l10n.hotelDatesInvalid);
    }
    for (final other in allStays) {
      if (other.id == stay.id) continue;
      final otherIn = ItineraryDao.dayFromKey(other.checkInDateTime);
      final otherOut = ItineraryDao.dayFromKey(other.checkOutDateTime);
      if (checkIn < otherOut && checkOut > otherIn) {
        warnings.add(l10n.hotelDatesOverlap);
        break;
      }
    }
    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final checkIn = ItineraryDao.dayFromKey(stay.checkInDateTime);
    final checkOut = ItineraryDao.dayFromKey(stay.checkOutDateTime);
    final nights = checkOut - checkIn;
    final warnings = _warnings(l10n, checkIn, checkOut);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hotel, size: 20, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: FutureBuilder<Spot?>(
                    future: spotDao.getById(stay.spotId),
                    builder: (context, snap) {
                      final missing = snap.connectionState == ConnectionState.done && snap.data == null;
                      return GestureDetector(
                        onTap: onPickHotel,
                        child: Row(
                          children: [
                            if (missing)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                              ),
                            Expanded(
                              child: Text(
                                missing ? l10n.missingReference : (snap.data?.name ?? '...'),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: missing ? Colors.red : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (nights > 0)
                  Text(l10n.nightsCount(nights),
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => itineraryDao.deleteHotelStay(stay.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DayPicker(
                    label: l10n.checkInDay,
                    value: checkIn,
                    min: 1,
                    max: dayCount,
                    onChanged: (v) => itineraryDao.updateHotelStay(
                        stay.id, checkInDay: v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DayPicker(
                    label: l10n.checkOutDay,
                    value: checkOut,
                    min: 1,
                    max: dayCount + 1,
                    onChanged: (v) => itineraryDao.updateHotelStay(
                        stay.id, checkOutDay: v),
                  ),
                ),
              ],
            ),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(w, style: TextStyle(fontSize: 12, color: Colors.red[800])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _DayPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        DropdownButton<int>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: List.generate(
            max - min + 1,
            (i) => DropdownMenuItem(
              value: min + i,
              child: Text('${min + i}'),
            ),
          ),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
