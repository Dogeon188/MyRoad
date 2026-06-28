import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:myroad/services/providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:myroad/database/database.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/api/places_api_client.dart';
import 'package:myroad/widgets/name_input_dialog.dart';
import 'package:myroad/widgets/dialogs.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  final String spotId;

  const SpotDetailScreen({super.key, required this.spotId});

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  final _notesController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _bufferController = TextEditingController();
  final _reviewController = TextEditingController();
  Spot? _spot;
  String _currency = 'JPY';

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

    final area = await ref.read(areaDaoProvider).getById(spot.areaId);
    final region = area != null ? await ref.read(regionDaoProvider).getById(area.regionId) : null;

    if (!mounted) return;
    setState(() {
      _spot = spot;
      if (region != null) _currency = region.currency;
      _notesController.text = spot!.notes;
      _priceController.text = spot.price ?? '';
      _durationController.text = spot.estimatedVisitDurationMinutes.toString();
      _bufferController.text = spot.bufferTimeMinutes.toString();
      _reviewController.text = spot.review ?? '';
    });
  }

  Future<void> _saveField({String? notes, int? duration, int? buffer, String? type, Value<String?>? price}) async {
    await ref.read(spotDaoProvider).updateSpot(
      widget.spotId,
      notes: notes,
      estimatedVisitDurationMinutes: duration,
      bufferTimeMinutes: buffer,
      type: type,
      price: price ?? const Value.absent(),
    );
  }

  IconData _spotTypeIcon(SpotType t) => switch (t) {
    SpotType.spot => Icons.place,
    SpotType.restaurant => Icons.restaurant,
    SpotType.hotel => Icons.hotel,
    SpotType.online => Icons.videocam,
    SpotType.custom => Icons.star_outline,
  };

  String _spotTypeLabel(AppLocalizations l10n, SpotType t) => switch (t) {
    SpotType.spot => l10n.spotTypeSpot,
    SpotType.restaurant => l10n.spotTypeRestaurant,
    SpotType.hotel => l10n.spotTypeHotel,
    SpotType.online => l10n.spotTypeOnline,
    SpotType.custom => l10n.spotTypeCustom,
  };

  @override
  void dispose() {
    _notesController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _bufferController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_spot == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(_spot!.name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => NameInputDialog(
                    title: l10n.rename,
                    labelText: l10n.spotName,
                    initialValue: _spot!.name,
                  ),
                );
                if (name != null && name.isNotEmpty) {
                  await ref.read(spotDaoProvider).updateSpot(widget.spotId, name: name);
                  setState(() => _spot = _spot!.copyWith(name: name));
                }
              },
              child: Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (_spot!.googlePlaceId != null || (_spot!.lat != null && _spot!.lng != null))
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: l10n.openInGoogleMaps,
              onPressed: () {
                final Uri uri;
                if (_spot!.googlePlaceId != null) {
                  uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': _spot!.name, 'query_place_id': _spot!.googlePlaceId!});
                } else {
                  uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '${_spot!.lat},${_spot!.lng}'});
                }
                launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_spot!.previewImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _spot!.previewImageUrl!,
                height: 200,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 200,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator.adaptive()),
                      ),
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
          const SizedBox(height: 16),
          DropdownButtonFormField<SpotType>(
            key: ValueKey(_spot!.type),
            initialValue: SpotType.fromString(_spot!.type),
            decoration: InputDecoration(labelText: l10n.spotType, prefixIcon: const Icon(Icons.category_outlined), border: const OutlineInputBorder()),
            items: SpotType.values
                .map((t) => DropdownMenuItem(value: t, child: Row(
                  children: [
                    Icon(_spotTypeIcon(t), size: 20),
                    const SizedBox(width: 8),
                    Text(_spotTypeLabel(l10n, t)),
                  ],
                )))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              if (_spot!.type == 'hotel' && v.value != 'hotel') {
                final db = ref.read(appDatabaseProvider);
                final refs = await (db.select(db.hotelStays)
                      ..where((t) => t.spotId.equals(_spot!.id))
                      ..limit(1))
                    .get();
                if (refs.isNotEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.hotelInUse)),
                  );
                  setState(() {}); // force dropdown rebuild via key
                  return;
                }
              }
              _saveField(type: v.value);
              setState(() => _spot = _spot!.copyWith(type: v.value));
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(labelText: l10n.notes, prefixIcon: const Icon(Icons.notes), border: const OutlineInputBorder()),
            maxLines: 3,
            onChanged: (v) => _saveField(notes: v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            decoration: InputDecoration(labelText: l10n.price, prefixIcon: const Icon(Icons.payments_outlined), prefixText: currencySymbol(_currency), border: const OutlineInputBorder()),
            onChanged: (v) => _saveField(price: Value(v.isEmpty ? null : v)),
          ),
          if (_spot!.type != 'hotel') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: InputDecoration(labelText: l10n.estimatedDuration, prefixIcon: const Icon(Icons.timer_outlined), border: const OutlineInputBorder()),
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
                    decoration: InputDecoration(labelText: l10n.bufferTime, prefixIcon: const Icon(Icons.hourglass_empty_outlined), border: const OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final b = int.tryParse(v);
                      if (b != null) _saveField(buffer: b);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _CustomInfoSection(spotId: widget.spotId),
          const SizedBox(height: 24),
          _OpeningHoursSection(spotId: widget.spotId),
          const SizedBox(height: 24),
          _PhotosSection(spotId: widget.spotId),
          const SizedBox(height: 24),
          Text(l10n.postTrip, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _reviewController,
                  decoration: InputDecoration(
                    hintText: l10n.writeReview,
                    prefixIcon: const Icon(Icons.rate_review_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (v) => ref.read(spotDaoProvider).updateSpot(widget.spotId, review: v),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.thumb_up, color: _spot!.rating == 1 ? Colors.green : null),
                    onPressed: () {
                      final r = _spot!.rating == 1 ? null : 1;
                      ref.read(spotDaoProvider).updateSpot(widget.spotId, rating: Value(r));
                      setState(() => _spot = _spot!.copyWith(rating: Value(r)));
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.thumb_down, color: _spot!.rating == -1 ? Colors.red : null),
                    onPressed: () {
                      final r = _spot!.rating == -1 ? null : -1;
                      ref.read(spotDaoProvider).updateSpot(widget.spotId, rating: Value(r));
                      setState(() => _spot = _spot!.copyWith(rating: Value(r)));
                    },
                  ),
                ],
              ),
            ],
          ),
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
                          icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
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
            TextField(controller: labelCtrl, decoration: InputDecoration(label: requiredLabel(l10n.label), prefixIcon: const Icon(Icons.label_outlined)), autofocus: true),
            const SizedBox(height: 8),
            TextField(controller: valueCtrl, decoration: InputDecoration(label: requiredLabel(l10n.value), prefixIcon: const Icon(Icons.text_fields))),
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

