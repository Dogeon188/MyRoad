import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/widgets/name_input_dialog.dart';
import 'package:myroad/screens/region_library/spot_search_screen.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';

class ZoneSection extends ConsumerWidget {
  final String zoneId;
  final String zoneName;
  final String regionId;

  const ZoneSection({super.key, required this.zoneId, required this.zoneName, required this.regionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(zoneName, style: Theme.of(context).textTheme.titleMedium),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            switch (action) {
              case 'rename':
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => NameInputDialog(
                    title: l10n.rename,
                    labelText: l10n.zoneName,
                    initialValue: zoneName,
                  ),
                );
                if (name != null) ref.read(zoneDaoProvider).updateZone(zoneId, name: name);
              case 'delete':
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
              case 'move':
                final target = await _pickRegion(context, ref, exclude: regionId);
                if (target != null) await ref.read(zoneDaoProvider).moveToRegion(zoneId, target.id);
              case 'copy':
                final target = await _pickRegion(context, ref);
                if (target != null) await ref.read(zoneDaoProvider).copyToRegion(zoneId, target.id, ref.read(spotDaoProvider));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
            PopupMenuItem(value: 'move', child: Text(l10n.moveToRegion)),
            PopupMenuItem(value: 'copy', child: Text(l10n.copyToRegion)),
            PopupMenuItem(value: 'delete', child: Text(l10n.deleteRegion)),
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (spot.notes.isNotEmpty)
                              Text(spot.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (spot.address.isNotEmpty)
                              Text(
                                spot.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: spot.id)),
                        ),
                        onLongPress: () => _showSpotActions(context, ref, spot),
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
      'online' => Icons.videocam,
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

  Future<void> _showSpotActions(BuildContext context, WidgetRef ref, Spot spot) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(l10n.moveToZone),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.copyToZone),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    final target = await _pickZone(context, ref, exclude: action == 'move' ? zoneId : null);
    if (target == null) return;
    final spotDao = ref.read(spotDaoProvider);
    if (action == 'move') {
      await spotDao.moveToZone(spot.id, target.id);
    } else {
      await spotDao.copyToZone(spot.id, target.id);
    }
  }

  Future<Zone?> _pickZone(BuildContext context, WidgetRef ref, {String? exclude}) async {
    final l10n = AppLocalizations.of(context)!;
    final regions = await ref.read(regionDaoProvider).watchAll().first;
    final zoneDao = ref.read(zoneDaoProvider);
    final children = <Widget>[];
    for (final region in regions) {
      final zones = await zoneDao.watchByRegion(region.id).first;
      final filtered = exclude != null ? zones.where((z) => z.id != exclude).toList() : zones;
      if (filtered.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
        child: Text(region.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
      ));
      for (final z in filtered) {
        children.add(SimpleDialogOption(
          onPressed: () => Navigator.pop(context, z),
          child: Text(z.name),
        ));
      }
    }
    if (children.isEmpty || !context.mounted) return null;
    return showDialog<Zone>(
      context: context,
      builder: (_) => SimpleDialog(title: Text(l10n.selectZone), children: children),
    );
  }

  Future<Region?> _pickRegion(BuildContext context, WidgetRef ref, {String? exclude}) async {
    final l10n = AppLocalizations.of(context)!;
    final regions = await ref.read(regionDaoProvider).watchAll().first;
    final filtered = exclude != null ? regions.where((r) => r.id != exclude).toList() : regions;
    if (filtered.isEmpty || !context.mounted) return null;
    return showDialog<Region>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(l10n.selectRegion),
        children: filtered
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, r),
                  child: Text(r.name),
                ))
            .toList(),
      ),
    );
  }
}
