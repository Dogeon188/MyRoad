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
        builder: (context, snapshot) {
          final regions = snapshot.data ?? [];
          if (regions.isEmpty) {
            return Center(child: Text(l10n.noRegions));
          }
          return ListView.builder(
            itemCount: regions.length,
            itemBuilder: (context, index) {
              final region = regions[index];
              return ListTile(
                title: Text(region.name),
                subtitle: region.description != null ? Text(region.description!) : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegionDetailScreen(regionId: region.id),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, region.id, region.name),
                ),
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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteRegion),
        content: Text(l10n.deleteRegionConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(regionDaoProvider).deleteRegion(id);
    }
  }
}