class _OpeningHoursSection extends ConsumerStatefulWidget {
  final String spotId;
  const _OpeningHoursSection({required this.spotId});

  @override
  ConsumerState<_OpeningHoursSection> createState() => _OpeningHoursSectionState();
}

class _OpeningHoursSectionState extends ConsumerState<_OpeningHoursSection> {
  int _rebuildKey = 0;

  Future<void> _refetchHours() async {
    final spotDao = ref.read(spotDaoProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final spot = await spotDao.getById(widget.spotId);
    if (spot?.googlePlaceId == null) return;
    final client = PlacesApiClient(languageCode: locale);
    final details = await client.getPlaceDetails(spot!.googlePlaceId!);
    if (details == null) return;
    await spotDao.deleteOpeningHours(widget.spotId);
    for (final p in details.openingHours) {
      await spotDao.addOpeningHours(widget.spotId, day: p.day, openMinutes: p.openMinutes, closeMinutes: p.closeMinutes);
    }
    if (mounted) setState(() => _rebuildKey++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spotDao = ref.watch(spotDaoProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.openingHours, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _refetchHours),
            IconButton(icon: const Icon(Icons.add), onPressed: _addHours),
          ],
        ),
        FutureBuilder(
          key: ValueKey(_rebuildKey),
          future: spotDao.getOpeningHours(widget.spotId),
          builder: (context, snapshot) {
            final hours = snapshot.data ?? [];
            if (hours.isEmpty) return const SizedBox.shrink();
            // ponytail: compact 7-col grid, upgrade to half-hour granularity if needed
            final minH = hours.map((h) => h.openMinutes ~/ 60).reduce((a, b) => a < b ? a : b);
            final maxH = hours.map((h) => (h.closeMinutes / 60).ceil()).reduce((a, b) => a > b ? a : b);
            final hourCount = maxH - minH;
            if (hourCount <= 0) return const SizedBox.shrink();
            final dayAbbr = [l10n.monday, l10n.tuesday, l10n.wednesday, l10n.thursday, l10n.friday, l10n.saturday, l10n.sunday]
                .map((s) => s.substring(0, 1))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Hour labels column
                    Column(
                      children: [
                        ...List.generate(hourCount, (i) => Container(
                          height: 14,
                          margin: const EdgeInsets.symmetric(vertical: 0.5),
                          alignment: Alignment.centerRight,
                          child: Text('${minH + i}', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                        )),
                        const SizedBox(height: 2),
                        Text('', style: TextStyle(fontSize: 9)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    // 7 day columns
                    ...List.generate(7, (col) {
                      // col 0=Mon..6=Sun; DB day 0=Sun,1=Mon..6=Sat
                      final apiDay = (col + 1) % 7;
                      final dayHours = hours.where((h) => h.day == apiDay).toList();
                      return Expanded(
                        child: Column(
                          children: [
                            ...List.generate(hourCount, (i) {
                              final mStart = (minH + i) * 60;
                              final mEnd = mStart + 60;
                              // Compute open fraction and alignment for partial-hour cells
                              double openStart = mEnd.toDouble(), openEnd = mStart.toDouble();
                              for (final h in dayHours) {
                                final s = h.openMinutes.clamp(mStart, mEnd).toDouble();
                                final e = h.closeMinutes.clamp(mStart, mEnd).toDouble();
                                if (e > s) { openStart = openStart < s ? openStart : s; openEnd = openEnd > e ? openEnd : e; }
                              }
                              final fill = (openEnd - openStart) / 60;
                              final align = fill > 0 && fill < 1
                                  ? (openStart > mStart ? Alignment.centerRight : Alignment.centerLeft)
                                  : Alignment.centerLeft;
                              return Container(
                                height: 14,
                                margin: const EdgeInsets.all(0.5),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                alignment: align,
                                child: fill > 0 ? FractionallySizedBox(
                                  widthFactor: fill.clamp(0, 1),
                                  heightFactor: 1,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ) : null,
                              );
                            }),
                            const SizedBox(height: 2),
                            Text(dayAbbr[col], style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _addHours() async {
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
                decoration: InputDecoration(labelText: l10n.dayOfWeek, prefixIcon: const Icon(Icons.calendar_today_outlined)),
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
        widget.spotId,
        day: day,
        openMinutes: open.hour * 60 + open.minute,
        closeMinutes: close.hour * 60 + close.minute,
      );
      if (mounted) setState(() => _rebuildKey++);
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
