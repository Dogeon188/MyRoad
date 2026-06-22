import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/database.dart';

class PngExportService {
  final AppDatabase _db;

  PngExportService(this._db);

  /// Capture a widget as PNG by briefly inserting it into the live widget tree.
  static Future<Uint8List> captureWidget(BuildContext context, Widget widget, {double pixelRatio = 2.0}) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (ctx) => Positioned(
      left: -10000,
      child: RepaintBoundary(
        key: key,
        child: IntrinsicWidth(
          child: IntrinsicHeight(
            child: Material(
              child: Theme(
                data: Theme.of(context),
                child: widget,
              ),
            ),
          ),
        ),
      ),
    ));
    overlay.insert(entry);

    // Wait for layout
    await Future.delayed(const Duration(milliseconds: 100));
    await WidgetsBinding.instance.endOfFrame;

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    entry.remove();

    return byteData!.buffer.asUint8List();
  }

  /// Build calendar view data for export.
  Future<CalendarExportData> getCalendarData(String tripId) async {
    final trip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingle();
    final itineraryDao = ItineraryDao(_db);
    final spotDao = SpotDao(_db);
    final areaDao = AreaDao(_db);
    final skippedSpots = await itineraryDao.watchSkippedSpots(tripId).first;
    final days = await itineraryDao.watchDays(tripId).first;
    final dayColumns = <CalendarDayData>[];
    for (final day in days) {
      final items = await itineraryDao.watchDayItems(day.id).first;
      final entries = <CalendarEntry>[];

      for (final item in items) {
        if (item.areaId == null) {
          entries.add(CalendarEntry.hotelAction(itemType: item.itemType));
        } else {
          final area = await areaDao.getById(item.areaId!);
          final spots = await spotDao.watchByArea(item.areaId!).first;
          entries.add(CalendarEntry.area(
            areaName: area?.name ?? '?',
            spots: spots.where((s) => s.type != 'hotel' && !skippedSpots.contains(s.id)).toList(),
          ));
        }
      }

      dayColumns.add(CalendarDayData(
        dayNumber: day.dayNumber,
        date: trip.startDate?.add(Duration(days: day.dayNumber - 1)),
        entries: entries,
      ));
    }

    // Resolve region per day
    final regionNames = <String?>[];
    for (final day in days) {
      final items = await itineraryDao.watchDayItems(day.id).first;
      final firstAreaId = items.map((i) => i.areaId).whereType<String>().firstOrNull;
      if (firstAreaId == null) { regionNames.add(null); continue; }
      final area = await areaDao.getById(firstAreaId);
      if (area == null) { regionNames.add(null); continue; }
      final region = await (_db.select(_db.regions)..where((t) => t.id.equals(area.regionId))).getSingleOrNull();
      regionNames.add(region?.name);
    }

    // Build region segments
    final regionSegments = <CalendarSegment>[];
    var si = 0;
    while (si < regionNames.length) {
      final name = regionNames[si];
      var span = 1;
      while (si + span < regionNames.length && regionNames[si + span] == name) { span++; }
      regionSegments.add(CalendarSegment(name: name, span: span));
      si += span;
    }

    // Build hotel segments
    final stays = await itineraryDao.watchHotelStays(tripId).first;
    final spotDao2 = SpotDao(_db);
    final hotelSegments = <CalendarSegment>[];
    var hi = 1;
    while (hi <= days.length) {
      final stay = ItineraryDao.hotelForDay(stays, hi);
      var span = 1;
      while (hi + span <= days.length && ItineraryDao.hotelForDay(stays, hi + span)?.id == stay?.id) { span++; }
      String? hotelName;
      if (stay != null) {
        final spot = await spotDao2.getById(stay.spotId);
        hotelName = spot?.name;
      }
      hotelSegments.add(CalendarSegment(name: hotelName, span: span));
      hi += span;
    }

    return CalendarExportData(
      tripName: trip.name,
      days: dayColumns,
      regionSegments: regionSegments,
      hotelSegments: hotelSegments,
    );
  }

  /// Build detail view data for a single day.
  Future<DetailDayData> getDetailDayData(String tripId, String dayId) async {
    final trip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingle();
    final itineraryDao = ItineraryDao(_db);
    final spotDao = SpotDao(_db);
    final areaDao = AreaDao(_db);
    final day = await (_db.select(_db.itineraryDays)..where((t) => t.id.equals(dayId))).getSingle();
    final items = await itineraryDao.watchDayItems(dayId).first;
    final skippedSpots = await itineraryDao.watchSkippedSpots(tripId).first;

    final stays = await itineraryDao.watchHotelStays(tripId).first;
    final entries = <DetailEntry>[];

    // Depart from previous night's hotel
    final prevHotel = day.dayNumber > 1 ? ItineraryDao.hotelForDay(stays, day.dayNumber - 1) : null;
    if (prevHotel != null) {
      final spot = await spotDao.getById(prevHotel.spotId);
      entries.add(DetailEntry.hotelAction(itemType: 'depart', hotelSpotId: prevHotel.spotId, hotelName: spot?.name));
    }

    for (final item in items) {
      if (item.areaId == null) {
        final lookupDay = item.itemType == 'checkout' ? day.dayNumber - 1 : day.dayNumber;
        final stay = ItineraryDao.hotelForDay(stays, lookupDay);
        String? hotelName;
        if (stay != null) {
          final spot = await spotDao.getById(stay.spotId);
          hotelName = spot?.name;
        }
        entries.add(DetailEntry.hotelAction(itemType: item.itemType, hotelSpotId: stay?.spotId, hotelName: hotelName));
      } else {
        final area = await areaDao.getById(item.areaId!);
        final spots = await spotDao.watchByArea(item.areaId!).first;

        for (final spot in spots.where((s) => s.type != 'hotel' && !skippedSpots.contains(s.id))) {
          entries.add(DetailEntry.spot(
            spot: spot,
            areaName: area?.name,
          ));
        }
      }
    }

    // Return to tonight's hotel
    final tonightHotel = ItineraryDao.hotelForDay(stays, day.dayNumber);
    if (tonightHotel != null) {
      final spot = await spotDao.getById(tonightHotel.spotId);
      entries.add(DetailEntry.hotelAction(itemType: 'return', hotelSpotId: tonightHotel.spotId, hotelName: spot?.name));
    }

    // Load transports between consecutive physical spots (including hotel spots)
    final physicalIds = entries.map((e) => e.physicalSpotId).whereType<String>().toList();
    final transports = <String, List<Transport>>{};
    for (var i = 0; i < physicalIds.length - 1; i++) {
      final from = physicalIds[i];
      final to = physicalIds[i + 1];
      final legs = await (_db.select(_db.transports)
            ..where((t) => t.fromSpotId.equals(from) & t.toSpotId.equals(to)))
          .get();
      if (legs.isNotEmpty) transports['$from->$to'] = legs;
    }

    return DetailDayData(
      tripName: trip.name,
      dayNumber: day.dayNumber,
      date: trip.startDate?.add(Duration(days: day.dayNumber - 1)),
      entries: entries,
      transports: transports,
    );
  }
}

