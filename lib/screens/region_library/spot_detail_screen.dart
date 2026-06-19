import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:myroad/services/providers.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/api/places_api_client.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  final String spotId;

  const SpotDetailScreen({super.key, required this.spotId});

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  final _notesController = TextEditingController();
  final _durationController = TextEditingController();
  final _bufferController = TextEditingController();
  Spot? _spot;

  @override
  void initState() {
    super.initState();
    _loadSpot();
  }

  Future<void> _loadSpot() async {
    final spotDao = ref.read(spotDaoProvider);
    var spot = await spotDao.getById(widget.spotId);
    if (spot == null || !mounted) return;

    if (spot.previewImageUrl == null && spot.googlePlaceId != null) {
      final client = PlacesApiClient(languageCode: Localizations.localeOf(context).languageCode);
      final details = await client.getPlaceDetails(spot.googlePlaceId!);
      if (details != null && details.photoReferences.isNotEmpty) {
        final url = client.getPhotoUrl(details.photoReferences.first);
        await spotDao.updateSpot(spot.id, previewImageUrl: url);
        spot = (await spotDao.getById(widget.spotId))!;
      }
    }

    if (!mounted) return;
    setState(() {
      _spot = spot;
      _notesController.text = spot!.notes;
      _durationController.text = spot.estimatedVisitDurationMinutes.toString();
      _bufferController.text = spot.bufferTimeMinutes.toString();
    });
  }

  Future<void> _saveField({String? notes, int? duration, int? buffer, String? type}) async {
    await ref.read(spotDaoProvider).updateSpot(
      widget.spotId,
      notes: notes,
      estimatedVisitDurationMinutes: duration,
      bufferTimeMinutes: buffer,
      type: type,
    );
  }

  IconData _spotTypeIcon(SpotType t) => switch (t) {
    SpotType.spot => Icons.place,
    SpotType.restaurant => Icons.restaurant,
    SpotType.hotel => Icons.hotel,
    SpotType.custom => Icons.star_outline,
  };

  String _spotTypeLabel(AppLocalizations l10n, SpotType t) => switch (t) {
    SpotType.spot => l10n.spotTypeSpot,
    SpotType.restaurant => l10n.spotTypeRestaurant,
    SpotType.hotel => l10n.spotTypeHotel,
    SpotType.custom => l10n.spotTypeCustom,
  };

  @override
  void dispose() {
    _notesController.dispose();
    _durationController.dispose();
    _bufferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_spot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_spot!.name)),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_spot!.previewImageUrl != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _spot!.previewImageUrl!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<SpotType>(
            initialValue: SpotType.fromString(_spot!.type),
            decoration: InputDecoration(labelText: l10n.spotType, border: const OutlineInputBorder()),
            items: SpotType.values
                .map((t) => DropdownMenuItem(value: t, child: Row(
                  children: [
                    Icon(_spotTypeIcon(t), size: 20),
                    const SizedBox(width: 8),
                    Text(_spotTypeLabel(l10n, t)),
                  ],
                )))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              _saveField(type: v.value);
              setState(() => _spot = _spot!.copyWith(type: v.value));
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(labelText: l10n.notes, border: const OutlineInputBorder()),
            maxLines: 3,
            onChanged: (v) => _saveField(notes: v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  decoration: InputDecoration(labelText: l10n.estimatedDuration, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final d = int.tryParse(v);
                    if (d != null) _saveField(duration: d);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _bufferController,
                  decoration: InputDecoration(labelText: l10n.bufferTime, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final b = int.tryParse(v);
                    if (b != null) _saveField(buffer: b);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _CustomInfoSection(spotId: widget.spotId),
          const SizedBox(height: 24),
          _OpeningHoursSection(spotId: widget.spotId),
          const SizedBox(height: 24),
          _PhotosSection(spotId: widget.spotId),
        ],
      ),
    );
  }
}

