import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:myroad/database/database.dart';

// ponytail: loads system TTF font for CJK, bundle a font asset if needed on platforms without these
Future<pw.Font?> _loadSystemFont() async {
  final candidates = [
    '/Library/Fonts/Arial Unicode.ttf',
    'C:\\Windows\\Fonts\\msyh.ttf',
    'C:\\Windows\\Fonts\\msgothic.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttf',
    '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return pw.Font.ttf(ByteData.sublistView(bytes));
    }
  }
  return null;
}

class PdfExportService {
  final AppDatabase _db;

  PdfExportService(this._db);

  Future<Uint8List> generatePdf(String tripId) async {
    final trip = await (_db.select(_db.trips)
          ..where((t) => t.id.equals(tripId)))
        .getSingle();

    final days = await (_db.select(_db.itineraryDays)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]))
        .get();

    final tripRegions = await (_db.select(_db.tripRegions)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .get();
    final regionNames = <String>[];
    for (final tr in tripRegions) {
      final r = await (_db.select(_db.regions)
            ..where((t) => t.id.equals(tr.regionId)))
          .getSingleOrNull();
      if (r != null) regionNames.add(r.name);
    }

    final font = await _loadSystemFont();
    final theme = font != null
        ? pw.ThemeData.withFont(base: font, bold: font)
        : null;
    final doc = pw.Document(theme: theme);

    // Cover page
    doc.addPage(pw.Page(
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(trip.name,
                style: pw.TextStyle(
                    fontSize: 32, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            if (trip.startDate != null && trip.endDate != null)
              pw.Text(
                  '${_fmtDate(trip.startDate!)} — ${_fmtDate(trip.endDate!)}'),
            pw.SizedBox(height: 8),
            pw.Text('${days.length} days'),
            if (regionNames.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(regionNames.join(', '),
                  style: const pw.TextStyle(fontSize: 14)),
            ],
          ],
        ),
      ),
    ));

    // Hotel stays for resolving checkin/checkout
    final hotelStays = await (_db.select(_db.hotelStays)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.checkInDateTime)]))
        .get();

    // Per-day pages — mirrors itinerary view
    for (final day in days) {
      final items = await (_db.select(_db.dayItems)
            ..where((t) => t.dayId.equals(day.id))
            ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .get();

      // Find dominant region for this day
      final regionCounts = <String, int>{};
      for (final item in items) {
        if (item.areaId != null) {
          final area = await (_db.select(_db.areas)
                ..where((t) => t.id.equals(item.areaId!)))
              .getSingleOrNull();
          if (area != null) {
            regionCounts[area.regionId] = (regionCounts[area.regionId] ?? 0) + 1;
          }
        }
      }
      String? dayRegionName;
      if (regionCounts.isNotEmpty) {
        final topRegionId = regionCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        final region = await (_db.select(_db.regions)
              ..where((t) => t.id.equals(topRegionId)))
            .getSingleOrNull();
        dayRegionName = region?.name;
      }

      // Build flat list of (spotId, widget) entries
      final entries = <({String? spotId, pw.Widget widget})>[];
      String? lastAreaName;

      for (final item in items) {
        if (item.areaId != null) {
          final area = await (_db.select(_db.areas)
                ..where((t) => t.id.equals(item.areaId!)))
              .getSingleOrNull();
          if (area == null) continue;

          final spots = await (_db.select(_db.spots)
                ..where((t) => t.areaId.equals(area.id) & t.type.equals('hotel').not())
                ..orderBy([(t) => OrderingTerm.asc(t.order)]))
              .get();

          for (final spot in spots) {
            final spotWidgets = <pw.Widget>[];
            if (area.name != lastAreaName) {
              lastAreaName = area.name;
              spotWidgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
                child: pw.Text(area.name,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal)),
              ));
            }
            spotWidgets.add(_buildSpotBlock(spot));
            entries.add((spotId: spot.id, widget: pw.Column(children: spotWidgets)));
          }
        } else {
          final label = switch (item.itemType) {
            'checkin' => 'Check-in',
            'checkout' => 'Check-out',
            'luggage' => 'Luggage',
            _ => item.itemType,
          };
          final lookupDay = item.itemType == 'checkout' ? day.dayNumber - 1 : day.dayNumber;
          final stay = _hotelForDay(hotelStays, lookupDay);
          Spot? hotelSpot;
          if (stay != null) {
            hotelSpot = await (_db.select(_db.spots)
                  ..where((t) => t.id.equals(stay.spotId)))
                .getSingleOrNull();
          }
          entries.add((spotId: hotelSpot?.id, widget: _buildHotelActionBlock(label, hotelSpot)));
        }
      }

      // Staying hotel at end of day
      final hotel = _hotelForDay(hotelStays, day.dayNumber);
      if (hotel != null) {
        final hotelSpot = await (_db.select(_db.spots)
              ..where((t) => t.id.equals(hotel.spotId)))
            .getSingleOrNull();
        if (hotelSpot != null) {
          entries.add((spotId: hotelSpot.id, widget: _buildStayingHotelBlock(hotelSpot)));
        }
      }

      // Interleave transport arrows between consecutive entries
      final dayWidgets = <pw.Widget>[];
      for (var i = 0; i < entries.length; i++) {
        dayWidgets.add(entries[i].widget);
        if (i < entries.length - 1) {
          final fromId = entries[i].spotId;
          final toId = entries[i + 1].spotId;
          if (fromId != null && toId != null) {
            final legs = await (_db.select(_db.transports)
                  ..where((t) => t.fromSpotId.equals(fromId) & t.toSpotId.equals(toId)))
                .get();
            for (final leg in legs) {
              dayWidgets.add(_buildTransportBlock(leg));
            }
          }
        }
      }

      doc.addPage(pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              [
                'Day ${day.dayNumber}',
                ?dayRegionName,
                if (day.date != null) _fmtDate(day.date!),
              ].join(' — '),
              style: pw.TextStyle(
                  fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            ...dayWidgets,
          ],
        ),
      ));
    }

    return doc.save();
  }

  static HotelStay? _hotelForDay(List<HotelStay> stays, int dayNumber) {
    for (final stay in stays) {
      final checkIn = stay.checkInDateTime.day;
      final checkOut = stay.checkOutDateTime.day;
      if (dayNumber >= checkIn && dayNumber < checkOut) return stay;
    }
    return null;
  }

  static PdfColor _spotColor(String type) => switch (type) {
    'restaurant' => PdfColors.orange,
    'hotel' => PdfColors.purple,
    'custom' => PdfColors.grey,
    _ => PdfColors.blue,
  };

  pw.Widget _buildDot(PdfColor color) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
    );
  }

  pw.Widget _buildHotelActionBlock(String label, Spot? hotelSpot) {
    final child = pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple.shade(0.15),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.purple.shade(0.3), width: 0.5),
      ),
      child: pw.Row(children: [
        _buildDot(PdfColors.purple),
        pw.SizedBox(width: 8),
        pw.Text(hotelSpot != null ? '$label — ${hotelSpot.name}' : label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.purple)),
      ]),
    );
    if (hotelSpot == null) return child;
    final url = _mapsUrl(hotelSpot.name, hotelSpot.lat, hotelSpot.lng, hotelSpot.googlePlaceId);
    return url != null ? pw.UrlLink(destination: url, child: child) : child;
  }

  pw.Widget _buildSpotBlock(Spot spot) {
    final color = _spotColor(spot.type);
    final child = pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: color.shade(0.15),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color.shade(0.3), width: 0.5),
      ),
      child: pw.Row(children: [
        _buildDot(color),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(spot.name,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text('${spot.estimatedVisitDurationMinutes} min',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ),
      ]),
    );
    final url = _mapsUrl(spot.name, spot.lat, spot.lng, spot.googlePlaceId);
    return url != null ? pw.UrlLink(destination: url, child: child) : child;
  }

  pw.Widget _buildStayingHotelBlock(Spot hotelSpot) {
    final block = pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple.shade(0.15),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(children: [
        _buildDot(PdfColors.purple),
        pw.SizedBox(width: 8),
        pw.Text(hotelSpot.name,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.purple)),
      ]),
    );
    final url = _mapsUrl(hotelSpot.name, hotelSpot.lat, hotelSpot.lng, hotelSpot.googlePlaceId);
    return url != null ? pw.UrlLink(destination: url, child: block) : block;
  }

  pw.Widget _buildTransportBlock(Transport leg) {
    final modeLabel = switch (leg.mode) {
      'walk' => 'Walk',
      'transit' => 'Transit',
      'car' => 'Car',
      'motorcycle' => 'Motorcycle',
      'bicycle' => 'Bicycle',
      _ => leg.mode,
    };
    final parts = <String>[
      '${leg.estimatedDurationMinutes} min',
      if (leg.distanceMeters != null)
        leg.distanceMeters! >= 1000
            ? '${(leg.distanceMeters! / 1000).toStringAsFixed(1)} km'
            : '${leg.distanceMeters!.round()} m',
      if (leg.routeName != null) leg.routeName!,
      if (leg.price != null) '\u{00a5}${leg.price!}',
    ];
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 16, bottom: 2, top: 2),
      child: pw.Text('v  $modeLabel  ${parts.join(' / ')}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
    );
  }

  static String? _mapsUrl(String name, double? lat, double? lng, String? placeId) {
    if (placeId != null) return 'https://www.google.com/maps/place/?q=place_id:$placeId';
    if (lat != null && lng != null) return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}';
  }

  String _fmtDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
