import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/json_export_service.dart';
import 'package:myroad/services/pdf_export_service.dart';

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
          onPressed: () => _exportPdf(context, ref),
          icon: const Icon(Icons.picture_as_pdf),
          label: Text(l10n.exportPdf),
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

  Future<String> _tripName(WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingle();
    return trip.name;
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    final db = ref.read(appDatabaseProvider);
    final name = await _tripName(ref);
    final bytes = await PdfExportService(db).generatePdf(tripId);
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '$name.myroad.pdf'));
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
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

}
