import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/utils/url_helper.dart';

/// Horizontal space one day column occupies in the builder grid, including
/// the gap before the next column. _DayColumn's width must match this so
/// region/hotel/pass blocks stay aligned with the day columns below them.
const double dayColumnStride = 200;

/// Gap between adjacent day columns / blocks.
const double dayColumnGap = 8;

class RegionRow extends StatelessWidget {
  final List<ItineraryDay> days;
  final ItineraryDao itineraryDao;
  final AreaDao areaDao;
  final RegionDao regionDao;
  final ScrollController scrollController;

  const RegionRow({
    super.key,
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
                    final width = seg.span * dayColumnStride - dayColumnGap;
                    if (seg.regionId == null) {
                      return SizedBox(width: width + dayColumnGap);
                    }
                    // ponytail: sticky text — shift content right when segment is partially scrolled off
                    final segStart = seg.startCol * dayColumnStride;
                    final stickyPad = (scrollOffset - segStart).clamp(0.0, width - 80.0).toDouble();

                    return Container(
                      width: width,
                      height: 28,
                      margin: const EdgeInsets.only(right: dayColumnGap),
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

class HotelRow extends StatelessWidget {
  final List<HotelStay> stays;
  final int dayCount;
  final SpotDao spotDao;

  const HotelRow({
    super.key,
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
          final width = seg.span * dayColumnStride - dayColumnGap;
          if (seg.stay == null) {
            return SizedBox(width: width + dayColumnGap);
          }
          return FutureBuilder<Spot?>(
            future: spotDao.getById(seg.stay!.spotId),
            builder: (context, snap) {
              final missing = snap.connectionState == ConnectionState.done && snap.data == null;
              return Container(
                width: width,
                height: 32,
                margin: const EdgeInsets.only(right: dayColumnGap),
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

class PassesRow extends StatelessWidget {
  final List<TravelPassesData> passes;
  final int dayCount;
  final String currencyPrefix;
  final void Function(TravelPassesData pass)? onPassLongPress;

  const PassesRow({super.key, required this.passes, required this.dayCount, required this.currencyPrefix, this.onPassLongPress});

  // ponytail: greedy interval packing — sort by start, assign to first non-overlapping row
  static List<List<TravelPassesData>> _packRows(List<TravelPassesData> passes) {
    final sorted = [...passes]..sort((a, b) => a.startDay.compareTo(b.startDay));
    final rows = <List<TravelPassesData>>[];
    final rowEnds = <int>[];
    for (final pass in sorted) {
      final ri = rowEnds.indexWhere((end) => end < pass.startDay);
      if (ri >= 0) {
        rows[ri].add(pass);
        rowEnds[ri] = pass.endDay;
      } else {
        rows.add([pass]);
        rowEnds.add(pass.endDay);
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _packRows(passes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((rowPasses) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: _buildRowChildren(rowPasses),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildRowChildren(List<TravelPassesData> rowPasses) {
    final children = <Widget>[];
    var cursor = 1;
    for (final pass in rowPasses) {
      if (pass.startDay > cursor) {
        children.add(SizedBox(width: (pass.startDay - cursor) * dayColumnStride));
      }
      children.add(GestureDetector(
        onTap: pass.url != null && pass.url!.isNotEmpty
            ? () => launchUrl(externalUri(pass.url!), mode: LaunchMode.externalApplication)
            : null,
        onLongPress: onPassLongPress != null ? () => onPassLongPress!(pass) : null,
        child: Container(
          width: (pass.endDay - pass.startDay + 1) * dayColumnStride - dayColumnGap,
          height: 32,
          margin: const EdgeInsets.only(right: dayColumnGap),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[300]!),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(pass.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              if (pass.price != null)
                Text('$currencyPrefix${pass.price!}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
      ));
      cursor = pass.endDay + 1;
    }
    return children;
  }
}

class AddDayButton extends StatelessWidget {
  final VoidCallback onTap;

  const AddDayButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 180,
        margin: const EdgeInsets.only(right: dayColumnGap),
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
