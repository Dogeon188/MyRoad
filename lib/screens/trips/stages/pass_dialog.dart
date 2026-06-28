import 'package:flutter/material.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/widgets/dialogs.dart';

Future<void> showPassDialog(BuildContext context, ItineraryDao itineraryDao, String tripId, int dayCount, {TravelPassesData? existing, int? defaultDay}) async {
  final l10n = AppLocalizations.of(context)!;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final urlCtrl = TextEditingController(text: existing?.url ?? '');
  final priceCtrl = TextEditingController(text: existing?.price ?? '');
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  int startDay = existing?.startDay ?? defaultDay ?? 1;
  int endDay = existing?.endDay ?? defaultDay ?? 1;
  bool rangeMode = existing != null && existing.startDay != existing.endDay;
  bool bought = existing?.bought ?? false;

  final dayItems = List.generate(dayCount, (i) => DropdownMenuItem(
    value: i + 1,
    child: Text(l10n.dayN(i + 1)),
  ));

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(existing != null ? l10n.editPass : l10n.addPass,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(label: requiredLabel(l10n.passName), prefixIcon: const Icon(Icons.confirmation_number_outlined)),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(labelText: l10n.passUrl, prefixIcon: const Icon(Icons.link)),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              decoration: InputDecoration(labelText: l10n.price, prefixIcon: const Icon(Icons.payments_outlined)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: l10n.passNote, prefixIcon: const Icon(Icons.notes)),
            ),
            CheckboxListTile(
              title: Text(l10n.passBought),
              value: bought,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(() => bought = v!),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(rangeMode ? l10n.startDay : l10n.day),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: startDay,
                  items: dayItems,
                  onChanged: (v) => setDialogState(() {
                    startDay = v!;
                    if (!rangeMode || endDay < startDay) endDay = startDay;
                  }),
                ),
              ],
            ),
            CheckboxListTile(
              title: Text(l10n.enableEndDay),
              value: rangeMode,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setDialogState(() {
                rangeMode = v!;
                if (!rangeMode) endDay = startDay;
              }),
            ),
            if (rangeMode)
              Row(
                children: [
                  Text(l10n.endDay),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: endDay,
                    items: dayItems.where((i) => i.value! >= startDay).toList(),
                    onChanged: (v) => setDialogState(() => endDay = v!),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        )),
      ),
    ),
  );

  if (result != true || nameCtrl.text.isEmpty) return;
  if (existing != null) {
    await itineraryDao.updatePass(existing.id,
        name: nameCtrl.text,
        url: urlCtrl.text.isEmpty ? null : urlCtrl.text,
        price: priceCtrl.text.isEmpty ? null : priceCtrl.text,
        startDay: startDay,
        endDay: endDay,
        bought: bought,
        note: noteCtrl.text.isEmpty ? null : noteCtrl.text);
  } else {
    await itineraryDao.addPass(
      tripId: tripId,
      name: nameCtrl.text,
      url: urlCtrl.text.isEmpty ? null : urlCtrl.text,
      price: priceCtrl.text.isEmpty ? null : priceCtrl.text,
      startDay: startDay,
      endDay: endDay,
      bought: bought,
      note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
    );
  }
}
