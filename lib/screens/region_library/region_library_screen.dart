import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/create_region_dialog.dart';
import 'package:myroad/screens/region_library/region_detail_screen.dart';

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
                padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 12, 12, 12),
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
                          builder: (_) => RegionDetailScreen(regionId: region.id),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              region.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (region.description != null && region.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                region.description!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.map_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(l10n.nAreas(s?.areas ?? 0), style: Theme.of(context).textTheme.labelMedium),
                                const SizedBox(width: 16),
                                Icon(Icons.place_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(l10n.nSpots(s?.spots ?? 0), style: Theme.of(context).textTheme.labelMedium),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createRegion(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createRegion(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => CreateRegionDialog(title: l10n.createRegion),
    );
    if (result != null) {
      await ref.read(regionDaoProvider).insertRegion(
            result['name']!,
            result['description']!.isEmpty ? null : result['description'],
          );
    }
  }
}
