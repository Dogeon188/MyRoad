import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:myroad/database/database.dart';

// ponytail: loads system TTF font for CJK, bundle a font asset if needed on platforms without these
Future<pw.Font?> _loadSystemFont() async {
  final candidates = [
    // macOS
    '/Library/Fonts/Arial Unicode.ttf',
    // Windows
    'C:\\Windows\\Fonts\\msyh.ttf',
    'C:\\Windows\\Fonts\\msgothic.ttf',
    // Linux
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

    // Per-day pages
    for (final day in days) {
      final items = await (_db.select(_db.dayItems)
            ..where((t) => t.dayId.equals(day.id))
            ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .get();

      final spotWidgets = <pw.Widget>[];
      for (final item in items) {
        if (item.areaId != null && item.spotId == null) {
          final area = await (_db.select(_db.areas)
                ..where((t) => t.id.equals(item.areaId!)))
              .getSingleOrNull();
          if (area == null) continue;
          spotWidgets.add(_buildAreaBlock(area, item));
        } else if (item.spotId != null) {
          final spot = await (_db.select(_db.spots)
                ..where((t) => t.id.equals(item.spotId!)))
              .getSingleOrNull();
          if (spot == null) continue;
          spotWidgets.add(_buildSpotBlock(spot, item));
        }
      }

      doc.addPage(pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              day.date != null
                  ? 'Day ${day.dayNumber} — ${_fmtDate(day.date!)}'
                  : 'Day ${day.dayNumber}',
              style: pw.TextStyle(
                  fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            ...spotWidgets,
          ],
        ),
      ));
    }

    return doc.save();
  }

  pw.Widget _buildAreaBlock(Area area, DayItem item) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.teal, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(children: [
        pw.Container(width: 12, height: 12, color: PdfColors.teal),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(area.name,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (item.startTimeMinutes != null)
                pw.Text(
                    '${_fmtTime(item.startTimeMinutes!)} – ${_fmtTime(item.endTimeMinutes!)}'),
              pw.Text('${area.estimatedDurationMinutes} min'),
            ],
          ),
        ),
      ]),
    );
  }

  pw.Widget _buildSpotBlock(Spot spot, DayItem item) {
    final color = switch (spot.type) {
      'restaurant' => PdfColors.orange,
      'hotel' => PdfColors.purple,
      'custom' => PdfColors.grey,
      _ => PdfColors.blue,
    };
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(children: [
        pw.Container(width: 12, height: 12, color: color),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(spot.name,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (item.startTimeMinutes != null)
                pw.Text(
                    '${_fmtTime(item.startTimeMinutes!)} – ${_fmtTime(item.endTimeMinutes!)}'),
              pw.Text('${spot.estimatedVisitDurationMinutes} min'),
            ],
          ),
        ),
      ]),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _fmtTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
