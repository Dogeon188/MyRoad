import 'package:flutter/material.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/widgets/time_picker_helper.dart';

class BuilderAreaCard extends StatelessWidget {
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

  const BuilderAreaCard({
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

  static ({IconData icon, String label}) hotelItemInfo(AppLocalizations l10n, String type) => switch (type) {
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
      final info = hotelItemInfo(l10n, item.itemType);
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
                  icon: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.error),
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
                    icon: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.error),
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
                      icon: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.error),
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
