import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/services/transport_service.dart';
import 'package:myroad/api/directions_api_client.dart';

String modeLabel(BuildContext context, String mode) {
  final l10n = AppLocalizations.of(context)!;
  return switch (mode) {
    'walk' => l10n.modeWalk,
    'transit' => l10n.modeTransit,
    'car' => l10n.modeCar,
    'bicycle' => l10n.modeBicycle,
    _ => mode,
  };
}

IconData _modeIcon(String mode) => switch (mode) {
  'transit' => Icons.directions_bus,
  'car' => Icons.directions_car,
  'bicycle' => Icons.directions_bike,
  _ => Icons.directions_walk,
};

// Shared by the leg-fetch mode picker and each leg's own mode picker so
// they can't visually drift apart the way two copy-pasted dropdowns would.
class _ModeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ModeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: TransportMode.values.map((m) => DropdownMenuItem(
        value: m.value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_modeIcon(m.value), size: 18),
            const SizedBox(width: 8),
            Text(modeLabel(context, m.value)),
          ],
        ),
      )).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class TransportEditSheet extends StatefulWidget {
  final AppDatabase db;
  final String tripId;
  final String fromSpotId;
  final String toSpotId;
  final List<Transport> legs;
  final String currencyPrefix;
  final TransportService transportService;
  final VoidCallback onChanged;
  final ScaffoldMessengerState rootMessenger;

  const TransportEditSheet({
    super.key,
    required this.db,
    required this.tripId,
    required this.fromSpotId,
    required this.toSpotId,
    required this.legs,
    this.currencyPrefix = '¥',
    required this.transportService,
    required this.onChanged,
    required this.rootMessenger,
  });

  @override
  State<TransportEditSheet> createState() => _TransportEditSheetState();
}

class _TransportEditSheetState extends State<TransportEditSheet> {
  late List<Transport> _legs;
  bool _fetching = false;
  String _fetchMode = 'walk';
  bool _reordering = false;
  Spot? _transitUnavailableFrom;
  Spot? _transitUnavailableTo;

  @override
  void initState() {
    super.initState();
    _legs = List.of(widget.legs);
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final trip = await (widget.db.select(widget.db.trips)
          ..where((t) => t.id.equals(widget.tripId)))
        .getSingleOrNull();
    final pref = trip?.transportPreference ?? 'walk';
    if (mounted) setState(() => _fetchMode = pref == 'motorcycle' ? 'bicycle' : pref);

    final spots = await Future.wait([
      (widget.db.select(widget.db.spots)..where((t) => t.id.equals(widget.fromSpotId))).getSingleOrNull(),
      (widget.db.select(widget.db.spots)..where((t) => t.id.equals(widget.toSpotId))).getSingleOrNull(),
    ]);
    if (!mounted) return;
    final from = spots[0];
    final to = spots[1];
    if (from != null && to != null &&
        (addressInJapan(from.address) || addressInJapan(to.address))) {
      setState(() {
        _transitUnavailableFrom = from;
        _transitUnavailableTo = to;
      });
    }
  }

  Future<void> _reload() async {
    final results = await (widget.db.select(widget.db.transports)
          ..where((t) =>
              t.fromSpotId.equals(widget.fromSpotId) &
              t.toSpotId.equals(widget.toSpotId)))
        .get();
    if (!mounted) return;
    setState(() => _legs = results);
    widget.onChanged();
  }

