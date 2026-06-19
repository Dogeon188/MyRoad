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
              onPressed: () => ref.read(zoneDaoProvider).deleteZone(zoneId),
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
                    ListTile(
                      leading: Icon(_spotTypeIcon(spot.type)),
                      title: Text(spot.name),
                      subtitle: Text(spot.address),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => ref.read(spotDaoProvider).deleteSpot(spot.id),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SpotDetailScreen(spotId: spot.id)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton.icon(
                      onPressed: () => _addSpot(context, ref),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addSpot),
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
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.search),
            title: Text(l10n.searchSpots),
            onTap: () => Navigator.pop(context, 'search'),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(l10n.addManually),
            onTap: () => Navigator.pop(context, 'manual'),
          ),
        ],
      ),
    );

    if (choice == 'search' && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpotSearchScreen(zoneId: zoneId),
        ),
      );
    } else if (choice == 'manual' && context.mounted) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => const _AddSpotDialog(),
      );
      if (result != null) {
        await ref.read(spotDaoProvider).insertSpot(
              name: result['name'] as String,
              zoneId: zoneId,
              type: result['type'] as String,
              lat: result['lat'] as double,
              lng: result['lng'] as double,
              address: result['address'] as String?,
            );
      }
    }
  }
}

class _AddSpotDialog extends StatefulWidget {
  const _AddSpotDialog();

  @override
  State<_AddSpotDialog> createState() => _AddSpotDialogState();
}

class _AddSpotDialogState extends State<_AddSpotDialog> {
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _addressController = TextEditingController();
  String _type = 'spot';

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addSpot),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.spotName),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.spotType),
              items: [
                DropdownMenuItem(value: 'spot', child: Text(l10n.spotTypeSpot)),
                DropdownMenuItem(value: 'restaurant', child: Text(l10n.spotTypeRestaurant)),
                DropdownMenuItem(value: 'hotel', child: Text(l10n.spotTypeHotel)),
                DropdownMenuItem(value: 'custom', child: Text(l10n.spotTypeCustom)),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _latController,
              decoration: InputDecoration(labelText: l10n.latitude),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lngController,
              decoration: InputDecoration(labelText: l10n.longitude),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(labelText: l10n.address),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final lat = double.tryParse(_latController.text);
            final lng = double.tryParse(_lngController.text);
            if (name.isEmpty || lat == null || lng == null) return;
            Navigator.pop(context, {
              'name': name,
              'type': _type,
              'lat': lat,
              'lng': lng,
              'address': _addressController.text.trim(),
            });
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
