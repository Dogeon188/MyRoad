import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/widgets/time_picker_helper.dart';
import 'package:myroad/screens/trips/stages/builder_area_card.dart';
import 'package:myroad/screens/trips/stages/builder_rows.dart';

// Gap between fields/rows in the add/edit pass dialog.
const _dialogFieldGap = 8.0;

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
  bool _didAutoScroll = false;

  @override
  void initState() {
    super.initState();
    final db = ref.read(appDatabaseProvider);
    _itineraryDao = ItineraryDao(db);
    _spotDao = ref.read(spotDaoProvider);
    _areaDao = ref.read(areaDaoProvider);
    _regionDao = ref.read(regionDaoProvider);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final startDate = ref.watch(tripProvider(widget.tripId)).valueOrNull?.startDate;
    final daysAsync = ref.watch(itineraryDaysProvider(widget.tripId));
    final days = daysAsync.valueOrNull ?? [];
    final stays = ref.watch(hotelStaysProvider(widget.tripId)).valueOrNull ?? [];
    final spotTimes = ref.watch(spotTimesProvider(widget.tripId)).valueOrNull ?? {};
    final skippedSpots = ref.watch(skippedSpotsProvider(widget.tripId)).valueOrNull ?? {};
    final passes = ref.watch(travelPassesProvider(widget.tripId)).valueOrNull ?? [];
    final regions = ref.watch(tripRegionsProvider(widget.tripId)).valueOrNull ?? [];
    final cp = regions.isNotEmpty ? currencySymbol(regions.first.currency) : '¥';

    if (daysAsync.isLoading) return const Center(child: CircularProgressIndicator());
    if (days.isNotEmpty && startDate != null && !_didAutoScroll) {
      _didAutoScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday(startDate, days.length));
    }
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

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RegionRow(
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
                        onAddPass: (dayNum) => _addPass(context, days.length, defaultDay: dayNum),
                        onDelete: () => _itineraryDao.deleteDayAndRenumber(widget.tripId, day.id),
                      )),
                  Align(
                    alignment: Alignment.center,
                    child: AddDayButton(onTap: () => _addDay(days)),
                  ),
                ],
              ),
            ),
          ),
          if (stays.isNotEmpty)
            HotelRow(
              stays: stays,
              dayCount: days.length,
              spotDao: _spotDao,
            ),
          if (passes.isNotEmpty)
            PassesRow(
              passes: passes,
              dayCount: days.length,
              currencyPrefix: cp,
              onPassLongPress: (pass) => _editPass(context, pass, days.length),
            ),
        ],
      ),
    );
  }

  Future<void> _addPass(BuildContext context, int dayCount, {int? defaultDay}) =>
      _showPassDialog(context, dayCount, defaultDay: defaultDay);

  Future<void> _editPass(BuildContext context, TravelPassesData pass, int dayCount) =>
      _showPassDialog(context, dayCount, existing: pass);

  Future<void> _showPassDialog(BuildContext context, int dayCount, {TravelPassesData? existing, int? defaultDay}) async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final priceCtrl = TextEditingController(text: existing?.price ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    int startDay = existing?.startDay ?? defaultDay ?? 1;
    int endDay = existing?.endDay ?? defaultDay ?? 1;
    bool rangeMode = existing != null && existing.startDay != existing.endDay;
    bool bought = existing?.bought ?? false;

    final dayItems = List.generate(dayCount, (i) => DropdownMenuItem(
      value: i + 1,
      child: Text(l10n.dayN(i + 1)),
    ));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? l10n.editPass : l10n.addPass),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: l10n.passName), autofocus: true),
                const SizedBox(height: _dialogFieldGap),
                TextField(controller: urlCtrl, decoration: InputDecoration(labelText: l10n.passUrl), keyboardType: TextInputType.url),
                const SizedBox(height: _dialogFieldGap),
                TextField(controller: priceCtrl, decoration: InputDecoration(labelText: l10n.price)),
                const SizedBox(height: _dialogFieldGap),
                TextField(controller: noteCtrl, decoration: InputDecoration(labelText: l10n.passNote)),
                CheckboxListTile(
                  title: Text(l10n.passBought),
                  value: bought,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => bought = v!),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Text(rangeMode ? l10n.startDay : l10n.tripDay),
                  const SizedBox(width: _dialogFieldGap),
                  DropdownButton<int>(
                    value: startDay,
                    items: dayItems,
                    onChanged: (v) => setDialogState(() { startDay = v!; if (!rangeMode || endDay < startDay) endDay = startDay; }),
                  ),
                ]),
                CheckboxListTile(
                  title: Text(l10n.enableEndDay),
                  value: rangeMode,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() { rangeMode = v!; if (!rangeMode) endDay = startDay; }),
                ),
                if (rangeMode)
                  Row(children: [
                    Text(l10n.endDay),
                    const SizedBox(width: _dialogFieldGap),
                    DropdownButton<int>(
                      value: endDay,
                      items: dayItems.where((i) => i.value! >= startDay).toList(),
                      onChanged: (v) => setDialogState(() => endDay = v!),
                    ),
                  ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
          ],
        ),
      ),
    );
    if (result != true || nameCtrl.text.isEmpty) return;
    if (existing != null) {
      await _itineraryDao.updatePass(existing.id,
        name: nameCtrl.text,
        url: urlCtrl.text.isEmpty ? null : urlCtrl.text,
        price: priceCtrl.text.isEmpty ? null : priceCtrl.text,
        startDay: startDay,
        endDay: endDay,
        bought: bought,
        note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
      );
    } else {
      await _itineraryDao.addPass(
        tripId: widget.tripId,
        name: nameCtrl.text,
        url: urlCtrl.text.isEmpty ? null : urlCtrl.text,
        price: priceCtrl.text.isEmpty ? null : priceCtrl.text,
        startDay: startDay,
        endDay: endDay,
        bought: bought,
        note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
      );
    }
  }

  void _scrollToToday(DateTime startDate, int dayCount) {
    if (!_scrollController.hasClients) return;
    final offset = todayScrollOffset(
      startDate: startDate,
      dayCount: dayCount,
      today: DateTime.now(),
      viewportWidth: _scrollController.position.viewportDimension,
      maxScrollExtent: _scrollController.position.maxScrollExtent,
    );
    if (offset != null) _scrollController.jumpTo(offset);
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

/// Scroll offset to center today's day column, or null if today falls
/// outside [startDate, startDate + dayCount - 1].
double? todayScrollOffset({
  required DateTime startDate,
  required int dayCount,
  required DateTime today,
  required double viewportWidth,
  required double maxScrollExtent,
}) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final todayDate = DateTime(today.year, today.month, today.day);
  final daysSinceStart = todayDate.difference(start).inDays;
  if (daysSinceStart < 0 || daysSinceStart > dayCount - 1) return null;

  final rawOffset = daysSinceStart * dayColumnStride;
  final centeredOffset = rawOffset - (viewportWidth - dayColumnStride) / 2;
  return centeredOffset.clamp(0.0, maxScrollExtent);
}

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
  final void Function(int dayNumber) onAddPass;
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
    required this.onAddPass,
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
    final dateStr = tripStartDate != null
        ? ' ${_formatDate(tripStartDate!.add(Duration(days: day.dayNumber - 1)))}'
        : '';
    final depTime = day.departureTimeMinutes;
    final arrTime = day.arrivalTimeMinutes;
    final depStr = depTime != null ? '${(depTime ~/ 60).toString().padLeft(2, '0')}:${(depTime % 60).toString().padLeft(2, '0')}' : null;
    final arrStr = arrTime != null ? '${(arrTime ~/ 60).toString().padLeft(2, '0')}:${(arrTime % 60).toString().padLeft(2, '0')}' : null;

    return SizedBox(
      width: dayColumnStride,
      child: Card(
        margin: const EdgeInsets.only(right: dayColumnGap),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${l10n.dayN(day.dayNumber)}$dateStr',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (val) {
                      switch (val) {
                        case 'add':
                          onAddArea();
                        case 'checkin':
                        case 'checkout':
                        case 'luggage':
                          _addHotelItem(val);
                        case 'pass':
                          onAddPass(day.dayNumber);
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'add', child: Text(l10n.addAreaToDay)),
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'checkin', child: Text(l10n.addCheckin)),
                      PopupMenuItem(value: 'checkout', child: Text(l10n.addCheckout)),
                      PopupMenuItem(value: 'luggage', child: Text(l10n.addLuggage)),
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'pass', child: Text(l10n.addPass)),
                      const PopupMenuDivider(),
                      PopupMenuItem(value: 'delete', child: Text(l10n.removeDay, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
            if (depStr != null || arrStr != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (depStr != null) ...[
                      GestureDetector(
                        onTap: () async {
                          final result = await pickOrClearTime(context, current: depTime, defaultTime: const TimeOfDay(hour: 9, minute: 0));
                          if (result == null) return;
                          itineraryDao.setDayDepartureTime(day.id, result == -1 ? null : result);
                        },
                        child: Text('↑$depStr', style: TextStyle(fontSize: 11, color: Colors.green[700])),
                      ),
                      const Spacer(),
                    ],
                    if (arrStr != null)
                      GestureDetector(
                        onTap: () async {
                          final result = await pickOrClearTime(context, current: arrTime, defaultTime: const TimeOfDay(hour: 20, minute: 0));
                          if (result == null) return;
                          itineraryDao.setDayArrivalTime(day.id, result == -1 ? null : result);
                        },
                        child: Text('↓$arrStr', style: TextStyle(fontSize: 11, color: Colors.red[700])),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<List<DayItem>>(
                stream: itineraryDao.watchDayItems(day.id),
                builder: (context, snap) {
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(l10n.addAreaToDay),
                        onPressed: onAddArea,
                      ),
                    );
                  }
                  return ReorderableListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final ids = items.map((i) => i.id).toList();
                      final moved = ids.removeAt(oldIndex);
                      ids.insert(newIndex, moved);
                      itineraryDao.reorderItems(ids);
                    },
                    itemBuilder: (context, i) => BuilderAreaCard(
                      key: ValueKey(items[i].id),
                      index: i,
                      item: items[i],
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
      ),
    );
  }
}
