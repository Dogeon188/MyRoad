import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/widgets/dialogs.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _transport = 'walk';
  String _planMode = 'coarse';
  // ponytail: regionId → 'link' | 'copy'
  final Map<String, String> _selectedRegions = {};
  int _step = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final regionDao = ref.read(regionDaoProvider);
    final db = ref.read(appDatabaseProvider);
    final tripId = await ref
        .read(tripDaoProvider)
        .insertTrip(
          name: _nameController.text.trim(),
          transportPreference: _transport,
          planMode: _planMode,
          startDate: _startDate,
          endDate: _endDate,
        );

    // Auto-init itinerary days from date range
    if (_startDate != null && _endDate != null) {
      final dayCount = _endDate!.difference(_startDate!).inDays + 1;
      if (dayCount > 0) {
        final itineraryDao = ItineraryDao(db);
        await itineraryDao.initializeDays(tripId, dayCount);
      }
    }

    final areaDao = ref.read(areaDaoProvider);
    final spotDao = ref.read(spotDaoProvider);
    for (final entry in _selectedRegions.entries) {
      if (entry.value == 'copy') {
        await regionDao.deepCopyForTrip(entry.key, tripId, areaDao, spotDao);
      } else {
        await regionDao.addToTrip(entry.key, tripId);
      }
    }

    if (mounted) Navigator.pop(context, tripId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createTrip)),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (_step == 0 && _nameController.text.trim().isEmpty) return;
          if (_step < 2) {
            setState(() => _step++);
          } else {
            _create();
          }
        },
        onStepCancel: () {
          if (_step > 0) setState(() => _step--);
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              FilledButton(
                onPressed: details.onStepContinue,
                child: Text(_step == 2 ? l10n.create : l10n.next),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(l10n.cancel),
                ),
              ],
            ],
          );
        },
        steps: [
          Step(
            title: Text(l10n.tripName),
            content: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    label: requiredLabel(l10n.tripName),
                    prefixIcon: const Icon(Icons.luggage_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _datePicker(
                        l10n.startDate,
                        _startDate,
                        (d) => setState(() => _startDate = d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _datePicker(
                        l10n.endDate,
                        _endDate,
                        (d) => setState(() => _endDate = d),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Step(
            title: Text(l10n.transportPreference),
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _transport,
                  decoration: InputDecoration(
                    labelText: l10n.transportPreference,
                    prefixIcon: const Icon(Icons.directions_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'walk',
                      child: _transportItem(Icons.directions_walk, l10n.walk),
                    ),
                    DropdownMenuItem(
                      value: 'transit',
                      child: _transportItem(
                        Icons.directions_bus,
                        l10n.publicTransit,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'car',
                      child: _transportItem(Icons.directions_car, l10n.car),
                    ),
                    DropdownMenuItem(
                      value: 'bicycle',
                      child: _transportItem(
                        Icons.directions_bike,
                        l10n.bicycle,
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _transport = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _planMode,
                  decoration: InputDecoration(
                    labelText: l10n.planMode,
                    prefixIcon: const Icon(Icons.event_note_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'coarse',
                      child: Text(l10n.planModeCoarse),
                    ),
                    DropdownMenuItem(
                      value: 'detailed',
                      child: Text(l10n.planModeDetailed),
                    ),
                  ],
                  onChanged: (v) => setState(() => _planMode = v!),
                ),
              ],
            ),
          ),
          Step(
            title: Text(l10n.selectRegions),
            content: _buildRegionSelector(l10n),
          ),
        ],
      ),
    );
  }

  Widget _transportItem(IconData icon, String label) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );
  }

  Widget _datePicker(
    String label,
    DateTime? value,
    ValueChanged<DateTime> onPicked,
  ) {
    return TextButton(
      onPressed: () async {
        final d = await showTripDatePicker(context, initialDate: value);
        if (d != null) onPicked(d);
      },
      child: Text(
        value != null ? '$label: ${value.toString().split(' ')[0]}' : label,
      ),
    );
  }

  Widget _buildRegionSelector(AppLocalizations l10n) {
    final regionDao = ref.watch(regionDaoProvider);
    return StreamBuilder<List<Region>>(
      stream: regionDao.watchAll(),
      builder: (context, snapshot) {
        final regions = snapshot.data ?? [];
        if (regions.isEmpty) return Text(l10n.noRegions);
        return Column(
          children: regions.map((region) {
            final mode = _selectedRegions[region.id];
            return ListTile(
              title: Text(region.name),
              subtitle: region.description != null
                  ? Text(region.description!)
                  : null,
              trailing: SegmentedButton<String>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'link',
                    icon: const Icon(Icons.link, size: 16),
                    label: Text(l10n.linkRegion),
                  ),
                  ButtonSegment(
                    value: 'copy',
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(l10n.copyRegion),
                  ),
                ],
                selected: mode != null ? {mode} : {},
                onSelectionChanged: (sel) {
                  setState(() {
                    if (sel.isEmpty) {
                      _selectedRegions.remove(region.id);
                    } else {
                      _selectedRegions[region.id] = sel.first;
                    }
                  });
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
