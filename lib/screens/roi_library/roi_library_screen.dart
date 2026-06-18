import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/roi_library/create_roi_dialog.dart';
import 'package:myroad/screens/roi_library/roi_detail_screen.dart';

class RoiLibraryScreen extends ConsumerWidget {
  const RoiLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final roiDao = ref.watch(roiDaoProvider);

    return Scaffold(
      body: StreamBuilder(
        stream: roiDao.watchAll(),
        builder: (context, snapshot) {
          final rois = snapshot.data ?? [];
          if (rois.isEmpty) {
            return Center(child: Text(l10n.noRois));
          }
          return ListView.builder(
            itemCount: rois.length,
            itemBuilder: (context, index) {
              final roi = rois[index];
              return ListTile(
                title: Text(roi.name),
                subtitle: roi.description != null ? Text(roi.description!) : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoiDetailScreen(roiId: roi.id),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, roi.id, roi.name),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createRoi(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createRoi(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => CreateRoiDialog(title: l10n.createRoi),
    );
    if (result != null) {
      await ref.read(roiDaoProvider).insertRoi(
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
        title: Text(l10n.deleteRoi),
        content: Text(l10n.deleteRoiConfirm(name)),
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
      await ref.read(roiDaoProvider).deleteRoi(id);
    }
  }
}
