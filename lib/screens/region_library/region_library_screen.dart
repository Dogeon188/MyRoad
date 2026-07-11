import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/json_import_service.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/create_region_dialog.dart';
import 'package:myroad/screens/region_library/region_detail_screen.dart';
import 'package:myroad/utils/spot_appearance.dart';
import 'package:myroad/widgets/stat_row.dart';

class RegionLibraryScreen extends ConsumerWidget {
  const RegionLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);

    return Scaffold(
      body: StreamBuilder(
        stream: regionDao.watchAll(),
        builder: (context, regionsSnapshot) {
          if (!regionsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final regions = regionsSnapshot.data!;
          if (regions.isEmpty) {
            return Center(child: Text(l10n.noRegions));
          }
          return StreamBuilder(
            stream: regionDao.watchRegionStats(),
            builder: (context, statsSnapshot) {
              final stats = statsSnapshot.data ?? {};
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  12,
                  MediaQuery.of(context).padding.top + 12,
                  12,
                  12,
                ),
                itemCount: regions.length,
                itemBuilder: (context, index) {
                  final region = regions[index];
                  final s = stats[region.id];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RegionDetailScreen(regionId: region.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  regionIcon(iconCode: region.iconCode),
                                  size: 20,
                                  color: regionColor(),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    region.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            if (region.description != null &&
                                region.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                region.description!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            StatRow(
                              items: [
                                StatItem(
                                  icon: Icons.map_outlined,
                                  label: l10n.nAreas(s?.areas ?? 0),
                                  color: Theme.of(context).colorScheme.outline,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                StatItem(
                                  icon: Icons.place_outlined,
                                  label: l10n.nSpots(s?.spots ?? 0),
                                  color: Theme.of(context).colorScheme.outline,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            tooltip: l10n.importJson,
            onPressed: () => _importRegion(context, ref),
            child: const Icon(Icons.file_open),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'create',
            tooltip: l10n.createRegion,
            onPressed: () => _createRegion(context, ref),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Future<void> _createRegion(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CreateRegionDialog(title: l10n.createRegion),
    );
    if (result != null) {
      await ref
          .read(regionDaoProvider)
          .insertRegion(
            result['name'] as String,
            (result['description'] as String).isEmpty
                ? null
                : result['description'] as String,
            iconCode: result['iconCode'] as int?,
          );
    }
  }

  Future<void> _importRegion(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final jsonStr = await file.readAsString();
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    final db = ref.read(appDatabaseProvider);
    final regionId = await JsonImportService(db).importRegion(json);

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegionDetailScreen(regionId: regionId)),
    );
  }
}
