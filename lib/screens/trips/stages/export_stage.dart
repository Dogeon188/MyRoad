import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/json_export_service.dart';
import 'package:myroad/services/pdf_export_service.dart';
import 'package:myroad/services/png_export_service.dart';
import 'package:myroad/widgets/calendar_export_view.dart';
import 'package:myroad/widgets/detail_export_view.dart';

class ExportStage extends ConsumerWidget {
  final String tripId;

  const ExportStage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _exportCalendarPng(context, ref),
          icon: const Icon(Icons.calendar_month),
          label: Text(l10n.exportCalendarPng),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _exportDetailPng(context, ref),
          icon: const Icon(Icons.image),
          label: Text(l10n.exportDetailPng),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _exportJson(context, ref),
          icon: const Icon(Icons.data_object),
          label: Text(l10n.exportJson),
        ),
      ],
    );
  }

  Rect _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    return box != null ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;
  }

  Future<String> _tripName(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingle();
    return trip.name;
  }

  Future<void> _exportCalendarPng(BuildContext context, WidgetRef ref) async {
    final origin = _shareOrigin(context);
    final db = ref.read(appDatabaseProvider);
    final service = PngExportService(db);
    final data = await service.getCalendarData(tripId);

    if (!context.mounted) return;
    final bytes = await PngExportService.captureWidget(
      context, CalendarExportView(data: data),
    );

    final name = await _tripName(ref);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '$name.calendar.png'));
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }

  Future<void> _exportDetailPng(BuildContext context, WidgetRef ref) async {
    final origin = _shareOrigin(context);
    final db = ref.read(appDatabaseProvider);
    final itineraryDao = ItineraryDao(db);
    final days = await itineraryDao.watchDays(tripId).first;

    if (days.isEmpty || !context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<List<ItineraryDay>>(
      context: context,
      builder: (ctx) => _DayPickerDialog(days: days, l10n: l10n),
    );
    if (selected == null || selected.isEmpty) return;

    final service = PngExportService(db);
    final name = await _tripName(ref);
    final dir = await getTemporaryDirectory();
    final files = <XFile>[];

    for (final day in selected) {
      final data = await service.getDetailDayData(tripId, day.id);
      if (!context.mounted) return;
      final bytes = await PngExportService.captureWidget(
        context, DetailExportView(data: data),
      );
      final file = File(p.join(dir.path, '$name.day${day.dayNumber}.png'));
      await file.writeAsBytes(bytes);
      files.add(XFile(file.path));
    }

    await Share.shareXFiles(files, sharePositionOrigin: origin);
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final origin = _shareOrigin(context);
    final db = ref.read(appDatabaseProvider);
    final name = await _tripName(ref);
    final json = await JsonExportService(db).exportTrip(tripId);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(json);
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$name.myroad.json'));
    await file.writeAsString(jsonStr);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }

  // ignore: unused
  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final origin = _shareOrigin(context);
    final db = ref.read(appDatabaseProvider);
    final name = await _tripName(ref);
    final bytes = await PdfExportService(db).generatePdf(tripId);
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$name.myroad.pdf'));
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }
}

class _DayPickerDialog extends StatefulWidget {
  final List<ItineraryDay> days;
  final AppLocalizations l10n;

  const _DayPickerDialog({required this.days, required this.l10n});

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late int _start;
  late int _end;

  @override
  void initState() {
    super.initState();
    _start = widget.days.first.dayNumber;
    _end = widget.days.last.dayNumber;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final first = widget.days.first.dayNumber;
    final last = widget.days.last.dayNumber;

    return AlertDialog(
      title: Text(l10n.selectDays),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.dayN(_start)} — ${l10n.dayN(_end)}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            RangeSlider(
              values: RangeValues(_start.toDouble(), _end.toDouble()),
              min: first.toDouble(),
              max: last.toDouble(),
              divisions: last - first,
              labels: RangeLabels(l10n.dayN(_start), l10n.dayN(_end)),
              onChanged: (v) => setState(() {
                _start = v.start.round();
                _end = v.end.round();
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final chosen = widget.days.where((d) => d.dayNumber >= _start && d.dayNumber <= _end).toList();
            Navigator.pop(context, chosen);
          },
          child: Text(l10n.export),
        ),
      ],
    );
  }
}
