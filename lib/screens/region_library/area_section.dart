import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/spot_search_screen.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/widgets/dialogs.dart';
import 'package:myroad/widgets/name_input_dialog.dart';

const _kDayBudgetMinutes = 16 * 60;

class AreaSection extends ConsumerWidget {
  final String areaId;
  final String areaName;
  final String regionId;
  final bool reorderable;

  const AreaSection({super.key, required this.areaId, required this.areaName, required this.regionId, this.reorderable = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(areaName, style: Theme.of(context).textTheme.titleMedium),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            switch (action) {
              case 'rename':
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => NameInputDialog(
                    title: l10n.rename,
                    labelText: l10n.areaName,
                    initialValue: areaName,
                  ),
                );
                if (name != null) ref.read(areaDaoProvider).updateArea(areaId, name: name);
              case 'delete':
                if (await showConfirmDialog(context, title: l10n.delete, content: l10n.deleteAreaConfirm(areaName))) {
                  ref.read(areaDaoProvider).deleteArea(areaId);
                }
              case 'move':
                final target = await _pickRegion(context, ref, exclude: regionId);
                if (target != null) await ref.read(areaDaoProvider).moveToRegion(areaId, target.id);
              case 'copy':
                final target = await _pickRegion(context, ref);
                if (target != null) await ref.read(areaDaoProvider).copyToRegion(areaId, target.id, ref.read(spotDaoProvider));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
            PopupMenuItem(value: 'move', child: Text(l10n.moveToRegion)),
            PopupMenuItem(value: 'copy', child: Text(l10n.copyToRegion)),
            PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
          ],
        ),
        children: [
          StreamBuilder(
            stream: spotDao.watchByArea(areaId),
            builder: (context, snapshot) {
              final spots = snapshot.data ?? [];
              return Column(
                children: [
                  if (reorderable && spots.isNotEmpty) ...[
                    Builder(builder: (context) {
                      final totalMinutes = spots.fold<int>(
                        0, (sum, s) => sum + s.estimatedVisitDurationMinutes + s.bufferTimeMinutes,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: (totalMinutes / _kDayBudgetMinutes).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[300],
                              color: totalMinutes > _kDayBudgetMinutes ? Colors.red : Colors.teal,
                            ),
                            const SizedBox(height: 4),
                            Text(l10n.timeBudget(totalMinutes ~/ 60, totalMinutes % 60)),
                          ],
                        ),
                      );
                    }),
                  ],
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
                      confirmDismiss: (_) => showConfirmDialog(context, content: l10n.deleteSpotConfirm(spot.name)),
                      onDismissed: (_) => ref.read(spotDaoProvider).deleteSpot(spot.id),
                      child: ListTile(
                        leading: reorderable
                            ? GestureDetector(
                                onVerticalDragStart: (_) {},
                                child: const Icon(Icons.drag_handle),
                              )
                            : Icon(_spotTypeIcon(spot.type)),
                        title: Text(spot.name),
                        subtitle: reorderable
                            ? Text('${spot.estimatedVisitDurationMinutes}min + ${spot.bufferTimeMinutes}min buffer')
                            : Column(
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
        builder: (_) => SpotSearchScreen(areaId: areaId),
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
              title: Text(l10n.moveToArea),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.copyToArea),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(l10n.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'delete') {
      if (await showConfirmDialog(context, content: l10n.deleteSpotConfirm(spot.name))) {
        ref.read(spotDaoProvider).deleteSpot(spot.id);
      }
      return;
    }
    final target = await _pickArea(context, ref, exclude: action == 'move' ? areaId : null);
    if (target == null) return;
    final spotDao = ref.read(spotDaoProvider);
    if (action == 'move') {
      await spotDao.moveToArea(spot.id, target.id);
    } else {
      await spotDao.copyToArea(spot.id, target.id);
    }
  }

  Future<Area?> _pickArea(BuildContext context, WidgetRef ref, {String? exclude}) async {
    final l10n = AppLocalizations.of(context)!;
    final regions = await ref.read(regionDaoProvider).watchAll().first;
    final areaDao = ref.read(areaDaoProvider);
    final children = <Widget>[];
    for (final region in regions) {
      final areas = await areaDao.watchByRegion(region.id).first;
      final filtered = exclude != null ? areas.where((a) => a.id != exclude).toList() : areas;
      if (filtered.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
        child: Text(region.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
      ));
      for (final a in filtered) {
        children.add(SimpleDialogOption(
          onPressed: () => Navigator.pop(context, a),
          child: Text(a.name),
        ));
      }
    }
    if (children.isEmpty || !context.mounted) return null;
    return showDialog<Area>(
      context: context,
      builder: (_) => SimpleDialog(title: Text(l10n.selectArea), children: children),
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
