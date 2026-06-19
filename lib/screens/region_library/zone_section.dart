import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/spot_search_screen.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';

class ZoneSection extends ConsumerWidget {
  final String zoneId;
  final String zoneName;

  const ZoneSection({super.key, required this.zoneId, required this.zoneName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(zoneName, style: Theme.of(context).textTheme.titleMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(l10n.deleteRegion),
                    content: Text(l10n.deleteZoneConfirm(zoneName)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
                    ],
                  ),
                );
                if (confirmed == true) ref.read(zoneDaoProvider).deleteZone(zoneId);
              },
            ),
          ],
        ),
        children: [
          StreamBuilder(
            stream: spotDao.watchByZone(zoneId),
            builder: (context, snapshot) {
              final spots = snapshot.data ?? [];
              return Column(
                children: [
                  if (spots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.nSpots(0)),
                    ),
                  for (final spot in spots)
                    Dismissible(
                      key: ValueKey(spot.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Theme.of(context).colorScheme.error,
                        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
                      ),
                      confirmDismiss: (_) => showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          content: Text(l10n.deleteSpotConfirm(spot.name)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
                          ],
                        ),
                      ),
                      onDismissed: (_) => ref.read(spotDaoProvider).deleteSpot(spot.id),
                      child: ListTile(
                        leading: Icon(_spotTypeIcon(spot.type)),
                        title: Text(spot.name),
                        subtitle: Text(spot.address),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: spot.id)),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () => _addSpot(context, ref),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 18),
                            const SizedBox(width: 8),
                            Text(l10n.addSpot),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _spotTypeIcon(String type) {
    return switch (type) {
      'restaurant' => Icons.restaurant,
      'hotel' => Icons.hotel,
      'custom' => Icons.star_outline,
      _ => Icons.place,
    };
  }

  Future<void> _addSpot(BuildContext context, WidgetRef ref) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpotSearchScreen(zoneId: zoneId),
      ),
    );
  }
}
