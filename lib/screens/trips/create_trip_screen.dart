import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/dao/roi_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/roi_import_service.dart';

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
  final Set<String> _selectedRoiIds = {};
  int _step = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final db = ref.read(appDatabaseProvider);
    final tripId = await TripDao(db).insertTrip(
      name: _nameController.text.trim(),
      transportPreference: _transport,
      planMode: _planMode,
      startDate: _startDate,
      endDate: _endDate,
    );

    final importService = RoiImportService(db);
    for (final roiId in _selectedRoiIds) {
      await importService.importIntoTrip(roiId: roiId, tripId: tripId);
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
                TextButton(onPressed: details.onStepCancel, child: Text(l10n.cancel)),
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
                  decoration: InputDecoration(labelText: l10n.tripName),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _datePicker(l10n.startDate, _startDate, (d) => setState(() => _startDate = d))),
                    const SizedBox(width: 8),
                    Expanded(child: _datePicker(l10n.endDate, _endDate, (d) => setState(() => _endDate = d))),
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
                  decoration: InputDecoration(labelText: l10n.transportPreference),
                  items: [
                    DropdownMenuItem(value: 'walk', child: Text(l10n.walk)),
                    DropdownMenuItem(value: 'transit', child: Text(l10n.publicTransit)),
                    DropdownMenuItem(value: 'car', child: Text(l10n.car)),
                    DropdownMenuItem(value: 'motorcycle', child: Text(l10n.motorcycle)),
                  ],
                  onChanged: (v) => setState(() => _transport = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _planMode,
                  decoration: InputDecoration(labelText: l10n.planMode),
                  items: [
                    DropdownMenuItem(value: 'coarse', child: Text(l10n.planModeCoarse)),
                    DropdownMenuItem(value: 'detailed', child: Text(l10n.planModeDetailed)),
                  ],
                  onChanged: (v) => setState(() => _planMode = v!),
                ),
              ],
            ),
          ),
          Step(
            title: Text(l10n.selectRois),
            content: _buildRoiSelector(l10n),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return TextButton(
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          initialDate: value ?? DateTime.now(),
        );
        if (d != null) onPicked(d);
      },
      child: Text(value != null ? '$label: ${value.toString().split(' ')[0]}' : label),
    );
  }

  Widget _buildRoiSelector(AppLocalizations l10n) {
    final db = ref.watch(appDatabaseProvider);
    return StreamBuilder<List<Roi>>(
      stream: RoiDao(db).watchAll(),
      builder: (context, snapshot) {
        final rois = snapshot.data ?? [];
        if (rois.isEmpty) return Text(l10n.noRois);
        return Column(
          children: rois.map((roi) => CheckboxListTile(
            title: Text(roi.name),
            subtitle: roi.description != null ? Text(roi.description!) : null,
            value: _selectedRoiIds.contains(roi.id),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedRoiIds.add(roi.id);
                } else {
                  _selectedRoiIds.remove(roi.id);
                }
              });
            },
          )).toList(),
        );
      },
    );
  }
}