// Data classes

class CalendarSegment {
  final String? name;
  final int span;
  CalendarSegment({required this.name, required this.span});
}

class CalendarExportData {
  final String tripName;
  final List<CalendarDayData> days;
  final List<CalendarSegment> regionSegments;
  final List<CalendarSegment> hotelSegments;
  CalendarExportData({required this.tripName, required this.days, required this.regionSegments, required this.hotelSegments});
}

class CalendarDayData {
  final int dayNumber;
  final DateTime? date;
  final List<CalendarEntry> entries;
  CalendarDayData({required this.dayNumber, this.date, required this.entries});
}

class CalendarEntry {
  final String? areaName;
  final List<Spot>? spots;
  final String? itemType;

  CalendarEntry.area({required String this.areaName, required List<Spot> this.spots}) : itemType = null;
  CalendarEntry.hotelAction({required String this.itemType}) : areaName = null, spots = null;

  bool get isHotelAction => itemType != null;
}

class DetailDayData {
  final String tripName;
  final int dayNumber;
  final DateTime? date;
  final List<DetailEntry> entries;
  final Map<String, List<Transport>> transports;

  DetailDayData({
    required this.tripName,
    required this.dayNumber,
    this.date,
    required this.entries,
    required this.transports,
  });
}

class DetailEntry {
  final Spot? spot;
  final String? areaName;
  final String? itemType;
  final String? hotelSpotId;
  final String? hotelName;

  DetailEntry.spot({required Spot this.spot, this.areaName}) : itemType = null, hotelSpotId = null, hotelName = null;
  DetailEntry.hotelAction({required String this.itemType, this.hotelSpotId, this.hotelName}) : spot = null, areaName = null;

  bool get isHotelAction => itemType != null;
  String? get physicalSpotId => isHotelAction ? hotelSpotId : (spot?.type != 'online' ? spot?.id : null);
}
