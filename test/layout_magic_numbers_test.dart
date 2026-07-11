import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Ratchet test, not a ban: hardcoded width/height literals are how the
// builder-view day-column drift bug happened (see cf9dfd6) — a pitch value
// duplicated across widgets silently went out of sync. Most width/height
// literals are harmless one-off spacers though, so this only stops the
// count from growing, and gets lowered as real duplicates get cleaned up:
//   194 -> 174  spot_detail_screen.dart preview/thumbnail/swatch sizes
//   174 -> 173  transport_edit_sheet.dart's copy-pasted mode dropdown
//               (merged into _ModeDropdown, also de-duped _modeIcon)
//   173 -> 168  itinerary_builder_stage.dart's pass-dialog field gaps
//   168 -> 166  hotel_config_stage.dart's hotel-bar track/overlay height
//               (this file also had a real bug: bar position/width were
//               computed from MediaQuery screen width minus a guessed 64px
//               of chrome instead of the widget's actual LayoutBuilder
//               constraints — fixed alongside, not counted by this regex)
//   166 -> 168  transport_edit_sheet.dart's map route button gap (+1),
//               spot_detail_screen.dart's spot-link field gap (+1)
//   168 -> 170  transport_edit_sheet.dart's leg-link field gap (+1),
//               icon_color_picker.dart swatch border width (+1)
//   169 -> 173  spot color customization restored: spot_detail_screen.dart's
//               color-picker row gaps (+2), icon_color_picker.dart's
//               ColorPickerButton swatch border width and dialog gap (+2)
//   173 -> 123  magic-number sweep: rail/gap/icon-size constants extracted
//               across builder_area_card.dart, detail_export_view.dart,
//               edit_area_dialog.dart, trip_dashboard_screen.dart,
//               create_trip_screen.dart, hotel_config_stage.dart,
//               transport_edit_sheet.dart, spot_detail_screen.dart,
//               builder_rows.dart, pass_dialog.dart, spot_search_screen.dart;
//               several Row/Column literal-gap spacers replaced with the
//               native Flex `spacing` param; trip_list_screen.dart and
//               region_library_screen.dart's copy-pasted stat row merged
//               into the shared widgets/stat_row.dart
void main() {
  test('width/height magic number literals in lib/ do not increase', () {
    final pattern = RegExp(r'(width|height): ?[0-9]+(\.[0-9]+)?');
    var count = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart')) {
        continue;
      }
      count += pattern.allMatches(entity.readAsStringSync()).length;
    }

    const baseline = 123;
    expect(
      count,
      lessThanOrEqualTo(baseline),
      reason:
          'New hardcoded width/height literal(s) in lib/ (found $count, baseline $baseline). '
          'One-off spacer? Bump the baseline. Needs to stay in sync with another '
          "widget's layout (a day-column pitch, a rail width)? Extract a shared "
          'constant instead of a new literal.',
    );
  });
}