  Future<void> _fetchRoute() async {
    setState(() => _fetching = true);
    try {
      final options = await widget.transportService.fetchRouteOptions(
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        mode: _fetchMode,
      );
      if (!mounted) return;

      if (options.isEmpty) {
        if (_fetchMode == 'transit') {
          _showTransitUnavailable();
        } else {
          _showOverlaySnackBar(context, AppLocalizations.of(context)!.noRouteFound);
        }
        return;
      }

      final chosen = options.length == 1
          ? options[0]
          : await _pickRoute(options);
      if (chosen == null) return;

      await widget.transportService.applyRoute(
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        tripId: widget.tripId,
        route: chosen,
      );
      await _reload();
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _showOverlaySnackBar(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.inverseSurface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface)),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), entry.remove);
  }

  Future<void> _showTransitUnavailable() async {
    final spots = await Future.wait([
      (widget.db.select(widget.db.spots)..where((t) => t.id.equals(widget.fromSpotId))).getSingleOrNull(),
      (widget.db.select(widget.db.spots)..where((t) => t.id.equals(widget.toSpotId))).getSingleOrNull(),
    ]);
    if (!mounted) return;
    final from = spots[0];
    final to = spots[1];
    setState(() {
      _transitUnavailableFrom = from;
      _transitUnavailableTo = to;
    });
  }

  Future<RouteOption?> _pickRoute(List<RouteOption> options) {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<RouteOption>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.pickRoute, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final opt in options)
              ListTile(
                leading: const Icon(Icons.route),
                title: Text(opt.summary),
                subtitle: Text('${opt.totalDurationMinutes} min · ${_formatDist(opt.totalDistanceMeters)}'),
                onTap: () => Navigator.pop(ctx, opt),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  Future<void> _addLeg() async {
    await widget.db.into(widget.db.transports).insert(
      TransportsCompanion.insert(
        tripId: widget.tripId,
        fromSpotId: widget.fromSpotId,
        toSpotId: widget.toSpotId,
        mode: Value(_fetchMode),
        estimatedDurationMinutes: 10,
      ),
    );
    await _reload();
  }

  Future<void> _deleteLeg(String id) async {
    await (widget.db.delete(widget.db.transports)..where((t) => t.id.equals(id))).go();
    await _reload();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _legs.removeAt(oldIndex);
      _legs.insert(newIndex, item);
    });
    _saveOrder();
  }

  Future<void> _saveOrder() async {
    final ordered = List.of(_legs);
    for (final leg in ordered) {
      await (widget.db.delete(widget.db.transports)..where((t) => t.id.equals(leg.id))).go();
    }
    for (final leg in ordered) {
      await widget.db.into(widget.db.transports).insert(
        TransportsCompanion.insert(
          id: Value(leg.id),
          tripId: widget.tripId,
          fromSpotId: widget.fromSpotId,
          toSpotId: widget.toSpotId,
          mode: Value(leg.mode),
          estimatedDurationMinutes: leg.estimatedDurationMinutes,
          distanceMeters: Value(leg.distanceMeters),
          routePolyline: Value(leg.routePolyline),
          routeName: Value(leg.routeName),
          price: Value(leg.price),
          notes: Value(leg.notes),
        ),
      );
    }
    widget.onChanged();
  }

  Future<void> _updateLeg(String id, {required String mode, required int duration, String? routeName, String? price, String? notes}) async {
    await (widget.db.update(widget.db.transports)..where((t) => t.id.equals(id)))
        .write(TransportsCompanion(
      mode: Value(mode),
      estimatedDurationMinutes: Value(duration),
      distanceMeters: mode == 'transit' ? const Value(null) : const Value.absent(),
      routeName: Value(routeName),
      price: Value(price),
      notes: Value(notes),
    ));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _legs.isEmpty ? l10n.addTransport : l10n.editTransport,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_legs.length > 1)
                  IconButton(
                    icon: Icon(_reordering ? Icons.check : Icons.swap_vert, size: 20),
                    onPressed: () => setState(() => _reordering = !_reordering),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_reordering)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _legs.length,
                onReorderItem: _onReorder,
                itemBuilder: (context, i) {
                  final leg = _legs[i];
                  return Card(
                    key: ValueKey(leg.id),
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Icon(_modeIcon(leg.mode), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              [
                                modeLabel(context, leg.mode),
                                '${leg.estimatedDurationMinutes}min',
                                if (leg.routeName != null) leg.routeName!,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            else ...[
              for (final (i, leg) in _legs.indexed)
                _LegEditor(
                  leg: leg,
                  index: i,
                  currencyPrefix: widget.currencyPrefix,
                  onUpdate: (mode, duration, {routeName, price, notes}) =>
                      _updateLeg(leg.id, mode: mode, duration: duration, routeName: routeName, price: price, notes: notes),
                  onDelete: () => _deleteLeg(leg.id),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addLeg,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addLeg),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ModeDropdown(
                    value: _fetchMode,
                    onChanged: (v) => setState(() {
                      _fetchMode = v;
                      _transitUnavailableFrom = null;
                      _transitUnavailableTo = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _fetching ? null : _fetchRoute,
                  icon: _fetching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.route, size: 18),
                  label: Text(_fetching ? l10n.fetchingRoute : l10n.fetchRoute),
                ),
              ],
            ),
            if (_transitUnavailableFrom != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.transitUnavailable, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 13))),
                      if (_transitUnavailableFrom!.lat != null && _transitUnavailableTo?.lat != null)
                        TextButton.icon(
                          onPressed: () {
                            final uri = Uri.parse(
                              'https://www.google.com/maps/dir/?api=1'
                              '&origin=${_transitUnavailableFrom!.lat},${_transitUnavailableFrom!.lng}'
                              '&destination=${_transitUnavailableTo!.lat},${_transitUnavailableTo!.lng}'
                              '&travelmode=transit',
                            );
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(l10n.openInGoogleMaps),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.done),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _LegEditor extends StatefulWidget {
  final Transport leg;
  final int index;
  final String currencyPrefix;
  final void Function(String mode, int duration, {String? routeName, String? price, String? notes}) onUpdate;
  final VoidCallback onDelete;

  const _LegEditor({
    required this.leg,
    required this.index,
    this.currencyPrefix = '¥',
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_LegEditor> createState() => _LegEditorState();
}

class _LegEditorState extends State<_LegEditor> {
  late String _mode;
  late TextEditingController _durationCtrl;
  late TextEditingController _routeNameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _mode = _migrateMode(widget.leg.mode);
    _durationCtrl = TextEditingController(text: '${widget.leg.estimatedDurationMinutes}');
    _routeNameCtrl = TextEditingController(text: widget.leg.routeName ?? '');
    _priceCtrl = TextEditingController(text: widget.leg.price ?? '');
    _notesCtrl = TextEditingController(text: widget.leg.notes ?? '');
  }

  static String _migrateMode(String mode) => mode == 'motorcycle' ? 'bicycle' : mode;

  @override
  void didUpdateWidget(_LegEditor old) {
    super.didUpdateWidget(old);
    if (old.leg.id != widget.leg.id) {
      _save();
      _mode = _migrateMode(widget.leg.mode);
      _durationCtrl.text = '${widget.leg.estimatedDurationMinutes}';
      _routeNameCtrl.text = widget.leg.routeName ?? '';
      _priceCtrl.text = widget.leg.price ?? '';
      _notesCtrl.text = widget.leg.notes ?? '';
    }
  }

  @override
  void deactivate() {
    _save();
    super.deactivate();
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _routeNameCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onUpdate(
      _mode,
      int.tryParse(_durationCtrl.text) ?? widget.leg.estimatedDurationMinutes,
      routeName: _routeNameCtrl.text.isEmpty ? null : _routeNameCtrl.text,
      price: _priceCtrl.text.isEmpty ? null : _priceCtrl.text,
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeDropdown(
                    value: _mode,
                    onChanged: (v) {
                      setState(() => _mode = v);
                      _save();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.durationMin,
                      prefixIcon: const Icon(Icons.timer_outlined),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _save(),
                    onTapOutside: (_) => _save(),
                  ),
                ),
                if (widget.leg.distanceMeters != null && _mode != 'transit') ...[
                  const SizedBox(width: 4),
                  Text(
                    widget.leg.distanceMeters! >= 1000
                        ? '${(widget.leg.distanceMeters! / 1000).toStringAsFixed(1)} km'
                        : '${widget.leg.distanceMeters!.round()} m',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: widget.onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_mode == 'transit') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _routeNameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.routeName,
                        prefixIcon: const Icon(Icons.route),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _save(),
                      onTapOutside: (_) => _save(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.price,
                        prefixIcon: const Icon(Icons.payments_outlined),
                        prefixText: widget.currencyPrefix,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _save(),
                      onTapOutside: (_) => _save(),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: l10n.notes,
                prefixIcon: const Icon(Icons.notes),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: null,
              onTapOutside: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}