class _CustomInfoSection extends ConsumerWidget {
  final String spotId;
  const _CustomInfoSection({required this.spotId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.customInfo, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(icon: const Icon(Icons.add), onPressed: () => _addCustomInfo(context, ref)),
          ],
        ),
        FutureBuilder(
          future: spotDao.getCustomInfos(spotId),
          builder: (context, snapshot) {
            final infos = snapshot.data ?? [];
            return Column(
              children: infos
                  .map((info) => ListTile(
                        title: Text(info.label),
                        subtitle: Text(info.value),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => spotDao.deleteCustomInfo(info.id),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addCustomInfo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final labelCtrl = TextEditingController();
    final valueCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.addCustomInfo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelCtrl, decoration: InputDecoration(labelText: l10n.label), autofocus: true),
            const SizedBox(height: 8),
            TextField(controller: valueCtrl, decoration: InputDecoration(labelText: l10n.value)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.save)),
        ],
      ),
    );

    if (result == true) {
      await ref.read(spotDaoProvider).addCustomInfo(spotId, labelCtrl.text.trim(), valueCtrl.text.trim());
    }
    labelCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _OpeningHoursSection extends ConsumerWidget {
  final String spotId;
  const _OpeningHoursSection({required this.spotId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);
    final dayNames = [l10n.monday, l10n.tuesday, l10n.wednesday, l10n.thursday, l10n.friday, l10n.saturday, l10n.sunday];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.openingHours, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(icon: const Icon(Icons.add), onPressed: () => _addHours(context, ref)),
          ],
        ),
        FutureBuilder(
          future: spotDao.getOpeningHours(spotId),
          builder: (context, snapshot) {
            final hours = snapshot.data ?? [];
            return Column(
              children: hours
                  .map((h) => ListTile(
                        title: Text(dayNames[h.day]),
                        subtitle: Text('${_fmt(h.openMinutes)} — ${_fmt(h.closeMinutes)}'),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _addHours(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    int day = 0;
    TimeOfDay open = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay close = const TimeOfDay(hour: 17, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addOpeningHours),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: day,
                decoration: InputDecoration(labelText: l10n.day),
                items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                        value: i,
                        child: Text([
                          l10n.monday, l10n.tuesday, l10n.wednesday, l10n.thursday,
                          l10n.friday, l10n.saturday, l10n.sunday,
                        ][i]))),
                onChanged: (v) => setDialogState(() => day = v!),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: open);
                        if (t != null) setDialogState(() => open = t);
                      },
                      child: Text('${l10n.openTime}: ${open.format(context)}'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: close);
                        if (t != null) setDialogState(() => close = t);
                      },
                      child: Text('${l10n.closeTime}: ${close.format(context)}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.save)),
          ],
        ),
      ),
    );

    if (result == true) {
      await ref.read(spotDaoProvider).addOpeningHours(
        spotId,
        day: day,
        openMinutes: open.hour * 60 + open.minute,
        closeMinutes: close.hour * 60 + close.minute,
      );
    }
  }
}

class _PhotosSection extends ConsumerWidget {
  final String spotId;
  const _PhotosSection({required this.spotId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.photos, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(icon: const Icon(Icons.add_a_photo), onPressed: () => _addPhoto(context, ref)),
          ],
        ),
        FutureBuilder(
          future: spotDao.getPhotos(spotId),
          builder: (context, snapshot) {
            final photos = snapshot.data ?? [];
            if (photos.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: photo.uri.startsWith('http')
                              ? Image.network(
                                  photo.uri, width: 120, height: 120, fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 120, height: 120,
                                    child: Center(child: Icon(Icons.broken_image_outlined)),
                                  ),
                                )
                              : Image.file(File(photo.uri), width: 120, height: 120, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => spotDao.deletePhoto(photo.id),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text(l10n.fromCamera),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(l10n.fromGallery),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, maxWidth: 1920);
    if (xFile == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!photosDir.existsSync()) photosDir.createSync(recursive: true);

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(xFile.path)}';
    final savedPath = p.join(photosDir.path, fileName);
    await File(xFile.path).copy(savedPath);

    await ref.read(spotDaoProvider).addPhoto(spotId, savedPath);
  }
}
