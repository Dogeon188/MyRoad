import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/widgets/spots_map.dart';
import 'package:myroad/screens/trips/stages/itinerary_view_stage.dart'
    show emptyItinerary, iosChip;

class ItineraryMapStage extends ConsumerWidget {
  final String tripId;
  const ItineraryMapStage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MapView(tripId: tripId);
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
        if (days.isEmpty)
          return emptyItinerary(context, l10n, itineraryDao, widget.tripId);

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  iosChip(
                    context,
                    l10n.allDays,
                    _filterDay == null,
                    () => setState(() => _filterDay = null),
                  ),
                  ...days.map(
                    (day) => iosChip(
                      context,
                      l10n.dayN(day.dayNumber),
                      _filterDay == day.dayNumber,
                      () => setState(() => _filterDay = day.dayNumber),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _SpotsMapLoader(
                days: _filterDay == null
                    ? days
                    : days.where((d) => d.dayNumber == _filterDay).toList(),
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
          spots.add(
            MapSpot(
              id: s.id,
              name: s.name,
              type: s.type,
              lat: s.lat!,
              lng: s.lng!,
            ),
          );
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
        return SpotsMap(
          key: ValueKey(spots.map((s) => s.id).join(',')),
          spots: spots,
        );
      },
    );
  }
}
